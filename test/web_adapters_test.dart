@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/browser_auth_response.dart';
import 'package:sso_admin/services/browser_download.dart';
import 'package:sso_admin/services/connectivity_platform.dart'
    as connectivity_platform;
import 'package:sso_admin/services/cross_tab_sync.dart';
import 'package:sso_admin/services/local_storage.dart';
import 'package:sso_admin/services/session_storage.dart';
import 'package:sso_admin/services/shortcut_platform.dart' as shortcut_platform;

/// Chrome-platform tests for the browser adapter layer: storage, cross-tab
/// sync, downloads, connectivity and keyboard shortcuts must work against
/// the real `web` package DOM bindings.
void main() {
  group('LocalStorage', () {
    test('round-trips values and lists keys', () {
      LocalStorage.removeItem('test-key');
      expect(LocalStorage.getItem('test-key'), isNull);

      LocalStorage.setItem('test-key', 'value-1');
      expect(LocalStorage.getItem('test-key'), 'value-1');
      expect(LocalStorage.keys(), contains('test-key'));

      LocalStorage.removeItem('test-key');
      expect(LocalStorage.getItem('test-key'), isNull);
      expect(LocalStorage.keys(), isNot(contains('test-key')));
    });
  });

  group('SessionStorage', () {
    test('round-trips values', () {
      SessionStorage.removeItem('session-key');
      expect(SessionStorage.getItem('session-key'), isNull);

      SessionStorage.setItem('session-key', 'tab-value');
      expect(SessionStorage.getItem('session-key'), 'tab-value');

      SessionStorage.removeItem('session-key');
      expect(SessionStorage.getItem('session-key'), isNull);
    });
  });

  group('CrossTabSync', () {
    test('init registers a storage listener and broadcasts', () async {
      final sync = CrossTabSync();
      final events = <SyncEvent>[];
      final sub = sync.onSync.listen(events.add);
      sync.init();
      // Init is idempotent.
      sync.init();
      addTearDown(sub.cancel);

      // Broadcasting writes to localStorage; the storage event fires in
      // OTHER tabs, so the local stream stays quiet but the write lands.
      CrossTabSync.broadcast('sync-key', 'sync-value');
      expect(LocalStorage.getItem('sync-key'), 'sync-value');
      expect(events, isEmpty);

      CrossTabSync.remove('sync-key');
      expect(LocalStorage.getItem('sync-key'), isNull);
    });
  });

  group('BrowserDownload', () {
    test('downloadBytes and text do not throw', () {
      BrowserDownload.bytes(
        [1, 2, 3],
        filename: 'test.bin',
        contentType: 'application/octet-stream',
      );
      BrowserDownload.text(
        'hello',
        filename: 'test.txt',
        contentType: 'text/plain',
      );
    });
  });

  group('ConnectivityPlatform', () {
    test('reports a boolean online state', () {
      expect(connectivity_platform.isOnline, isA<bool>());
      final cancel = connectivity_platform.listen((_) {});
      cancel();
    });
  });

  group('ShortcutPlatform', () {
    test('registers and removes key listeners', () {
      var calls = 0;
      final cancel = shortcut_platform.listen(
        (key, control, preventDefault) => calls++,
      );
      cancel();
      expect(calls, 0);
    });
  });

  group('BrowserAuthResponse', () {
    test('submitForm builds a form and returns true', () {
      final started = BrowserAuthResponse.submitForm(
        'https://invalid.example.invalid/callback',
        {'code': 'abc', 'state': 'xyz'},
      );
      expect(started, isTrue);
    });

    test('replaceDocument returns true', () {
      expect(BrowserAuthResponse.replaceDocument('<html></html>'), isTrue);
    });
  });
}
