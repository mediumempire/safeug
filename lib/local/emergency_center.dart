import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_store.dart';
import 'mobile_tools.dart' show PublishedDirectory;

class EmergencyCenter extends StatelessWidget {
  const EmergencyCenter({super.key, required this.store, this.initialTab = 0});
  final LocalStore store;
  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: initialTab,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Emergency Center',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              Text('Quick access to help and your trusted contacts.'),
            ],
          ),
        ),
        const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.emergency_outlined), text: 'Local Services'),
            Tab(icon: Icon(Icons.people_outline), text: 'My Contacts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              PublishedDirectory(store: store, collection: 'services'),
              AnimatedBuilder(
                animation: store,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton.icon(
                      onPressed: () => editContact(context, store),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add Contact'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Add people you trust. Choose who can see your location in Location Tracking & Sharing.',
                      ),
                    ),
                    if (store.personalContacts.isEmpty)
                      const Text(
                        'No personal contacts yet. Add your first trusted contact above.',
                      ),
                    for (final contact in store.personalContacts)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text('${contact['name']}'),
                          subtitle: Text(
                            '${contact['relationship']}\n${contact['phone']}',
                          ),
                          isThreeLine: true,
                          onTap: () =>
                              editContact(context, store, contact: contact),
                          trailing: IconButton(
                            tooltip: 'Remove ${contact['name']}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove contact?'),
                                  content: Text(
                                    'Remove ${contact['name']} and revoke their location link?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                await store.save('contacts', {
                                  'status': 'Inactive',
                                  'shareLocation': false,
                                }, id: '${contact['id']}');
                              } catch (e) {
                                if (context.mounted) {
                                  _notice(
                                    context,
                                    'Contact was not removed. Check your connection and retry.',
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> editContact(
  BuildContext context,
  LocalStore store, {
  Record? contact,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ContactEditor(store: store, contact: contact),
);

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({required this.store, this.contact});
  final LocalStore store;
  final Record? contact;
  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.contact?['name'] as String?,
  );
  late final relationship = TextEditingController(
    text: widget.contact?['relationship'] as String?,
  );
  late final phone = TextEditingController(
    text: widget.contact?['phone'] as String?,
  );
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    relationship.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.save('contacts', {
        'name': name.text.trim(),
        'relationship': relationship.text.trim(),
        'phone': phone.text.trim(),
        'status': 'Active',
        if (widget.contact == null) 'shareLocation': false,
      }, id: widget.contact?['id'] as String?);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Contact was not saved. Check your connection and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.contact == null ? 'Add Contact' : 'Edit Contact'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.trim().isEmpty ? 'Enter a name' : null,
              ),
              TextFormField(
                controller: relationship,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Relationship'),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Enter a relationship' : null,
              ),
              TextFormField(
                controller: phone,
                maxLength: 40,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: (v) =>
                    RegExp(r'^[+\d ()-]{5,40}$').hasMatch(v!.trim())
                    ? null
                    : 'Enter a valid phone number',
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Saving…' : 'Save Contact'),
      ),
    ],
  );
}

class LocationSharing extends StatefulWidget {
  const LocationSharing({super.key, required this.store});
  final LocalStore store;
  @override
  State<LocationSharing> createState() => _LocationSharingState();
}

class _LocationSharingState extends State<LocationSharing> {
  final pending = <String>{};
  bool locating = false;
  Future<void> locate() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      await widget.store.locate();
    } catch (_) {
      /* Store exposes permission/retry guidance. */
    }
    if (mounted) setState(() => locating = false);
  }

  Future<void> toggle(Record contact, bool enabled) async {
    final id = '${contact['id']}';
    setState(() => pending.add(id));
    try {
      await widget.store.save('contacts', {'shareLocation': enabled}, id: id);
      if (enabled) {
        await locate();
        await widget.store.publishLocation();
      }
    } catch (_) {
      if (mounted) {
        _notice(
          context,
          'Sharing setting was not saved. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final position = store.devicePosition;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Location Tracking & Sharing',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'My Location',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Text(
            'Location updates automatically while SafeUG is open. Your device may ask for location permission.',
          ),
          const SizedBox(height: 12),
          if (position != null) ...[
            SizedBox(
              height: 240,
              child: FlutterMap(
                key: ValueKey('${position.latitude}:${position.longitude}'),
                options: MapOptions(
                  initialCenter: LatLng(position.latitude, position.longitude),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.safeug.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(position.latitude, position.longitude),
                        child: const Icon(
                          Icons.my_location,
                          size: 32,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              'Accuracy ${position.accuracy.round()} m • Updated ${position.timestamp.toLocal()}',
            ),
          ] else
            Text(store.locationError ?? 'Finding your current location…'),
          TextButton.icon(
            onPressed: locating ? null : locate,
            icon: const Icon(Icons.my_location),
            label: Text(
              locating ? 'Finding location…' : 'Refresh current location',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Location Sharing',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Text(
            'Choose which emergency contacts can view your location. Turn on sharing, then send that contact their private link. Turning it off revokes the link. A link expires after two minutes without a fresh location.',
          ),
          if (store.sharingError != null)
            Text(
              store.sharingError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          if (store.personalContacts.isEmpty)
            const Text('Add a trusted contact to start sharing.'),
          for (final contact in store.personalContacts)
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('${contact['name']}'),
                    subtitle: Text(
                      '${contact['relationship']} • ${contact['phone']}',
                    ),
                    secondary: const Icon(Icons.person_outline),
                    value: contact['shareLocation'] == true,
                    onChanged: pending.contains('${contact['id']}')
                        ? null
                        : (value) => toggle(contact, value),
                  ),
                  if (contact['shareLocation'] == true &&
                      contact['shareToken'] != null)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.sms_outlined),
                          label: const Text('Send private link'),
                          onPressed: () async {
                            final link =
                                '${store.endpoint}/share/${contact['shareToken']}';
                            final uri = Uri(
                              scheme: 'sms',
                              path: '${contact['phone']}',
                              query:
                                  'body=${Uri.encodeComponent('View my SafeUG location: $link')}',
                            );
                            if (!await launchUrl(uri) && context.mounted) {
                              _notice(
                                context,
                                'Messaging is unavailable. Copy the link and send it to this contact.',
                              );
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy private link'),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    '${store.endpoint}/share/${contact['shareToken']}',
                              ),
                            );
                            if (context.mounted) {
                              _notice(
                                context,
                                'Private link copied. Send it only to ${contact['name']}.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => editContact(context, store),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Contact'),
          ),
        ],
      );
    },
  );
}
