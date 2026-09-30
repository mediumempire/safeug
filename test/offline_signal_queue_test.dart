import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/services/offline_signal_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  QueuedSosSignal signal(String id, String uid) => QueuedSosSignal(
    id: id,
    uid: uid,
    createdAt: DateTime.utc(2026),
    contactIds: const [],
    latitude: 0.3,
    longitude: 32.5,
  );

  test('queue preserves GPS and deduplicates a signal ID', () async {
    final queue = OfflineSignalQueue.instance;
    await queue.enqueue(signal('one', 'alice'));
    await queue.enqueue(signal('one', 'alice'));
    final pending = await queue.pending();
    expect(pending, hasLength(1));
    expect(pending.single.latitude, 0.3);
  });

  test(
    'retry cannot send another account signals and retains failures',
    () async {
      final queue = OfflineSignalQueue.instance;
      await queue.enqueue(signal('one', 'alice'));
      await queue.enqueue(signal('two', 'bob'));
      expect(
        await queue.retry(
          (s) async => throw Exception('offline'),
          uid: 'alice',
        ),
        0,
      );
      expect(await queue.pending(), hasLength(2));
      expect(
        await queue.retry((s) async {
          expect(s.uid, 'alice');
          return s.id;
        }, uid: 'alice'),
        1,
      );
      expect((await queue.pending()).single.uid, 'bob');
    },
  );

  test('new signal queued during retry is retained', () async {
    final queue = OfflineSignalQueue.instance;
    await queue.enqueue(signal('one', 'alice'));
    await queue.retry((s) async {
      await queue.enqueue(signal('two', 'alice'));
      return s.id;
    }, uid: 'alice');
    expect((await queue.pending()).single.id, 'two');
  });
}
