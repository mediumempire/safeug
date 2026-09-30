import 'package:flutter_test/flutter_test.dart';
import 'package:safeug/local/server_config.dart';

void main() {
  test('native defaults to the online service and web stays same-origin', () {
    expect(
      resolveServerEndpoint(web: false, webOrigin: ''),
      'https://www.safeug.online',
    );
    expect(
      resolveServerEndpoint(
        web: true,
        webOrigin: 'https://www.safeug.online',
        saved: 'http://10.0.2.2:8099',
      ),
      'https://www.safeug.online',
    );
    expect(
      resolveServerEndpoint(
        web: false,
        webOrigin: '',
        saved: 'http://10.0.2.2:8099',
      ),
      allowServerOverride
          ? 'http://10.0.2.2:8099'
          : 'https://www.safeug.online',
    );
  });
  test('server origins cannot contain credentials, paths or query strings', () {
    for (final invalid in [
      'https://user:password@example.com',
      'https://example.com/api',
      'https://example.com?token=secret',
      'file:///etc/passwd',
    ]) {
      expect(
        () => resolveServerEndpoint(web: true, webOrigin: invalid),
        throwsStateError,
      );
    }
  });
}
