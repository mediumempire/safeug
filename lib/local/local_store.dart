import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'incident_contract.dart';
import 'device_location.dart';
import 'server_config.dart';
import 'package:geolocator/geolocator.dart';

typedef Record = Map<String, dynamic>;

class LocalStore extends ChangeNotifier {
  LocalStore({
    this.adminApp = false,
    http.Client? client,
    http.Client Function()? liveClientFactory,
  }) : _client = client ?? http.Client(),
       _liveClientFactory = liveClientFactory ?? http.Client.new;
  final bool adminApp;
  final http.Client _client;
  final http.Client Function() _liveClientFactory;
  bool authenticated = false;
  String? _token;
  Future<void>? _authorization;
  final _secure = const FlutterSecureStorage();
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (!adminApp && _token != null) 'Authorization': 'Bearer $_token',
  };
  Future<void> login(String username, String password) async {
    final response = await _client.post(
      Uri.parse('$endpoint/api/auth/login'),
      headers: headers,
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );
    if (response.statusCode != 200) {
      throw StateError('Sign-in failed. Check your username and password.');
    }
    authenticated = true;
    await sync();
  }

  Future<void> logout() async {
    _stopLive();
    await _client.post(Uri.parse('$endpoint/api/auth/logout'));
    authenticated = false;
    data.clear();
    notifyListeners();
  }

  Future<void> dispatch(String id) async {
    final r = await _client
        .post(Uri.parse('$endpoint/api/dispatch/$id'), headers: headers)
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw StateError('${jsonDecode(r.body)['error']}');
    await sync();
  }

  Future<void> _authorize() => _authorization ??= _authorizeOnce().whenComplete(
    () => _authorization = null,
  );

  Future<void> _authorizeOnce() async {
    if (adminApp) {
      final r = await _client
          .get(Uri.parse('$endpoint/api/auth/session'))
          .timeout(const Duration(seconds: 6));
      authenticated =
          r.statusCode == 200 && jsonDecode(r.body)['role'] == 'admin';
      if (!authenticated) throw StateError('Administrator sign-in required');
    } else if (_token == null) {
      _token = await _secure.read(key: 'device_token_$endpoint');
      if (_token == null) {
        final r = await _client
            .post(Uri.parse('$endpoint/api/auth/device'))
            .timeout(const Duration(seconds: 6));
        if (r.statusCode != 201) {
          throw StateError('Device registration unavailable');
        }
        _token = jsonDecode(r.body)['token'] as String;
        await _secure.write(key: 'device_token_$endpoint', value: _token);
      }
    }
  }

  Future<void> _clearRejectedDeviceToken(int status) async {
    if (status != 401 || adminApp || _token == null) return;
    await _secure.delete(key: 'device_token_$endpoint');
    _token = null;
    if (_syncing && !_retriedDeviceAuth) {
      _retriedDeviceAuth = true;
      _syncAgain = true;
    }
  }

  final Map<String, List<Record>> data = {};
  final List<Record> queue = [];
  final List<Record> pendingIncidentActions = [];
  Record? pendingProfile;
  Record? get touristProfile =>
      pendingProfile ??
      (records('tourists').isEmpty ? null : records('tourists').first);
  String get _profileKey => 'tourist_profile_pending_$endpoint';
  bool connected = false;
  bool ready = false;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _retriedDeviceAuth = false;
  Completer<void>? _syncCompletion;
  int _mutationVersion = 0;
  String? _revision;
  bool liveConnected = false;
  int _liveGeneration = 0;
  http.Client? _liveClient;
  Timer? _liveRetry;
  bool _disposed = false;
  Future<void> _actionMutation = Future<void>.value();
  String endpoint = '';
  String? error;
  Timer? _timer;
  late SharedPreferences _prefs;
  List<Record> records(String name) => data[name] ?? [];
  List<Record> get personalContacts =>
      records('contacts').where((r) => r['status'] != 'Inactive').toList();
  Position? devicePosition;
  String? locationError;
  String? sharingError;
  Future<Position>? _findingLocation;

  Future<Position> locate({Future<Position> Function()? provider}) =>
      _findingLocation ??= _locate(
        provider,
      ).whenComplete(() => _findingLocation = null);

  Future<Position> _locate(Future<Position> Function()? provider) async {
    try {
      final position =
          await (provider?.call() ?? DeviceLocation.currentPosition());
      devicePosition = position;
      locationError = null;
      notifyListeners();
      unawaited(publishLocation());
      return position;
    } catch (e) {
      devicePosition = null;
      locationError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> publishLocation() async {
    final position = devicePosition;
    if (adminApp ||
        position == null ||
        DateTime.now().difference(position.timestamp).inSeconds > 90 ||
        !personalContacts.any((r) => r['shareLocation'] == true)) {
      return;
    }
    try {
      await _authorize();
      final response = await _client
          .put(
            Uri.parse('$endpoint/api/live-location'),
            headers: headers,
            body: jsonEncode({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
              'locationCapturedAt': position.timestamp
                  .toUtc()
                  .toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        throw StateError('Location was not delivered');
      }
      sharingError = null;
    } catch (_) {
      sharingError =
          'Location was not delivered. Check your connection. Links expire after two minutes without a fresh location.';
    }
    notifyListeners();
  }

  bool isQueued(String id) => queue.any((record) => record['id'] == id);

  /// Queue entries remain visible until their server acknowledgement is cached.
  List<Record> get ownIncidents {
    final byId = <String, Record>{
      for (final record in records('incidents')) '${record['id']}': record,
      for (final record in queue) '${record['id']}': record,
    };
    for (final action in pendingIncidentActions) {
      final id = '${action['incidentId']}';
      final incident = byId[id];
      if (incident == null) continue;
      byId[id] = {
        ...incident,
        if (action['action'] == 'stand-down') 'standDownPending': true,
        if (action['action'] == 'location')
          ...Record.from(action['fields'] as Map),
      };
    }
    final result = byId.values.toList();
    result.sort((a, b) => '${b['reportedAt']}'.compareTo('${a['reportedAt']}'));
    return result;
  }

  Record? incidentById(String id) {
    for (final incident in ownIncidents) {
      if (incident['id'] == id) return incident;
    }
    return null;
  }

  Record? get latestSos {
    for (final incident in ownIncidents) {
      if (isSosIncident(incident)) return incident;
    }
    return null;
  }

  Record? get activeSos {
    for (final incident in ownIncidents) {
      if (isSosIncident(incident) && isOpenIncident(incident)) return incident;
    }
    return null;
  }

  String responseMessage(Record incident) =>
      incidentResponseMessage(incident, queued: isQueued('${incident['id']}'));
  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final previousEndpoint =
        _prefs.getString('local_endpoint') ?? 'http://10.0.2.2:8099';
    endpoint = resolveServerEndpoint(
      web: kIsWeb,
      webOrigin: kIsWeb ? Uri.base.origin : '',
      saved: _prefs.getString('local_endpoint'),
    );
    // Preserve identity when the existing private database is moved to the VPS.
    // An unknown/expired token is replaced after a server 401, never on a timeout.
    if (!kIsWeb && !allowServerOverride && previousEndpoint != endpoint) {
      final token = await _secure.read(key: 'device_token_$endpoint');
      final oldToken = await _secure.read(
        key: 'device_token_$previousEndpoint',
      );
      if (token == null && oldToken != null) {
        await _secure.write(key: 'device_token_$endpoint', value: oldToken);
      }
      final profile = _prefs.getString(
        'tourist_profile_pending_$previousEndpoint',
      );
      if (profile != null && _prefs.getString(_profileKey) == null) {
        await _prefs.setString(_profileKey, profile);
      }
      await _prefs.setString('local_endpoint', endpoint);
    }
    try {
      final savedProfile = adminApp ? null : _prefs.getString(_profileKey);
      if (savedProfile != null) {
        pendingProfile = Record.from(jsonDecode(savedProfile) as Map);
      }
      final saved =
          jsonDecode(
                adminApp ? '[]' : _prefs.getString('mobile_queue_v2') ?? '[]',
              )
              as List;
      queue.addAll(saved.map((r) => Record.from(r as Map)));
      final savedActions =
          jsonDecode(
                adminApp
                    ? '[]'
                    : _prefs.getString('mobile_incident_actions_v1') ?? '[]',
              )
              as List;
      pendingIncidentActions.addAll(
        savedActions.map((r) => Record.from(r as Map)),
      );
      final cache =
          jsonDecode(
                adminApp ? '{}' : _prefs.getString('mobile_cache_v2') ?? '{}',
              )
              as Map;
      for (final entry in cache.entries) {
        data[entry.key as String] = (entry.value as List)
            .map((r) => Record.from(r as Map))
            .toList();
      }
    } catch (_) {
      error = 'Saved data could not be read.';
    }
    ready = true;
    notifyListeners();
    unawaited(sync());
    if (!_disposed) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!liveConnected ||
            queue.isNotEmpty ||
            pendingIncidentActions.isNotEmpty ||
            pendingProfile != null) {
          unawaited(sync());
        }
      });
    }
  }

  Future<void> setEndpoint(String value) async {
    if (kIsWeb || !allowServerOverride) {
      throw StateError('This app uses the configured SafeUG online service.');
    }
    if (queue.isNotEmpty ||
        pendingIncidentActions.isNotEmpty ||
        pendingProfile != null ||
        _syncing) {
      throw StateError(
        'Wait for synchronization and deliver pending reports before changing servers.',
      );
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw ArgumentError('Enter a complete server URL.');
    }
    endpoint = resolveServerEndpoint(
      web: false,
      webOrigin: '',
      saved: value.trim(),
    );
    _stopLive();
    _revision = null;
    _token = null;
    data.clear();
    await _prefs.setString('local_endpoint', endpoint);
    await sync();
  }

  Future<void> persistQueue() async {
    if (!await _prefs.setString('mobile_queue_v2', jsonEncode(queue))) {
      throw StateError('Could not save the signal on this device.');
    }
  }

  Future<void> _persistActions() async {
    if (!await _prefs.setString(
      'mobile_incident_actions_v1',
      jsonEncode(pendingIncidentActions),
    )) {
      throw StateError('Could not save the SOS update on this device.');
    }
  }

  Future<void> _changeActions(void Function() change) {
    final next = _actionMutation.then((_) async {
      final previous = List<Record>.from(pendingIncidentActions);
      change();
      try {
        await _persistActions();
      } catch (_) {
        pendingIncidentActions
          ..clear()
          ..addAll(previous);
        rethrow;
      }
    });
    // Serialize mutations, including acknowledgements, without letting one
    // failed preference write suppress a later stand-down request.
    _actionMutation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _queueIncidentAction(
    String id,
    String action,
    Record fields,
  ) async {
    final incident = incidentById(id);
    if (incident == null ||
        !(action == 'location'
            ? isEmergencyIncident(incident)
            : isSosIncident(incident))) {
      throw StateError('Emergency alert not found.');
    }
    if (!isOpenIncident(incident)) return;
    await _changeActions(() {
      pendingIncidentActions.removeWhere(
        (item) => item['incidentId'] == id && item['action'] == action,
      );
      pendingIncidentActions.add({
        'id': newId(),
        'incidentId': id,
        'action': action,
        'fields': fields,
      });
    });
    notifyListeners();
    unawaited(sync());
  }

  Future<void> updateIncidentLocation(String id, Record coordinates) async {
    final latitude = coordinates['latitude'];
    final longitude = coordinates['longitude'];
    final accuracy = coordinates['accuracy'];
    if (latitude is! num ||
        !latitude.isFinite ||
        latitude.abs() > 90 ||
        longitude is! num ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        (accuracy != null &&
            (accuracy is! num || !accuracy.isFinite || accuracy < 0))) {
      throw ArgumentError('A valid device location is required.');
    }
    final fields = <String, dynamic>{
      'latitude': coordinates['latitude'],
      'longitude': coordinates['longitude'],
      'accuracy': coordinates['accuracy'],
      'locationCapturedAt':
          coordinates['locationCapturedAt'] ??
          DateTime.now().toUtc().toIso8601String(),
      'locationSource': 'device',
    };
    await _queueIncidentAction(id, 'location', fields);
  }

  Future<void> closeSos(
    String id, {
    String reason = 'I am safe / accidental activation',
  }) => _queueIncidentAction(id, 'stand-down', {'reason': reason});

  Future<void> registerTourist(Record fields) async {
    if (adminApp) throw StateError('Use the mobile app to register.');
    final profile = Record.from(fields);
    if (!await _prefs.setString(_profileKey, jsonEncode(profile))) {
      throw StateError('Could not save your profile on this device.');
    }
    pendingProfile = profile;
    notifyListeners();
    unawaited(sync());
  }

  Future<String> signal(Record fields) async {
    final type = normalizeIncidentType(fields['type'] ?? 'SOS');
    if (type == 'SOS' && activeSos != null) {
      return activeSos!['id'] as String;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final record = <String, dynamic>{
      ...fields,
      'type': type,
      'severity': fields['severity'] ?? defaultIncidentSeverity(type),
      'id': newId(),
      'status': 'Reported',
      'reportedAt': now,
      'occurredAt': fields['occurredAt'] ?? now,
    };
    queue.add(record);
    try {
      await persistQueue();
    } catch (_) {
      queue.remove(record);
      rethrow;
    }
    notifyListeners();
    unawaited(sync());
    return record['id'] as String;
  }

  Future<void> rateGuide(String id, int score) async {
    if (adminApp || score < 1 || score > 5) {
      throw StateError('Choose a rating from 1 to 5 in the mobile app.');
    }
    await _authorize();
    final response = await _client
        .put(
          Uri.parse('$endpoint/api/guides/${Uri.encodeComponent(id)}/rating'),
          headers: headers,
          body: jsonEncode({'score': score}),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      await _clearRejectedDeviceToken(response.statusCode);
      throw StateError('${jsonDecode(response.body)['error']}');
    }
    final result = Record.from(jsonDecode(response.body) as Map);
    _mutationVersion++;
    final list = data.putIfAbsent('guides', () => []);
    final index = list.indexWhere((r) => r['id'] == id);
    if (index < 0) {
      list.add(result);
    } else {
      list[index] = result;
    }
    notifyListeners();
    await _prefs.setString('mobile_cache_v2', jsonEncode(data));
    unawaited(sync());
  }

  Future<Record> save(String collection, Record fields, {String? id}) async {
    if (!adminApp && _token == null) await _authorize();
    final uri = Uri.parse(
      '$endpoint/api/$collection${id == null ? '' : '/$id'}',
    );
    final response =
        await (id == null
                ? _client.post(uri, headers: headers, body: jsonEncode(fields))
                : _client.patch(
                    uri,
                    headers: headers,
                    body: jsonEncode(fields),
                  ))
            .timeout(const Duration(seconds: 6));
    if (response.statusCode >= 300) {
      await _clearRejectedDeviceToken(response.statusCode);
      throw StateError('${jsonDecode(response.body)['error']}');
    }
    final result = Record.from(jsonDecode(response.body) as Map);
    _mutationVersion++;
    final list = data.putIfAbsent(collection, () => []);
    list.removeWhere((r) => r['id'] == result['id']);
    list.add(result);
    if (!adminApp) {
      // Save the server receipt before removing its offline queue entry. A failed
      // subsequent state refresh must not lose the active SOS on app restart.
      if (!await _prefs.setString('mobile_cache_v2', jsonEncode(data))) {
        throw StateError('Could not save the delivery receipt on this device.');
      }
    }
    notifyListeners();
    return result;
  }

  Future<Record> reviewGuide(String id, String status, String note) async {
    final response = await _client
        .post(
          Uri.parse('$endpoint/api/guideApplications/$id/review'),
          headers: headers,
          body: jsonEncode({'status': status, 'note': note}),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('${jsonDecode(response.body)['error']}');
    }
    await sync();
    return Record.from(jsonDecode(response.body) as Map);
  }

  Future<void> sync() async {
    if (!ready || _disposed) return;
    if (_syncing) {
      _syncAgain = true;
      return _syncCompletion?.future;
    }
    _syncing = true;
    final completion = _syncCompletion = Completer<void>();
    try {
      await _authorize();
      if (_disposed) return;
      await _syncIncidentActions();
      final pending = List<Record>.from(queue)
        ..sort((a, b) => _priority(a).compareTo(_priority(b)));
      for (final signal in pending) {
        final location = pendingIncidentActions.where(
          (action) =>
              action['incidentId'] == signal['id'] &&
              action['action'] == 'location',
        );
        await save('incidents', {
          ...signal,
          if (location.isNotEmpty)
            ...Record.from(location.last['fields'] as Map),
        });
        queue.removeWhere((r) => r['id'] == signal['id']);
        await persistQueue();
        await _syncIncidentActions();
      }
      final profile = pendingProfile;
      if (profile != null) {
        final response = await _client
            .put(
              Uri.parse('$endpoint/api/tourist-profile'),
              headers: headers,
              body: jsonEncode(profile),
            )
            .timeout(const Duration(seconds: 6));
        if (response.statusCode >= 300) {
          await _clearRejectedDeviceToken(response.statusCode);
          throw StateError('${jsonDecode(response.body)['error']}');
        }
        if (identical(profile, pendingProfile)) {
          if (!await _prefs.remove(_profileKey)) {
            throw StateError('Could not update saved registration.');
          }
          if (identical(profile, pendingProfile)) {
            pendingProfile = null;
          } else {
            await _prefs.setString(_profileKey, jsonEncode(pendingProfile));
          }
        }
        data['tourists'] = [Record.from(jsonDecode(response.body) as Map)];
      }
      final fetchVersion = _mutationVersion;
      final response = await _client
          .get(Uri.parse('$endpoint/api/state'), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        await _clearRejectedDeviceToken(response.statusCode);
        throw StateError('SafeUG service unavailable. Check your connection.');
      }
      final state = jsonDecode(response.body) as Map;
      // An overlapping save may have returned a newer server receipt while
      // this snapshot was in flight. Never overwrite that receipt with old data.
      if (fetchVersion != _mutationVersion) {
        _syncAgain = true;
        return;
      }
      _revision = state['revision'] as String?;
      for (final entry in state.entries) {
        if (entry.value is List) {
          data[entry.key as String] = (entry.value as List)
              .map((r) => Record.from(r as Map))
              .toList();
        }
      }
      connected = true;
      _retriedDeviceAuth = false;
      error = null;
      if (!adminApp) {
        await _prefs.setString('mobile_cache_v2', jsonEncode(data));
      }
    } catch (failure) {
      connected = false;
      error = '$failure';
    } finally {
      _syncing = false;
      notifyListeners();
      completion.complete();
      if (_syncAgain && !_disposed) {
        _syncAgain = false;
        unawaited(sync());
      } else {
        _startLive();
      }
    }
  }

  void _stopLive() {
    _liveGeneration++;
    _liveRetry?.cancel();
    _liveRetry = null;
    _liveClient?.close();
    _liveClient = null;
    liveConnected = false;
  }

  void _startLive() {
    if (_disposed ||
        !connected ||
        _revision == null ||
        _liveClient != null ||
        _liveRetry != null ||
        (adminApp && !authenticated)) {
      return;
    }
    final client = _liveClient = _liveClientFactory();
    final generation = ++_liveGeneration;
    unawaited(_listenLive(client, generation));
  }

  Future<void> _listenLive(http.Client client, int generation) async {
    try {
      while (!_disposed && generation == _liveGeneration) {
        final revision = _revision;
        final pending = client.get(
          Uri.parse(
            '$endpoint/api/changes',
          ).replace(queryParameters: {'since': revision ?? ''}),
          headers: headers,
        );
        liveConnected = true;
        final response = await pending.timeout(const Duration(seconds: 35));
        if (_disposed || generation != _liveGeneration) return;
        if (response.statusCode == 401) {
          if (adminApp) authenticated = false;
          throw StateError('Session expired');
        }
        if (response.statusCode != 200) {
          throw StateError('Live connection interrupted');
        }
        final next = jsonDecode(response.body)['revision'];
        if (next is! String) throw StateError('Invalid live response');
        if (next != _revision) await sync();
        if (!connected) throw StateError('State refresh failed');
      }
    } catch (_) {
      if (!_disposed && generation == _liveGeneration) {
        liveConnected = false;
        notifyListeners();
      }
    } finally {
      client.close();
      if (generation == _liveGeneration) {
        _liveClient = null;
        if (!_disposed && (!adminApp || authenticated)) {
          _liveRetry = Timer(const Duration(seconds: 2), () {
            _liveRetry = null;
            unawaited(sync());
          });
        }
      }
    }
  }

  Future<void> _syncIncidentActions() async {
    await _actionMutation;
    for (final action in List<Record>.from(pendingIncidentActions)) {
      if (_disposed) return;
      if (isQueued('${action['incidentId']}')) continue;
      final response = await _client
          .post(
            Uri.parse(
              '$endpoint/api/incidents/${action['incidentId']}/${action['action']}',
            ),
            headers: headers,
            body: jsonEncode(action['fields']),
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        throw StateError('${jsonDecode(response.body)['error']}');
      }
      final incident = Record.from(jsonDecode(response.body) as Map);
      _mutationVersion++;
      final records = data.putIfAbsent('incidents', () => []);
      records.removeWhere((record) => record['id'] == incident['id']);
      records.add(incident);
      if (!await _prefs.setString('mobile_cache_v2', jsonEncode(data))) {
        throw StateError('Could not save the SOS response on this device.');
      }
      await _changeActions(
        () => pendingIncidentActions.removeWhere(
          (item) => item['id'] == action['id'],
        ),
      );
      notifyListeners();
    }
  }

  int _priority(Record r) =>
      ['SOS', 'Ranger down'].contains(normalizeIncidentType(r['type']))
      ? 0
      : ['Poaching', 'Backup needed'].contains(r['type'])
      ? 1
      : 2;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLive();
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
