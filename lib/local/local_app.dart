import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import 'local_store.dart';
import 'server_config.dart';
import 'guide_card.dart';
import 'mobile_tools.dart';
import 'device_location.dart';
import 'incident_contract.dart';
import 'theme_controller.dart';
import 'emergency_center.dart';
import 'sos_button.dart';
import 'alert_controller.dart';

const forest = Color(0xFF003A2D);
const statuses = incidentStatuses;

class SafeUgLocalApp extends StatefulWidget {
  const SafeUgLocalApp({super.key, this.adminApp = false});
  final bool adminApp;
  @override
  State<SafeUgLocalApp> createState() => _SafeUgLocalAppState();
}

class _SafeUgLocalAppState extends State<SafeUgLocalApp> {
  late final store = LocalStore(adminApp: widget.adminApp);
  late final theme = ThemeController(adminApp: widget.adminApp);
  @override
  void initState() {
    super.initState();
    unawaited(store.initialize());
    unawaited(theme.initialize());
  }

  @override
  void dispose() {
    store.dispose();
    theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ThemeScope(
    controller: theme,
    child: AnimatedBuilder(
      animation: theme,
      builder: (_, _) => MaterialApp(
        title: 'SafeUG',
        debugShowCheckedModeBanner: false,
        theme: buildSafeUgTheme(brightness: Brightness.light),
        darkTheme: buildSafeUgTheme(brightness: Brightness.dark),
        themeMode: theme.mode,
        home: AnimatedBuilder(
          animation: store,
          builder: (context, _) => store.ready
              ? widget.adminApp && !store.authenticated
                    ? AdminLogin(store: store)
                    : LocalShell(store: store)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    ),
  );
}

class LocalShell extends StatefulWidget {
  const LocalShell({super.key, required this.store, this.currentPosition});
  final LocalStore store;
  final Future<Position> Function()? currentPosition;
  @override
  State<LocalShell> createState() => _LocalShellState();
}

class _LocalShellState extends State<LocalShell> {
  LocalStore get store => widget.store;
  late final alerts = AlertController(store);
  int _page = 0;
  int _mobilePage = 0;
  String _search = '';
  String _filter = 'All';
  bool _sending = false;
  bool _locating = false;
  Future<void>? _locationRequest;
  Position? _position;
  bool _storeChangeScheduled = false;
  final _mapController = MapController();
  final _viewRevision = ValueNotifier(0);
  Timer? _locationTimer;
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    store.addListener(_storeChanged);
    unawaited(alerts.initialize());
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        if (_foreground && mounted) {
          unawaited(_locate());
          unawaited(alerts.refreshPermission());
          unawaited(store.sync());
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_locate());
    });
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _foreground && _position != null) unawaited(_locate());
    });
  }

  void _storeChanged() {
    if (_storeChangeScheduled || !mounted) return;
    _storeChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _storeChangeScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    store.removeListener(_storeChanged);
    alerts.dispose();
    _locationTimer?.cancel();
    _lifecycle.dispose();
    _mapController.dispose();
    _viewRevision.dispose();
    super.dispose();
  }

  static const labels = [
    'Overview',
    'Map & operations',
    'Incidents',
    'Rangers',
    'Tourists',
    'Protected areas',
    'Wildlife',
    'Field devices',
    'Reports',
    'Settings',
    'Tour guides',
    'Safety tips',
    'Emergency services',
    'Location sharing',
    'Ranger welfare',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.map_outlined,
    Icons.warning_amber_rounded,
    Icons.badge_outlined,
    Icons.people_outline,
    Icons.park_outlined,
    Icons.pets_outlined,
    Icons.cell_tower,
    Icons.bar_chart,
    Icons.settings_outlined,
    Icons.hiking,
    Icons.health_and_safety_outlined,
    Icons.emergency_outlined,
    Icons.share_location,
    Icons.monitor_heart_outlined,
  ];
  static const collections = {
    2: 'incidents',
    3: 'rangers',
    4: 'tourists',
    5: 'parks',
    6: 'wildlife',
    7: 'devices',
    10: 'guides',
    11: 'tips',
    12: 'services',
    13: 'locations',
    14: 'welfare',
  };

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _locate({bool centerMap = false}) async {
    await (_locationRequest ??= _readLocation().whenComplete(
      () => _locationRequest = null,
    ));
    final position = _position;
    if (centerMap && mounted && position != null) {
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    } else if (centerMap && mounted && position == null) {
      _message(
        store.locationError ??
            'Location is unavailable. Check your device permissions.',
      );
    }
  }

  Future<void> _readLocation() async {
    setState(() => _locating = true);
    try {
      final position = await store.locate(provider: widget.currentPosition);
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _position = null;
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _sos() async {
    if (_sending) return;
    if (store.activeSos != null) {
      await _standDown();
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await store.signal({
        'type': 'SOS',
        'severity': 'Critical',
        'description': 'Emergency assistance requested.',
        'reporter': store.touristProfile?['name'] ?? 'Guest',
        'phone': store.touristProfile?['phone'] ?? '',
        'area': store.touristProfile?['area'] ?? '',
      });
      if (mounted) {
        setState(() => _mobilePage = 0);
        unawaited(_attachSosLocation(id));
      }
    } catch (e) {
      _message('Could not save SOS: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachSosLocation(String id) async {
    await _locate();
    if (!mounted) return;
    final position = _position;
    if (position == null ||
        DateTime.now().difference(position.timestamp).inMinutes > 1) {
      return;
    }
    try {
      await store.updateIncidentLocation(id, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'locationCapturedAt': position.timestamp.toUtc().toIso8601String(),
      });
    } catch (error) {
      _message(
        'SOS remains active. Location update could not be saved: $error',
      );
    }
  }

  Future<void> _standDown() async {
    final sos = store.activeSos;
    if (sos == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this SOS?'),
        content: const Text(
          'Only end the alert if you are safe or activated it accidentally. Administrators will receive your stand-down update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep SOS active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I am safe — end SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await store.closeSos('${sos['id']}');
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    } catch (error) {
      _message('Could not end SOS: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final admin = store.adminApp;
    final nav = _sidebar();
    return Scaffold(
      drawer: admin && !wide ? Drawer(child: nav) : null,
      body: Row(
        children: [
          if (admin && wide) SizedBox(width: 222, child: nav),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: admin
                      ? Text(
                          labels[_page],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const SafeUgLogo(),
                  actions: [
                    const ThemeToggleButton(),
                    AnimatedBuilder(
                      animation: alerts,
                      builder: (context, _) => IconButton(
                        tooltip: alerts.permission == 'granted'
                            ? 'System notifications enabled'
                            : 'Enable system notifications',
                        icon: Icon(
                          alerts.permission == 'granted'
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_outlined,
                        ),
                        onPressed: () async {
                          await alerts.enable();
                          if (mounted && alerts.permission != 'granted') {
                            _message(
                              'Allow notifications in your device or browser settings to receive emergency alerts.',
                            );
                          }
                        },
                      ),
                    ),
                    Tooltip(
                      message: store.connected
                          ? 'SafeUG connected'
                          : 'SafeUG offline',
                      child: Icon(
                        store.connected
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: store.connected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (admin)
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () async {
                          await alerts.platform.clear();
                          await store.logout();
                        },
                        icon: const Icon(Icons.logout),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
                if (admin || !store.connected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 7,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Text(
                      '${store.connected ? 'Connected to SafeUG' : 'Offline — reports saved on this device'}${store.queue.isEmpty ? '' : '  /  ${store.queue.length} pending'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (admin) _urgentSosBanner(),
                Expanded(
                  child: admin
                      ? Padding(
                          padding: EdgeInsets.all(wide ? 28 : 16),
                          child: _adminBody(),
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _mobileBody(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: admin
          ? null
          : NavigationBar(
              selectedIndex: _mobilePage,
              onDestinationSelected: (i) {
                if (i == 2) {
                  _edit('incidents');
                } else {
                  setState(() => _mobilePage = i);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  label: 'Report',
                ),
              ],
            ),
    );
  }

  Widget _sidebar() => Material(
    color: forest,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 22, 30),
            child: Row(
              children: [
                Image.asset(
                  safeUgLogoAsset,
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                SizedBox(width: 9),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SafeUG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'CONSERVATION & SAFETY',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: labels.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  selected: i == _page,
                  selectedTileColor: const Color(0xFF08674D),
                  leading: Icon(icons[i], color: Colors.white70, size: 20),
                  title: Text(
                    labels[i],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  onTap: () {
                    setState(() {
                      _page = i;
                      _search = '';
                      _filter = 'All';
                    });
                    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          const ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF165D4D),
              child: Icon(Icons.computer, color: Colors.white),
            ),
            title: Text(
              'Local administrator',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            subtitle: Text(
              'SafeUG workspace',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

  Widget _adminBody() {
    if (_page == 0) return _overview();
    if (_page == 1) return _map();
    if (_page == 8) return _reports();
    if (_page == 9) return _settings();
    final collection = collections[_page]!;
    return _table(collection, labels[_page]);
  }

  Widget _urgentSosBanner() {
    final pending =
        store
            .records('incidents')
            .where((r) => isSosIncident(r) && r['status'] == 'Reported')
            .toList()
          ..sort(
            (a, b) => '${b['reportedAt']}'.compareTo('${a['reportedAt']}'),
          );
    if (pending.isEmpty) return const SizedBox.shrink();
    final first = pending.first;
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.emergency,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(
          'SOS emergency • ${pending.length} awaiting response',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${first['reporter'] ?? 'Guest'} • ${first['area']?.toString().isNotEmpty == true ? first['area'] : 'Location pending'}',
        ),
        trailing: FilledButton(
          onPressed: () => _details(first),
          child: const Text('Review SOS'),
        ),
      ),
    );
  }

  List<Record> get incidents =>
      [...store.records('incidents')]
        ..sort((a, b) => '${b['reportedAt']}'.compareTo('${a['reportedAt']}'));
  Widget _overview() => ListView(
    children: [
      const Text(
        'Your safety network, at a glance',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        'Uganda wildlife & tourism operations',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, size) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'Rangers',
              store.records('rangers').length,
              Icons.badge_outlined,
              AppColors.primary,
              size.maxWidth,
            ),
            _metric(
              'Tourists',
              store.records('tourists').length,
              Icons.people_outline,
              Colors.blue,
              size.maxWidth,
            ),
            _metric(
              'Open incidents',
              incidents.where(isOpenIncident).length,
              Icons.warning_amber,
              AppColors.danger,
              size.maxWidth,
            ),
            _metric(
              'Protected areas',
              store.records('parks').length,
              Icons.park_outlined,
              Colors.deepPurple,
              size.maxWidth,
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      LayoutBuilder(
        builder: (context, size) {
          final map = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Field locations',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 345,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _map(),
                ),
              ),
            ],
          );
          final activity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent incidents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _page = 2),
                    child: const Text('View all'),
                  ),
                ],
              ),
              if (incidents.isEmpty)
                _empty(
                  'No incidents reported',
                  'Signals from the mobile view will appear here.',
                ),
              for (final item in incidents.take(4)) _incidentTile(item),
            ],
          );
          return size.maxWidth > 750
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: map),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: activity),
                  ],
                )
              : Column(children: [map, const SizedBox(height: 24), activity]);
        },
      ),
      const SizedBox(height: 24),
      const Text(
        'Quick actions',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => _edit('incidents'),
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Report incident'),
          ),
          OutlinedButton.icon(
            onPressed: () => _edit('rangers'),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add ranger'),
          ),
          OutlinedButton.icon(
            onPressed: store.sync,
            icon: const Icon(Icons.sync),
            label: const Text('Sync now'),
          ),
        ],
      ),
    ],
  );

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
    double width,
  ) => SizedBox(
    width: width >= 800 ? (width - 36) / 4 : (width - 12) / 2,
    child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E9E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value',
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

  Widget _mobileBody() {
    if (_mobilePage == 1) return _map();
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        const Text(
          'Help is one tap away',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'SafeUG field companion',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 25),
        Center(
          child: SosButton(
            active: store.activeSos != null,
            busy: _sending,
            onPressed: _sos,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          store.activeSos == null
              ? 'Tap SOS to alert SafeUG operations with your current location.'
              : 'SOS is active. Tap again only when you are safe.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        if (store.activeSos != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                mobileIncidentStatus(
                  store.activeSos!,
                  queued: store.isQueued('${store.activeSos!['id']}'),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => _edit('incidents'),
          icon: const Icon(Icons.edit_note),
          label: const Text('Report an incident'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your travel companion',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 112,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _companionTool(
              'Find a guide',
              Icons.hiking,
              () => _openPage(
                'Tour guides',
                () => PublishedDirectory(store: store, collection: 'guides'),
              ),
            ),
            _companionTool(
              'Safety tips',
              Icons.health_and_safety_outlined,
              () => _openPage(
                'Safety tips',
                () => PublishedDirectory(store: store, collection: 'tips'),
              ),
            ),
            _companionTool(
              'Translator',
              Icons.translate,
              () =>
                  _openPage('Translator', () => VoiceTranslator(store: store)),
            ),
            _companionTool(
              'Emergency',
              Icons.emergency_outlined,
              () => _openPage(
                'Emergency Center',
                () => EmergencyCenter(store: store),
              ),
            ),
            _companionTool(
              'Share location',
              Icons.share_location,
              () => _openPage(
                'Location sharing',
                () => LocationSharing(store: store),
              ),
            ),
            _companionTool(
              'Community report',
              Icons.edit_note_outlined,
              () => _edit('incidents'),
            ),
            _companionTool(
              'Protected areas',
              Icons.park_outlined,
              () => _openPage(
                'Protected areas',
                () => PublishedDirectory(store: store, collection: 'parks'),
              ),
            ),
            _companionTool(
              'Ranger check-in',
              Icons.monitor_heart_outlined,
              () => _edit('welfare'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _touristProfileTile(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Connection settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPage('Settings', _settings),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mobilePage = 1),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Open field map'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (store.queue.isNotEmpty)
          TextButton.icon(
            onPressed: store.sync,
            icon: const Icon(Icons.sync),
            label: const Text('Retry pending reports'),
          ),
      ],
    );
  }

  void _openPage(String title, Widget Function() body) {
    _search = '';
    _filter = 'All';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AnimatedBuilder(
            animation: Listenable.merge([store, _viewRevision]),
            builder: (_, _) =>
                Padding(padding: const EdgeInsets.all(16), child: body()),
          ),
        ),
      ),
    );
  }

  Widget _companionTool(String label, IconData icon, VoidCallback onTap) =>
      Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _incidentTile(Record item) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFFFE9E9),
      child: Icon(
        item['status'] == 'Resolved' ? Icons.check : Icons.warning_amber,
        color: AppColors.danger,
      ),
    ),
    title: Text(
      '${item['type'] ?? 'SOS'}',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${item['area'] ?? 'Location not specified'}\n${item['status']}',
    ),
    isThreeLine: true,
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _details(item),
  );

  Widget _empty(String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 16),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 35, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _table(String collection, String title) {
    final list = store
        .records(collection)
        .where(
          (r) =>
              '${r['name']} ${r['type']} ${r['area']} ${r['description']}'
                  .toLowerCase()
                  .contains(_search.toLowerCase()) &&
              (_filter == 'All' || r['status'] == _filter),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _edit(collection),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add record'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search records',
          ),
          onChanged: (q) {
            setState(() => _search = q);
            _viewRevision.value++;
          },
        ),
        if (collection == 'incidents') ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['All', ...statuses]
                .map(
                  (s) => ChoiceChip(
                    label: Text(s),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: _empty(
                    'No matching records',
                    'Add a record to start building your local workspace.',
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth <
                        (collection == 'guides' ? 1100 : 640)) {
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => collection == 'incidents'
                            ? _incidentTile(list[i])
                            : collection == 'guides'
                            ? Column(
                                children: [
                                  GuideCard(store: store, guide: list[i]),
                                  TextButton.icon(
                                    onPressed: () => _edit(collection, list[i]),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit guide'),
                                  ),
                                ],
                              )
                            : ListTile(
                                title: Text('${list[i]['name']}'),
                                subtitle: Text(
                                  '${list[i]['area'] ?? ''}\n${list[i]['status'] ?? 'Active'}',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(collection, list[i]),
                                ),
                              ),
                      );
                    }
                    return SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll(
                            Theme.of(context).colorScheme.surfaceContainer,
                          ),
                          columns: [
                            const DataColumn(label: Text('Name / type')),
                            if (collection == 'guides')
                              const DataColumn(label: Text('Visitor rating')),
                            const DataColumn(label: Text('Area')),
                            const DataColumn(label: Text('Status')),
                            const DataColumn(label: Text('Updated')),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: list
                              .map(
                                (r) => DataRow(
                                  cells: [
                                    DataCell(Text('${r['name'] ?? r['type']}')),
                                    if (collection == 'guides')
                                      DataCell(GuideRatingSummary(guide: r)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          '${r['area'] ?? '-'}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      _badge('${r['status'] ?? 'Active'}'),
                                    ),
                                    DataCell(
                                      Text(
                                        _date(
                                          r['updatedAt'] ?? r['reportedAt'],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        tooltip: collection == 'incidents'
                                            ? 'Open incident'
                                            : 'Edit record',
                                        icon: const Icon(
                                          Icons.open_in_new,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            collection == 'incidents'
                                            ? _details(r)
                                            : _edit(collection, r),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _date(dynamic value) {
    final time = DateTime.tryParse('$value')?.toLocal();
    return time == null
        ? '-'
        : '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _badge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: status == 'Reported'
          ? const Color(0xFFFFE9E9)
          : const Color(0xFFE6F4EB),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      status,
      style: TextStyle(
        fontSize: 11,
        color: status == 'Reported' ? AppColors.danger : AppColors.primary,
      ),
    ),
  );

  Widget _map() {
    final points = <Record>[];
    for (final kind
        in store.adminApp
            ? [
                'parks',
                'rangers',
                'tourists',
                'incidents',
                'wildlife',
                'locations',
              ]
            : ['parks', 'locations']) {
      for (final r in store.records(kind)) {
        if (r['latitude'] is num &&
            r['longitude'] is num &&
            (kind != 'locations' || r['status'] == 'Sharing')) {
          points.add({...r, 'kind': kind});
        }
      }
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(1.2, 32.2),
            initialZoom: 7,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.safeug.app',
            ),
            MarkerLayer(
              markers: [
                if (_position != null)
                  Marker(
                    point: LatLng(_position!.latitude, _position!.longitude),
                    width: 44,
                    height: 44,
                    child: const Tooltip(
                      message: 'Your current location',
                      child: Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  ),
                ...points.map(
                  (r) => Marker(
                    point: LatLng(
                      (r['latitude'] as num).toDouble(),
                      (r['longitude'] as num).toDouble(),
                    ),
                    width: 42,
                    height: 42,
                    child: IconButton(
                      tooltip: '${r['name'] ?? r['type']}',
                      icon: Icon(
                        Icons.location_on,
                        color: r['kind'] == 'incidents'
                            ? AppColors.danger
                            : AppColors.primary,
                        size: 32,
                      ),
                      onPressed: () => r['kind'] == 'incidents'
                          ? _details(r)
                          : _edit('${r['kind']}', r),
                    ),
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${points.length} recorded locations  /  Basemap requires internet',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 45,
          child: FilledButton.icon(
            onPressed: _locating ? null : () => _locate(centerMap: true),
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? 'Locating…' : 'My location'),
          ),
        ),
      ],
    );
  }

  Widget _reports() => ListView(
    children: [
      const Text(
        'Reports & analytics',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 24),
      Text(
        '${incidents.length} total incidents',
        style: const TextStyle(fontSize: 20),
      ),
      const SizedBox(height: 20),
      for (final status in statuses)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$status  (${incidents.where((r) => r['status'] == status).length})',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: incidents.isEmpty
                    ? 0
                    : incidents.where((r) => r['status'] == status).length /
                          incidents.length,
                minHeight: 12,
                backgroundColor: const Color(0xFFE1EBE6),
              ),
            ],
          ),
        ),
      const Divider(),
      const Text('Counts are calculated from synchronized SafeUG records.'),
    ],
  );

  Widget _settings() => ListView(
    children: [
      const Text(
        'Workspace settings',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 24),
      ListTile(
        leading: const Icon(Icons.storage_outlined),
        title: const Text('SafeUG online service'),
        subtitle: SelectableText(store.endpoint),
      ),
      if (store.error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            store.error!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ListTile(
        leading: Icon(store.connected ? Icons.cloud_done : Icons.cloud_off),
        title: Text(store.connected ? 'Connected' : 'Disconnected'),
        subtitle: Text('${store.queue.length} signals waiting on this device'),
        trailing: IconButton(
          tooltip: 'Sync now',
          onPressed: store.sync,
          icon: const Icon(Icons.sync),
        ),
      ),
      if (!kIsWeb && allowServerOverride)
        TextButton(
          onPressed: _serverSettings,
          child: const Text('Development server address'),
        ),
      const Divider(),
      if (store.adminApp) ...[
        const Text(
          'Provider connections',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final integration in store.records('integrations'))
          ListTile(
            leading: const Icon(Icons.link_off),
            title: Text('${integration['name']}'),
            subtitle: Text(
              '${integration['status']}\n${integration['requirements']}',
            ),
            isThreeLine: true,
          ),
      ],
      const ListTile(
        leading: Icon(Icons.satellite_alt_outlined),
        title: Text('Off-grid gateway'),
        subtitle: Text(
          'Not connected. Alerts are stored on the device until SafeUG can be reached.',
        ),
      ),
      const ListTile(
        leading: Icon(Icons.public),
        title: Text('EarthRanger'),
        subtitle: Text('Not connected.'),
      ),
      const Divider(),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Administrators sign in separately. External responders are not connected. Use verified emergency contacts when immediate assistance is needed.',
        ),
      ),
    ],
  );

  Future<void> _serverSettings() async {
    final controller = TextEditingController(text: store.endpoint);
    await _showManagedDialog<void>(
      (context) => AlertDialog(
        title: const Text('Development service address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.10:8099',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await store.setEndpoint(controller.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                _message('$e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _details(Record initial) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final r =
              store
                  .records('incidents')
                  .where((r) => r['id'] == initial['id'])
                  .firstOrNull ??
              initial;
          final isSaved = store
              .records('incidents')
              .any((v) => v['id'] == r['id']);
          return AlertDialog(
            title: Text('${r['type'] ?? 'SOS'} incident'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        _badge('${r['status']}'),
                        _badge(
                          '${r['severity'] ?? defaultIncidentSeverity(r['type'])}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('${r['description'] ?? ''}'),
                    for (final file in (r['evidence'] as List? ?? []))
                      ListTile(
                        leading: Icon(
                          '${file['mime']}'.startsWith('video/')
                              ? Icons.videocam_outlined
                              : Icons.image_outlined,
                        ),
                        title: Text('${file['name']}'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => EvidenceViewer(
                            store: store,
                            file: Record.from(file as Map),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Reference: ${r['id']}\nArea: ${r['area'] ?? 'Not supplied'}\nOccurred: ${_date(r['occurredAt'] ?? r['reportedAt'])}\nReported: ${_date(r['reportedAt'])}\nReporter: ${r['reporter'] ?? 'Guest'}\nContact: ${r['phone'] ?? 'Not supplied'}\nGPS: ${r['latitude'] ?? '-'}, ${r['longitude'] ?? '-'}\nAccuracy: ${r['accuracy'] ?? '-'} m\nLocation captured: ${_date(r['locationCapturedAt'])}',
                    ),
                    const SizedBox(height: 12),
                    Text(store.responseMessage(r)),
                    if ((r['statusHistory'] as List? ?? []).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Response history',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final event in r['statusHistory'] as List)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${event['status']} · ${_date(event['at'])} · ${event['actor']}',
                          ),
                        ),
                    ],
                    if (isSaved && store.adminApp) ...[
                      TextButton.icon(
                        onPressed: () => _recordResponse(r),
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Record security response'),
                      ),
                      Text(
                        'External gateway: ${r['externalDelivery'] ?? 'Not submitted'}',
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await store.dispatch('${r['id']}');
                            _message(
                              'Submitted to gateway. Responder acceptance is not confirmed.',
                            );
                          } catch (e) {
                            _message('$e');
                          }
                        },
                        icon: const Icon(Icons.emergency_share_outlined),
                        label: const Text('Submit to external dispatch'),
                      ),
                      const SizedBox(height: 20),
                      const Text('Response status'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: statuses
                            .map(
                              (s) => OutlinedButton(
                                onPressed: r['status'] == s
                                    ? null
                                    : () async {
                                        try {
                                          await store.save('incidents', {
                                            'status': s,
                                          }, id: '${r['id']}');
                                        } catch (e) {
                                          _message('Status not saved: $e');
                                        }
                                      },
                                child: Text(s),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _recordResponse(Record incident) async {
    final agency = TextEditingController(
      text: '${incident['responseAgency'] ?? ''}',
    );
    final note = TextEditingController(
      text: '${incident['responseNote'] ?? ''}',
    );
    String status = '${incident['status']}';
    String? error;
    bool saving = false;
    await _showManagedDialog<void>(
      (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Record security response'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Record confirmed contact and response details. These updates are shown to the reporting device.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Response status',
                    ),
                    items: statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: saving ? null : (v) => status = v!,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: agency,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: 'Security agency contacted',
                      hintText: 'Agency or responding unit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: note,
                    enabled: !saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Confirmed response / instructions',
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (agency.text.trim().isEmpty ||
                          note.text.trim().isEmpty) {
                        refresh(
                          () => error =
                              'Enter the contacted agency and confirmed response.',
                        );
                        return;
                      }
                      refresh(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await store.save('incidents', {
                          'status': status,
                          'responseAgency': agency.text.trim(),
                          'responseNote': note.text.trim(),
                        }, id: '${incident['id']}');
                        if (context.mounted) Navigator.pop(context);
                      } catch (failure) {
                        if (context.mounted) {
                          refresh(() {
                            saving = false;
                            error = '$failure';
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save response'),
            ),
          ],
        ),
      ),
    );
    agency.dispose();
    note.dispose();
  }

  Widget _touristProfileTile() => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.person_outline),
    title: Text(
      store.touristProfile == null
          ? 'Register as tourist'
          : 'My tourist profile',
    ),
    subtitle: Text(
      store.pendingProfile != null
          ? 'Saved on device. Waiting to sync.'
          : store.touristProfile == null
          ? 'Optional registration'
          : 'Registered with SafeUG',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TouristRegistration(store: store),
      ),
    ),
  );

  Future<void> _edit(String collection, [Record? current]) async {
    if (collection == 'incidents' && current == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FieldReport(store: store)),
      );
      return;
    }
    if (!store.adminApp && !['welfare', 'contacts'].contains(collection)) {
      return;
    }
    final incident = collection == 'incidents';
    final fields = <String, TextEditingController>{
      for (final key in [
        'name',
        'area',
        'description',
        'phone',
        'health',
        'battery',
        if (collection == 'tourists') ...[
          'email',
          'country',
          'emergencyContactName',
          'emergencyContactPhone',
        ],
      ])
        key: TextEditingController(text: '${current?[key] ?? ''}'),
    };
    String type = '${current?['type'] ?? 'Medical'}';
    String status = '${current?['status'] ?? 'Active'}';
    bool busy = false;
    bool locating = false;
    Position? capturedPosition = current == null ? store.devicePosition : null;
    String? locationNote = capturedPosition == null
        ? null
        : 'Current device location attached automatically.';
    String? error;
    await _showManagedDialog<void>(
      (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(
            incident
                ? 'Report incident'
                : '${current == null ? 'Add' : 'Edit'} ${collection == 'parks' ? 'protected area' : collection}',
          ),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (incident)
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Incident type',
                      ),
                      items:
                          [
                                'Medical',
                                'Poaching',
                                'Lost tourist',
                                'Wildlife',
                                'Fire',
                                'Other',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (v) => type = v!,
                    )
                  else
                    TextField(
                      controller: fields['name'],
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fields['area'],
                    decoration: const InputDecoration(labelText: 'Park / area'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fields['description'],
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description / notes',
                    ),
                  ),
                  if (!incident) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items:
                          [
                                'Active',
                                'On patrol',
                                'Off duty',
                                'Needs attention',
                                'Inactive',
                                'Sharing',
                                'Stopped',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (v) => status = v!,
                    ),
                  ],
                  if ([
                    'rangers',
                    'tourists',
                    'contacts',
                    'guides',
                    'services',
                  ].contains(collection)) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fields['phone'],
                      decoration: InputDecoration(
                        labelText: collection == 'guides'
                            ? 'Phone / WhatsApp number'
                            : 'Phone',
                        helperText: collection == 'guides'
                            ? 'Use a WhatsApp number, e.g. +256700123456.'
                            : null,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                  if ([
                    'rangers',
                    'wildlife',
                    'welfare',
                  ].contains(collection)) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fields['health'],
                      decoration: const InputDecoration(
                        labelText: 'Health / welfare notes',
                      ),
                    ),
                  ],
                  if (collection == 'tourists')
                    for (final entry in {
                      'email': 'Email',
                      'country': 'Country',
                      'emergencyContactName': 'Emergency contact name',
                      'emergencyContactPhone': 'Emergency contact phone',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: fields[entry.key],
                          decoration: InputDecoration(labelText: entry.value),
                        ),
                      ),
                  if (collection == 'devices') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fields['battery'],
                      decoration: const InputDecoration(labelText: 'Battery %'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy || locating
                        ? null
                        : () async {
                            refresh(() {
                              locating = true;
                              locationNote = null;
                            });
                            try {
                              final position =
                                  await (widget.currentPosition?.call() ??
                                      DeviceLocation.currentPosition());
                              if (!context.mounted) return;
                              refresh(() {
                                capturedPosition = position;
                                locationNote =
                                    'Current location attached (accuracy ${position.accuracy.round()} m).';
                              });
                            } catch (failure) {
                              if (context.mounted) {
                                refresh(
                                  () => locationNote =
                                      '$failure You can describe the area instead.',
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                refresh(() => locating = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      locating
                          ? 'Finding current location…'
                          : 'Use device current location',
                    ),
                  ),
                  if (locationNote != null)
                    Text(locationNote!)
                  else if (current?['latitude'] != null &&
                      current?['longitude'] != null)
                    const Text(
                      'Saved location retained. Use current location to replace it.',
                    )
                  else
                    const Text(
                      'Attach this device’s location or describe the area above.',
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy || locating
                  ? null
                  : () async {
                      refresh(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        if (!incident && fields['name']!.text.trim().isEmpty) {
                          throw ArgumentError('Name is required.');
                        }
                        final record = <String, dynamic>{
                          'type': type,
                          'status': status,
                          if (capturedPosition != null) ...{
                            'latitude': capturedPosition!.latitude,
                            'longitude': capturedPosition!.longitude,
                            'accuracy': capturedPosition!.accuracy,
                            'locationCapturedAt': capturedPosition!.timestamp
                                .toUtc()
                                .toIso8601String(),
                          },
                        };
                        for (final field in fields.entries) {
                          final value = field.value.text.trim();
                          if (['battery'].contains(field.key)) {
                            record[field.key] = value.isEmpty
                                ? null
                                : double.tryParse(value);
                            if (value.isNotEmpty && record[field.key] == null) {
                              throw ArgumentError(
                                'Enter a valid ${field.key}.',
                              );
                            }
                          } else {
                            record[field.key] = value;
                          }
                        }
                        if (incident) {
                          await store.signal(record);
                        } else {
                          await store.save(
                            collection,
                            record,
                            id: current?['id'] as String?,
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                        _message(
                          incident
                              ? 'Report saved for admin review.'
                              : 'Record saved on laptop.',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          refresh(() {
                            error = '$e';
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(
                busy
                    ? 'Saving...'
                    : incident
                    ? 'Submit report'
                    : 'Save record',
              ),
            ),
          ],
        ),
      ),
    );
    for (final controller in fields.values) {
      controller.dispose();
    }
  }

  Future<T?> _showManagedDialog<T>(WidgetBuilder builder) async {
    final route = DialogRoute<T>(context: context, builder: builder);
    final result = await Navigator.of(context).push(route);
    // Text fields retain their controllers until the exit animation finishes.
    await route.completed;
    return result;
  }
}
