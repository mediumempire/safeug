import 'package:flutter/services.dart';

class SystemNotifications {
  static const _channel = MethodChannel('safeug/notifications');
  Future<String> permission({bool request = false}) async {
    try {
      return await _channel.invokeMethod<String>(
            request ? 'requestPermission' : 'permission',
          ) ??
          'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return 'unavailable';
    }
  }

  Future<void> show({
    required String id,
    required String title,
    required String body,
    required bool admin,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'body': body,
      });
    } on MissingPluginException {
      /* Unsupported desktop test target. */
    } on PlatformException {
      /* Permission can be revoked outside the app. */
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      /* Unsupported target. */
    } on PlatformException {
      /* Platform unavailable. */
    }
  }
}
