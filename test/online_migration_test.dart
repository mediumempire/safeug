import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/local/local_store.dart';
import 'package:safeug/local/server_config.dart';

class OfflineMigrationStore extends LocalStore {
  @override
  Future<void> sync() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'online migration keeps device identity, pending profile and queued SOS',
    () async {
      const old = 'http://192.168.1.10:8099';
      final vault = <String, String>{
        'device_token_$old': 'existing-device-token',
      };
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            if (call.method == 'read') return vault[args['key']];
            if (call.method == 'write') vault[args['key']] = args['value'];
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      SharedPreferences.setMockInitialValues({
        'local_endpoint': old,
        'tourist_profile_pending_$old': jsonEncode({
          'name': 'Pending visitor',
          'consent': true,
        }),
        'mobile_queue_v2': jsonEncode([
          {'id': 'pending-sos', 'type': 'SOS', 'status': 'Reported'},
        ]),
      });
      final store = OfflineMigrationStore();
      await store.initialize();
      expect(store.endpoint, allowServerOverride ? old : productionApiUrl);
      expect(store.pendingProfile?['name'], 'Pending visitor');
      expect(store.queue.single['id'], 'pending-sos');
      expect(vault['device_token_${store.endpoint}'], 'existing-device-token');
      store.dispose();
    },
  );
}
