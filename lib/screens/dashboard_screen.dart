import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/offline_signal_queue.dart';
import 'safety_screen.dart';
import 'tracking_screen.dart';
import 'translate_screen.dart';
import 'emergency_screen.dart';
import 'guides_screen.dart';
import 'report_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FirestoreService().roleStream('roles_admin', user.uid),
      builder: (context, adminSnapshot) => StreamBuilder<bool>(
        stream: FirestoreService().roleStream('roles_safetyExpert', user.uid),
        builder: (context, expertSnapshot) {
          final isAuthority =
              adminSnapshot.data == true || expertSnapshot.data == true;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: isAuthority
                    ? const AuthorityBanner()
                    : SosButton(user: user),
              ),
              const SizedBox(height: 18),
              ActiveAlertsCard(user: user, isAuthority: isAuthority),
              const SizedBox(height: 22),
              Text(
                isAuthority ? 'Response terminal' : 'Your travel companion',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isAuthority
                    ? 'Manage reports and monitor tourist safety.'
                    : 'Essential tools for your Ugandan adventure.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.08,
                children: [
                  DashboardCard(
                    title: 'Find a Guide',
                    description: 'Certified local experts',
                    icon: Icons.explore_rounded,
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GuidesScreen()),
                    ),
                  ),
                  DashboardCard(
                    title: 'Safety Tips',
                    description: 'Real-time AI alerts',
                    icon: Icons.shield_rounded,
                    color: AppColors.accent,
                    darkIcon: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SafetyScreen()),
                    ),
                  ),
                  DashboardCard(
                    title: 'Translator',
                    description: 'Local languages',
                    icon: Icons.translate_rounded,
                    color: const Color(0xFFB9A7E9),
                    darkIcon: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TranslateScreen(),
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: 'Emergency',
                    description: 'Help services',
                    icon: Icons.favorite_rounded,
                    color: AppColors.danger,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmergencyScreen(),
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: 'Location',
                    description: 'Share status',
                    icon: Icons.my_location_rounded,
                    color: const Color(0xFFA5E0C6),
                    darkIcon: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrackingScreen(user: user),
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: 'SMART Report',
                    description: 'Help the community',
                    icon: Icons.report_problem_rounded,
                    color: const Color(0xFFFFD291),
                    darkIcon: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportScreen(user: user),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class AuthorityBanner extends StatelessWidget {
  const AuthorityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44D92D3A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'AUTHORITY MODE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'National Emergency Response & Monitoring',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radio_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'SYSTEM LINKED: UPF / UPDF / TOURIST POLICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.user});
  final User user;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  final _firestore = FirestoreService();
  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _incidentSubscription;
  String? _incidentId;
  String _status = 'Idle';
  bool _active = false;
  bool _activating = false;
  int _queuedSignals = 0;

  @override
  void initState() {
    super.initState();
    _loadPosition();
    _refreshQueuedSignals();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    try {
      if (!await _ensureLocationPermission()) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {}
  }

  Future<void> _refreshQueuedSignals() async {
    final pending = await OfflineSignalQueue.instance.pending();
    if (mounted) {
      setState(
        () => _queuedSignals = pending
            .where((s) => s.uid == widget.user.uid)
            .length,
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _handleSos() async {
    if (_active) {
      await _deactivate();
      return;
    }
    if (_activating) return;
    setState(() {
      _activating = true;
      _status = 'Alerting';
    });
    try {
      if (_position == null &&
          await _ensureLocationPermission().timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          )) {
        try {
          _position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
      List<EmergencyContact> contacts;
      try {
        contacts = await _firestore
            .contactsStream(widget.user.uid)
            .first
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        contacts = const [];
      }
      final signal = QueuedSosSignal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        uid: widget.user.uid,
        createdAt: DateTime.now(),
        contactIds: contacts.map((contact) => contact.id).toList(),
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        accuracy: _position?.accuracy,
      );
      await OfflineSignalQueue.instance.enqueue(signal);
      try {
        _incidentId = await _firestore
            .createQueuedIncident(signal)
            .timeout(const Duration(seconds: 12));
        await OfflineSignalQueue.instance.remove(signal.id);
        _startTracking();
        _incidentSubscription?.cancel();
        _incidentSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .collection('incidentReports')
            .doc(_incidentId)
            .snapshots()
            .listen((doc) {
              if (mounted && doc.exists) {
                setState(
                  () => _status = '${doc.data()?['status'] ?? 'Reported'}',
                );
              }
            }, onError: (_) {});
      } catch (_) {
        _incidentId = null;
      }
      await _refreshQueuedSignals();
      if (!mounted) return;
      setState(() {
        _active = true;
        _activating = false;
        _status = _incidentId == null ? 'Saved on device' : 'Reported';
      });
      showSafeSnackBar(
        context,
        _incidentId == null
            ? 'SOS saved on this device. Use Retry when a connection is available.'
            : 'SOS received by SafeUG. Awaiting operator response.',
        error: _incidentId != null,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _activating = false;
          _status = 'Idle';
        });
        showSafeSnackBar(
          context,
          'Could not activate SOS: $error',
          error: true,
        );
      }
    }
  }

  Future<void> _retryQueuedSignals() async {
    final delivered = await OfflineSignalQueue.instance.retry(
      _firestore.createQueuedIncident,
      uid: widget.user.uid,
    );
    await _refreshQueuedSignals();
    if (!mounted) return;
    showSafeSnackBar(
      context,
      delivered == 0
          ? 'No queued SOS signals could be delivered yet.'
          : '$delivered queued SOS signal${delivered == 1 ? '' : 's'} delivered.',
    );
  }

  void _startTracking() {
    if (_incidentId == null) return;
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          _position = position;
          _firestore.appendLocation(
            uid: widget.user.uid,
            incidentId: _incidentId!,
            position: position,
          );
          if (mounted) setState(() {});
        });
  }

  Future<void> _deactivate() async {
    final id = _incidentId;
    _stopTracking();
    if (id != null) {
      await _firestore.setIncidentStatus(
        uid: widget.user.uid,
        incidentId: id,
        status: 'Resolved',
      );
    }
    if (!mounted) return;
    setState(() {
      _active = false;
      _status = 'Idle';
      _incidentId = null;
    });
    showSafeSnackBar(context, 'SOS system returned to standby.');
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _incidentSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final coordinateText = _position == null
        ? 'GPS awaiting permission'
        : '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}';
    return Column(
      children: [
        GestureDetector(
          onTap: _handleSos,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _active ? Colors.black : AppColors.danger,
              border: Border.all(
                color: AppColors.danger.withValues(alpha: .22),
                width: 12,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x66D92D3A), blurRadius: 42),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _activating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(
                        _active
                            ? Icons.shield_rounded
                            : Icons.phone_in_talk_rounded,
                        color: _active ? Colors.redAccent : Colors.white,
                        size: 50,
                      ),
                const SizedBox(height: 5),
                Text(
                  _active ? 'ACTIVE' : 'SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_active) ...[
          const SizedBox(height: 20),
          Text(
            'LIVE GPS STREAM: $coordinateText',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Chip(
            avatar: const Icon(
              Icons.radio_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            label: Text(
              'STATUS: $_status',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            backgroundColor: AppColors.primary.withValues(alpha: .08),
            side: BorderSide.none,
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Send SOS to SafeUG',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        if (_queuedSignals > 0) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _retryQueuedSignals,
            icon: const Icon(Icons.sync_rounded),
            label: Text(
              'Retry $_queuedSignals queued SOS signal${_queuedSignals == 1 ? '' : 's'}',
            ),
          ),
        ],
      ],
    );
  }
}

class ActiveAlertsCard extends StatelessWidget {
  const ActiveAlertsCard({
    super.key,
    required this.user,
    required this.isAuthority,
  });
  final User user;
  final bool isAuthority;

  @override
  Widget build(BuildContext context) {
    final stream = isAuthority
        ? FirebaseFirestore.instance
              .collectionGroup('incidentReports')
              .snapshots()
              .map(
                (snapshot) => snapshot.docs
                    .map(IncidentReport.fromDocument)
                    .where(
                      (report) => const [
                        'Reported',
                        'Active',
                        'Dispatched',
                        'En Route',
                      ].contains(report.status),
                    )
                    .toList(),
              )
        : FirestoreService().touristIncidentsStream(user.uid);
    return StreamBuilder<List<IncidentReport>>(
      stream: stream,
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <IncidentReport>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(child: LinearProgressIndicator());
        }
        if (reports.isEmpty) {
          if (!isAuthority) return const SizedBox.shrink();
          return AppCard(
            child: Column(
              children: [
                Icon(
                  Icons.radar_rounded,
                  color: AppColors.muted.withValues(alpha: .5),
                  size: 30,
                ),
                const SizedBox(height: 8),
                const Text(
                  'AUTHORITY MONITOR ACTIVE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scanning the national grid for distress signals...',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: isAuthority ? AppColors.danger : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAuthority
                        ? 'Command Center: Active Alerts'
                        : 'Emergency Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isAuthority ? AppColors.danger : AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isAuthority)
                  const Chip(
                    label: Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...reports
                .take(5)
                .map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            color: isAuthority
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isAuthority
                                      ? 'Tracking tourist ${report.reporterId.substring(0, report.reporterId.length < 8 ? report.reporterId.length : 8)}…'
                                      : 'Status updated by the response team.',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(
                              report.status,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.darkIcon = false,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool darkIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: darkIcon ? AppColors.ink : Colors.white,
              size: 27,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: darkIcon ? AppColors.ink : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: (darkIcon ? AppColors.ink : Colors.white).withValues(
                      alpha: .72,
                    ),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
