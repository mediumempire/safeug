import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const PageIntro(
            title: 'Emergency Center',
            subtitle: 'Quick access to help and your trusted contacts.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              tabs: const [
                Tab(
                  icon: Icon(Icons.emergency_rounded),
                  text: 'Local services',
                ),
                Tab(icon: Icon(Icons.groups_rounded), text: 'My contacts'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [EmergencyServices(), EmergencyContacts()],
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyServices extends StatelessWidget {
  const EmergencyServices({super.key});

  static const services = [
    (
      'National Police',
      'For all police-related emergencies.',
      '999',
      Icons.shield_rounded,
    ),
    (
      'Ambulance / Medical',
      'For medical emergencies and ambulance services.',
      '112',
      Icons.local_hospital_rounded,
    ),
    (
      'Tourist Police',
      'Specialized unit for tourist safety and concerns.',
      '0800 100 900',
      Icons.shield_rounded,
    ),
  ];

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      showSafeSnackBar(
        context,
        'Calling is not available on this device.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = services[index];
        return AppCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                child: Icon(service.$4, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      service.$2,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _call(context, service.$3),
                icon: const Icon(Icons.phone, size: 15),
                label: Text(service.$3, style: const TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EmergencyContacts extends StatefulWidget {
  const EmergencyContacts({super.key});

  @override
  State<EmergencyContacts> createState() => _EmergencyContactsState();
}

class _EmergencyContactsState extends State<EmergencyContacts> {
  final _firestore = FirestoreService();

  Future<void> _addContact(String uid) async {
    final name = TextEditingController();
    final relationship = TextEditingController();
    final phone = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add new contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: _required,
              ),
              TextFormField(
                controller: relationship,
                decoration: const InputDecoration(labelText: 'Relationship'),
                validator: _required,
              ),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: _required,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      name.dispose();
      relationship.dispose();
      phone.dispose();
      return;
    }
    try {
      await _firestore.addContact(
        uid,
        EmergencyContact(
          id: '',
          name: name.text.trim(),
          relationship: relationship.text.trim(),
          phone: phone.text.trim(),
        ),
      );
      if (mounted) showSafeSnackBar(context, 'Emergency contact added.');
    } catch (error) {
      if (mounted) {
        showSafeSnackBar(
          context,
          'Could not save contact: $error',
          error: true,
        );
      }
    }
    name.dispose();
    relationship.dispose();
    phone.dispose();
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to manage emergency contacts.'));
    }
    return StreamBuilder<List<EmergencyContact>>(
      stream: _firestore.contactsStream(user.uid),
      builder: (context, snapshot) {
        final contacts = snapshot.data ?? const <EmergencyContact>[];
        final children = <Widget>[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'People to notify in case of an emergency.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _addContact(user.uid),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ];
        if (snapshot.connectionState == ConnectionState.waiting) {
          children.add(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (contacts.isEmpty) {
          children.add(
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'You have not added any emergency contacts yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            ),
          );
        } else {
          children.addAll(
            contacts.map(
              (contact) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: .12,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${contact.relationship} • ${contact.phone}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () =>
                            _firestore.deleteContact(user.uid, contact.id),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: children,
        );
      },
    );
  }
}
