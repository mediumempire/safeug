import 'package:flutter/foundation.dart';

const productionApiUrl = String.fromEnvironment(
  'SAFEUG_API_URL',
  defaultValue: 'https://www.safeug.online',
);
const allowServerOverride = bool.fromEnvironment(
  'SAFEUG_ALLOW_SERVER_OVERRIDE',
  defaultValue: kDebugMode,
);

String resolveServerEndpoint({
  required bool web,
  required String webOrigin,
  String? saved,
}) {
  final value = web
      ? webOrigin
      : allowServerOverride && saved != null
      ? saved
      : productionApiUrl;
  final uri = Uri.parse(value);
  if (!['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw StateError('SafeUG requires a valid server origin.');
  }
  if (!web && !allowServerOverride && uri.scheme != 'https') {
    throw StateError('Release apps require a secure HTTPS server.');
  }
  return uri.origin;
}
