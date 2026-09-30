import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/local/incident_contract.dart';
import 'package:safeug/local/local_store.dart';

class OfflineIncidentStore extends LocalStore {
  OfflineIncidentStore({super.client});
  @override
  Future<void> sync() async {}

  Future<void> deliver() => super.sync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'active SOS and pending GPS/stand-down survive restart without duplicates',
    () async {
      final store = OfflineIncidentStore();
      await store.initialize();
      final id = await store.signal({'type': 'SOS Activation'});
      expect(store.activeSos?['id'], id);
      expect(store.activeSos?['severity'], 'Critical');
      expect(await store.signal({'type': 'SOS'}), id);
      expect(store.queue, hasLength(1));
      expect(
        store.responseMessage(store.activeSos!),
        contains('Waiting to reach'),
      );
      await store.updateIncidentLocation(id, {
        'latitude': 0.3,
        'longitude': 32.5,
        'accuracy': 4,
      });
      await store.updateIncidentLocation(id, {
        'latitude': 0.4,
        'longitude': 32.6,
        'accuracy': 3,
      });
      expect(store.pendingIncidentActions, hasLength(1));
      expect(store.activeSos?['latitude'], 0.4);
      await store.closeSos(id);
      expect(store.activeSos?['standDownPending'], true);
      expect(
        store.responseMessage(store.activeSos!),
        contains('Stand-down request saved'),
      );
      store.dispose();

      final restored = OfflineIncidentStore();
      await restored.initialize();
      expect(restored.activeSos?['id'], id);
      expect(restored.activeSos?['latitude'], 0.4);
      expect(restored.pendingIncidentActions, hasLength(2));
      expect(restored.activeSos?['standDownPending'], true);
      await expectLater(
        restored.setEndpoint('http://localhost:9999'),
        throwsStateError,
      );
      restored.dispose();
    },
  );

  test(
    'server response controls active state and does not invent external contact',
    () {
      final store = LocalStore();
      final record = <String, dynamic>{
        'id': 'one',
        'type': 'SOS',
        'status': 'Reported',
        'reportedAt': '2026-09-30T08:00:00Z',
      };
      store.data['incidents'] = [record];
      expect(store.activeSos?['id'], 'one');
      expect(
        store.responseMessage(record),
        contains('Awaiting acknowledgement'),
      );
      record['status'] = 'Acknowledged';
      expect(store.responseMessage(record), contains('acknowledged'));
      expect(store.responseMessage(record), isNot(contains('contacted')));
      record['externalDelivery'] = 'Submitted';
      expect(
        store.responseMessage(record),
        contains('acceptance is not yet confirmed'),
      );
      record['status'] = 'False Alarm';
      expect(store.activeSos, isNull);
      expect(store.latestSos?['id'], 'one');
      store.dispose();
    },
  );

  test('legacy categories normalize to the benchmark contract', () {
    expect(normalizeIncidentType('Suspicious activity'), 'Suspicious Activity');
    expect(normalizeIncidentType('Safety concern'), 'Safety Hazard');
    expect(normalizeIncidentType('Poaching activity'), 'Poaching');
    expect(
      incidentTypes,
      containsAll([
        'Animal Sighting',
        'Human-Wildlife Conflict',
        'Illegal Encroachment',
        'Other',
      ]),
    );
  });

  test(
    'concurrent GPS and stand-down writes survive disposal and restart',
    () async {
      final store = OfflineIncidentStore();
      await store.initialize();
      final id = await store.signal({'type': 'SOS'});
      final updates = <Future<void>>[
        for (var i = 0; i < 12; i++)
          store.updateIncidentLocation(id, {
            'latitude': 0.3 + i / 100,
            'longitude': 32.5,
            'accuracy': 4,
          }),
        store.closeSos(id),
      ];
      store.dispose();
      await Future.wait(updates);
      final restored = OfflineIncidentStore();
      await restored.initialize();
      expect(restored.pendingIncidentActions, hasLength(2));
      expect(restored.activeSos?['latitude'], closeTo(0.41, 0.001));
      expect(restored.activeSos?['standDownPending'], true);
      restored.dispose();
    },
  );

  test(
    'successful receipt survives failed state refresh and restart',
    () async {
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(storageChannel, null),
      );
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/device') {
          return http.Response('{"token":"test-device-token"}', 201);
        }
        if (request.url.path == '/api/incidents') {
          final incident = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              ...incident,
              'status': 'Acknowledged',
              'receivedAt': '2026-09-30T08:01:00Z',
            }),
            201,
          );
        }
        return http.Response('{"error":"Disconnected after receipt"}', 503);
      });
      final store = OfflineIncidentStore(client: client);
      await store.initialize();
      final id = await store.signal({'type': 'SOS'});
      await store.deliver();
      expect(store.queue, isEmpty);
      expect(store.activeSos?['status'], 'Acknowledged');
      expect(store.connected, false);
      store.dispose();
      final restored = OfflineIncidentStore();
      await restored.initialize();
      expect(restored.activeSos?['id'], id);
      expect(restored.activeSos?['status'], 'Acknowledged');
      expect(restored.isQueued(id), false);
      restored.dispose();
    },
  );
}
