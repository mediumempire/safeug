import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/local/alert_controller.dart';
import 'package:safeug/local/local_store.dart';
import 'package:safeug/local/system_notifications.dart';

class NotificationRecorder extends SystemNotifications {
  final events = <Map<String, String>>[];
  @override
  Future<String> permission({bool request = false}) async => 'granted';
  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required bool admin,
  }) async {
    events.add({'id': id, 'title': title, 'body': body});
  }
}

Future<void> flushAlerts() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'mobile uses OS notifications only for delivery, real agency responses and closure',
    () async {
      final store = LocalStore()
        ..ready = true
        ..endpoint = 'http://test';
      final platform = NotificationRecorder();
      final alerts = AlertController(store, platform: platform);
      await alerts.initialize();
      final incident = <String, dynamic>{
        'id': 'sos',
        'type': 'SOS',
        'status': 'Reported',
        'reportedAt': '2026-09-30T10:00:00Z',
      };
      store.queue.add(incident);
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events.single['body'], contains('Connecting'));
      store.queue.clear();
      store.data['incidents'] = [incident];
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events.last['body'], contains('delivered'));
      final count = platform.events.length;
      incident['latitude'] = 0.3;
      incident['updatedAt'] = '2026-09-30T10:00:10Z';
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events, hasLength(count));
      for (final agency in ['UPF', 'Tourist Police', 'UPDF']) {
        (incident.putIfAbsent('agencyResponses', () => <String, dynamic>{})
            as Map)[agency] = {
          'note': 'Confirmed by administrator',
          'at': agency,
        };
        store.notifyListeners();
        await flushAlerts();
      }
      expect(platform.events.skip(count).map((e) => e['title']), [
        'UPF response',
        'Tourist Police response',
        'UPDF response',
      ]);
      incident['status'] = 'False Alarm';
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events.last['title'], 'SOS ended');
      expect(platform.events.last['body'], 'Your SOS has ended.');
      final after = platform.events.length;
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events, hasLength(after));
      alerts.dispose();
      final reopened = AlertController(store, platform: platform);
      await reopened.initialize();
      await flushAlerts();
      expect(
        platform.events,
        hasLength(after),
        reason: 'restarting must not replay a closed SOS',
      );
      reopened.dispose();
      store.dispose();
    },
  );

  test(
    'admin gets one new-SOS system alert, not another for GPS/status refreshes',
    () async {
      final store = LocalStore(adminApp: true)
        ..ready = true
        ..authenticated = true
        ..endpoint = 'http://test';
      final platform = NotificationRecorder();
      final alerts = AlertController(store, platform: platform);
      await alerts.initialize();
      store.data['incidents'] = [
        {'id': 'new', 'type': 'SOS', 'status': 'Reported'},
      ];
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events.single['title'], 'New SOS emergency');
      store.data['incidents']!.single['latitude'] = 1;
      store.notifyListeners();
      await flushAlerts();
      store.data['incidents']!.single['status'] = 'Acknowledged';
      store.notifyListeners();
      await flushAlerts();
      expect(platform.events, hasLength(1));
      alerts.dispose();
      store.dispose();
    },
  );
}
