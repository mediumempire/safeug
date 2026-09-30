import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/local/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'live invalidation refreshes the canonical record without a timer tick',
    () async {
      final listening = Completer<void>(),
          event = Completer<http.Response>(),
          nextListen = Completer<http.Response>(),
          updated = Completer<void>();
      var revision = 'epoch:1';
      var status = 'Reported';
      var calls = 0;
      final api = MockClient(
        (request) async => request.url.path == '/api/auth/session'
            ? http.Response('{"role":"admin"}', 200)
            : http.Response(
                jsonEncode({
                  'revision': revision,
                  'incidents': [
                    {'id': 'live', 'type': 'SOS', 'status': status},
                  ],
                }),
                200,
              ),
      );
      final store = LocalStore(
        adminApp: true,
        client: api,
        liveClientFactory: () => MockClient((request) async {
          if (calls++ == 0) {
            expect(request.url.queryParameters['since'], 'epoch:1');
            listening.complete();
            return event.future;
          }
          return nextListen.future;
        }),
      );
      store.addListener(() {
        if (store.records('incidents').firstOrNull?['status'] == 'Resolved' &&
            !updated.isCompleted) {
          updated.complete();
        }
      });
      await store.initialize();
      await listening.future.timeout(const Duration(seconds: 1));
      revision = 'epoch:2';
      status = 'Resolved';
      event.complete(http.Response('{"revision":"epoch:2"}', 200));
      await updated.future.timeout(const Duration(seconds: 1));
      expect(store.activeSos, isNull);
      store.dispose();
      nextListen.complete(http.Response('{}', 401));
    },
  );
  test(
    'SOS queued during a refresh is posted as soon as that refresh completes',
    () async {
      final entered = Completer<void>(),
          snapshot = Completer<http.Response>(),
          sent = Completer<void>();
      Record? received;
      var snapshots = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/session') {
          return http.Response('{"role":"admin"}', 200);
        }
        if (request.method == 'POST' && request.url.path == '/api/incidents') {
          received = Map<String, dynamic>.from(jsonDecode(request.body));
          if (!sent.isCompleted) sent.complete();
          return http.Response(jsonEncode(received), 201);
        }
        if (request.url.path == '/api/state') {
          if (snapshots++ == 0) {
            entered.complete();
            return snapshot.future;
          }
          return http.Response(
            jsonEncode({
              'incidents': [?received],
            }),
            200,
          );
        }
        throw StateError('Unexpected request ${request.url}');
      });
      final store = LocalStore(adminApp: true, client: client);
      await store.initialize();
      await entered.future;
      final id = await store.signal({'type': 'SOS'});
      expect(received, isNull);
      snapshot.complete(http.Response('{"incidents":[]}', 200));
      await sent.future.timeout(const Duration(seconds: 1));
      await store.sync();
      expect(received?['id'], id);
      expect(store.queue, isEmpty);
      store.dispose();
    },
  );

  test(
    'a slow state response cannot replace a newer incident receipt',
    () async {
      final entered = Completer<void>(), snapshot = Completer<http.Response>();
      var reads = 0;
      final original = {
        'id': 'sos',
        'type': 'SOS',
        'status': 'Reported',
        'reportedAt': '2026-09-30T10:00:00Z',
      };
      final resolved = {...original, 'status': 'Resolved'};
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/session') {
          return http.Response('{"role":"admin"}', 200);
        }
        if (request.method == 'PATCH') {
          return http.Response(jsonEncode(resolved), 200);
        }
        if (request.url.path == '/api/state') {
          if (reads++ == 0) {
            entered.complete();
            return snapshot.future;
          }
          return http.Response(
            jsonEncode({
              'incidents': [resolved],
            }),
            200,
          );
        }
        throw StateError('Unexpected request');
      });
      final store = LocalStore(adminApp: true, client: client);
      await store.initialize();
      await entered.future;
      final observed = <String>[];
      store.addListener(() {
        if (store.records('incidents').isNotEmpty) {
          observed.add('${store.records('incidents').first['status']}');
        }
      });
      await store.save('incidents', {'status': 'Resolved'}, id: 'sos');
      snapshot.complete(
        http.Response(
          jsonEncode({
            'incidents': [original],
          }),
          200,
        ),
      );
      await store.sync();
      await Future<void>.delayed(Duration.zero);
      expect(observed, isNot(contains('Reported')));
      expect(store.activeSos, isNull);
      store.dispose();
    },
  );
}
