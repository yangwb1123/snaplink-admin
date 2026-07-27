@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:web/web.dart' as web;

void main() {
  test('pushState and replaceState notify same-document listeners', () {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    var notifications = 0;
    final cancel = BrowserNavigation.listenToLocationChange(
      () => notifications++,
    );

    try {
      BrowserNavigation.pushState('/admin/clients');
      expect(web.window.location.pathname, '/admin/clients');
      expect(notifications, 1);

      BrowserNavigation.replaceState('/admin/users/user-1');
      expect(web.window.location.pathname, '/admin/users/user-1');
      expect(notifications, 2);

      web.window.dispatchEvent(web.Event('popstate'));
      expect(notifications, 3);

      cancel();
      BrowserNavigation.pushState('/admin/tenants');
      expect(notifications, 3);
    } finally {
      // Restore the Flutter test runner URL without sending another app event.
      web.window.history.replaceState(null, '', originalLocation);
    }
  });
}
