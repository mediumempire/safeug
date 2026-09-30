import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.user});
  final User user;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _firestore = FirestoreService();
  Position? _position;
  String? _locationError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _position = position;
          _locationError = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _locationError = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        const PageIntro(
          title: 'Location Tracking & Sharing',
          subtitle: 'Manage your location sharing settings and view your current location.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My location',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 5),
              const Text(
                'A live view of your current GPS position.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _MapPreview(
                loading: _loading,
                error: _locationError,
                position: _position,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadLocation,
                icon: const Icon(Icons.my_location_rounded, size: 17),
                label: const Text('Refresh location'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location sharing',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose which emergency contacts can see your location.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<EmergencyContact>>(
                stream: _firestore.contactsStream(widget.user.uid),
                builder: (context, snapshot) {
                  final contacts = snapshot.data ?? const <EmergencyContact>[];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (contacts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          'Add emergency contacts to manage sharing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: contacts
                        .map(
                          (contact) => _SharingRow(
                            contact: contact,
                            onChanged: (value) => _firestore.setLocationSharing(
                              widget.user.uid,
                              contact.id,
                              value,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.loading,
    required this.error,
    required this.position,
  });
  final bool loading;
  final String? error;
  final Position? position;

  @override
  Widget build(BuildContext context) {
    Widget label;
    if (loading) {
      label = const Text('Fetching location...');
    } else if (error != null) {
      label = Text(
        error!,
        style: const TextStyle(color: AppColors.danger, fontSize: 12),
      );
    } else {
      label = Text(
        'Current coordinates\nLat: ${position!.latitude.toStringAsFixed(5)}, Lon: ${position!.longitude.toStringAsFixed(5)}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      );
    }
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFB7D9C8), Color(0xFF7CB5D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.map_rounded, color: Colors.white70, size: 74),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: label,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharingRow extends StatelessWidget {
  const _SharingRow({required this.contact, required this.onChanged});
  final EmergencyContact contact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: .12),
            child: const Icon(Icons.person, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  contact.relationship,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: contact.locationSharingEnabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
