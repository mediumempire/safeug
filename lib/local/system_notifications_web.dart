import 'dart:js_interop';
import 'package:web/web.dart' as web;

class SystemNotifications {
  Future<String> permission({bool request = false}) async {
    try {
      if (!web.window.isSecureContext) return 'unavailable';
      if (request) {
        return (await web.Notification.requestPermission().toDart).toDart;
      }
      return web.Notification.permission;
    } catch (_) {
      return 'unavailable';
    }
  }

  Future<void> show({
    required String id,
    required String title,
    required String body,
    required bool admin,
  }) async {
    if (await permission() != 'granted') return;
    try {
      // A dedicated worker keeps notification clicks working after a tab closes.
      // Remote delivery into a closed browser requires a separate Push service.
      final registration = await web.window.navigator.serviceWorker
          .register(
            '/safeug-notifications.js'.toJS,
            web.RegistrationOptions(scope: '/safeug-alerts/'),
          )
          .toDart;
      for (var i = 0; registration.active == null && i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await registration
          .showNotification(
            title,
            web.NotificationOptions(
              body: body,
              tag: 'safeug-$id',
              icon: '/icons/Icon-192.png',
              requireInteraction: admin,
              data: {'url': admin ? '/admin/' : '/'}.jsify(),
            ),
          )
          .toDart;
    } catch (_) {
      // Desktop fallback for a browser without service-worker notifications.
      try {
        web.Notification(
          title,
          web.NotificationOptions(body: body, tag: 'safeug-$id'),
        );
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    try {
      final registration = await web.window.navigator.serviceWorker
          .getRegistration('/safeug-alerts/')
          .toDart;
      if (registration == null) return;
      final notifications = await registration.getNotifications().toDart;
      for (final notification in notifications.toDart) {
        notification.close();
      }
    } catch (_) {}
  }
}
