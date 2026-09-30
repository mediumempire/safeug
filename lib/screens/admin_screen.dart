import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import 'operations_records.dart';

/// The same incident documents are read by the mobile status screen.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _page = 0;
  String _query = '';
  String _status = 'All';
  final _db = FirebaseFirestore.instance;
  late final _incidents = _db.collectionGroup('incidentReports').snapshots();
  static const _pages = [
    'Overview',
    'Incidents',
    'Community reports',
    'Tourists',
    'Connections',
    'Rangers',
    'Protected areas',
    'Wildlife',
    'Field devices',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.warning_amber_rounded,
    Icons.assignment_outlined,
    Icons.people_outline,
    Icons.hub_outlined,
    Icons.badge_outlined,
    Icons.park_outlined,
    Icons.pets_outlined,
    Icons.cell_tower,
  ];
  static const _statuses = [
    'Reported',
    'Active',
    'Dispatched',
    'En Route',
    'Resolved',
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final navigation = Container(
      width: 224,
      color: const Color(0xFF002E25),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Color(0xFF68D995)),
                  SizedBox(width: 10),
                  Text(
                    'SafeUG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 14),
              child: Text(
                'OPERATIONS',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
            for (var i = 0; i < _pages.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: ListTile(
                  selected: i == _page,
                  selectedTileColor: const Color(0xFF00684B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  leading: Icon(_icons[i], color: Colors.white70, size: 21),
                  title: Text(
                    _pages[i],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  onTap: () {
                    setState(() {
                      _page = i;
                      _query = '';
                    });
                    if (!wide) Navigator.pop(context);
                  },
                ),
              ),
            const Spacer(),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text(
                'Sign out',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      drawer: wide ? null : Drawer(child: navigation),
      body: Row(
        children: [
          if (wide) navigation,
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: Text(_pages[_page]),
                  automaticallyImplyLeading: !wide,
                  actions: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Chip(
                        avatar: Icon(Icons.shield_outlined, size: 16),
                        label: Text('Operations console'),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 28 : 16),
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_page >= 5) {
      return OperationsRecords(
        key: ValueKey(_page),
        collection: [
          'rangers',
          'protectedAreas',
          'wildlife',
          'fieldDevices',
        ][_page - 5],
        title: _pages[_page],
      );
    }
    if (_page == 4) {
      return ListView(
        children: const [
          Text(
            'Service connections',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Firebase'),
            subtitle: Text(
              'Incident and profile records use the configured Firebase project. Access depends on your assigned role.',
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.cell_tower),
            title: Text('Off-grid transport'),
            subtitle: Text(
              'Not connected. Device storage preserves pending SOS records; radio, satellite and SMS gateways require provisioning.',
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.public),
            title: Text('EarthRanger'),
            subtitle: Text(
              'Not configured. No conservation data has been synced.',
            ),
          ),
        ],
      );
    }
    if (_page == 2 || _page == 3) {
      return _records(_page == 2 ? 'communityReports' : 'tourists');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _incidents,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _error(
            'Incident data could not be loaded. Check your administrator role and Firestore rules.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) => _date(b.data()).compareTo(_date(a.data())));
        final filtered = docs
            .where(
              (d) =>
                  (_status == 'All' || d.data()['status'] == _status) &&
                  '${d.id} ${d.data()['incidentType']} ${d.data()['reporterTouristId']}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList();
        return ListView(
          children: [
            Text(
              _page == 0 ? 'Safety operations' : 'Incident management',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.data!.metadata.isFromCache
                  ? 'Cached records. Waiting for the server.'
                  : 'Shared incident records',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  'All incidents',
                  docs.length,
                  Icons.assignment_outlined,
                  Colors.blue,
                ),
                _metric(
                  'Awaiting response',
                  docs.where((d) => d.data()['status'] == 'Reported').length,
                  Icons.notification_important_outlined,
                  Colors.red,
                ),
                _metric(
                  'In progress',
                  docs
                      .where(
                        (d) => [
                          'Active',
                          'Dispatched',
                          'En Route',
                        ].contains(d.data()['status']),
                      )
                      .length,
                  Icons.local_shipping_outlined,
                  Colors.orange,
                ),
                _metric(
                  'Resolved',
                  docs.where((d) => d.data()['status'] == 'Resolved').length,
                  Icons.check_circle_outline,
                  AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search incidents or reporter ID',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ['All', ..._statuses]
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No incidents match this view.')),
              ),
            for (final doc in filtered)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFE4E6),
                    child: Icon(
                      doc.data()['status'] == 'Resolved'
                          ? Icons.check
                          : Icons.warning_amber,
                      color: AppColors.danger,
                    ),
                  ),
                  title: Text(
                    '${doc.data()['incidentType'] ?? 'Incident'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${doc.data()['status'] ?? 'Reported'}  |  ${_date(doc.data()).toLocal().toString().split('.').first}\n${doc.id}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _details(doc),
                ),
              ),
          ],
        );
      },
    );
  }

  DateTime _date(Map<String, dynamic> data) =>
      (data['reportedAt'] as Timestamp?)?.toDate() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Widget _metric(String label, int count, IconData icon, Color color) =>
      SizedBox(
        width: 205,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12)),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _error(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _records(
    String collection,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _db.collection(collection).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('Records unavailable. Check access permissions.');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = snapshot.data!.docs;
      if (records.isEmpty) {
        return const Center(child: Text('No records have been submitted yet.'));
      }
      return ListView.separated(
        itemCount: records.length,
        separatorBuilder: (_, index) => const Divider(),
        itemBuilder: (context, index) {
          final record = records[index];
          final data = record.data();
          return ListTile(
            leading: Icon(
              collection == 'tourists'
                  ? Icons.person_outline
                  : Icons.description_outlined,
            ),
            title: Text(
              '${data['reportType'] ?? data['homeCountry'] ?? record.id}',
            ),
            subtitle: Text(
              collection == 'tourists'
                  ? 'ID: ${record.id}\nLocation sharing: ${data['locationSharingEnabled'] == true ? 'Enabled' : 'Disabled'}'
                  : '${data['location'] ?? ''}\n${data['description'] ?? ''}',
            ),
            isThreeLine: true,
          );
        },
      );
    },
  );

  Future<void> _details(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    String? failure;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Incident details'),
          content: SizedBox(
            width: 460,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: doc.reference.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? doc.data();
                final latitude = data['initialLatitude'];
                final longitude = data['initialLongitude'];
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        'Reference: ${doc.id}\nReporter: ${data['reporterTouristId']}',
                      ),
                      const SizedBox(height: 16),
                      Text('${data['description'] ?? ''}'),
                      const SizedBox(height: 16),
                      Text('Status: ${data['status']}'),
                      const SizedBox(height: 12),
                      if (latitude is num &&
                          longitude is num &&
                          !(latitude == 0 && longitude == 0))
                        TextButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: Text('$latitude, $longitude'),
                          onPressed: () async {
                            final opened = await launchUrl(
                              Uri.https('www.google.com', '/maps/search/', {
                                'api': '1',
                                'query': '$latitude,$longitude',
                              }),
                            );
                            if (!opened && context.mounted) {
                              refresh(
                                () => failure = 'Could not open the map.',
                              );
                            }
                          },
                        )
                      else
                        const Text('No GPS coordinates supplied.'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statuses
                            .map(
                              (status) => OutlinedButton(
                                onPressed: saving || data['status'] == status
                                    ? null
                                    : () async {
                                        refresh(() {
                                          saving = true;
                                          failure = null;
                                        });
                                        try {
                                          await doc.reference
                                              .update({
                                                'status': status,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                                'updatedBy': FirebaseAuth
                                                    .instance
                                                    .currentUser!
                                                    .uid,
                                              })
                                              .timeout(
                                                const Duration(seconds: 12),
                                              );
                                        } catch (_) {
                                          if (context.mounted) {
                                            refresh(
                                              () => failure =
                                                  'Update not confirmed. Check the connection and permissions.',
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            refresh(() => saving = false);
                                          }
                                        }
                                      },
                                child: Text(status),
                              ),
                            )
                            .toList(),
                      ),
                      if (saving) const LinearProgressIndicator(),
                      if (failure != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            failure!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
