import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/local/local_store.dart';

class OfflineStore extends LocalStore {
  @override
  Future<void> sync() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline tourist profile survives restart and blocks server change',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = OfflineStore();
      await first.initialize();
      await first.registerTourist({
        'name': 'Offline Tourist',
        'phone': '+256700123456',
        'consent': true,
      });
      expect(first.pendingProfile?['name'], 'Offline Tourist');
      await expectLater(
        first.setEndpoint('http://localhost:9999'),
        throwsStateError,
      );
      first.dispose();
      final restored = OfflineStore();
      await restored.initialize();
      expect(restored.touristProfile?['name'], 'Offline Tourist');
      expect(restored.pendingProfile, isNotNull);
      restored.dispose();
    },
  );
}
