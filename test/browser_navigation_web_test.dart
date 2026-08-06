@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:web/web.dart' as web;

void main() {
  test('external navigation rejects non-HTTPS and credentialed URLs', () {
    final before = web.window.location.href;
    expect(
      BrowserNavigation.assignExternalLocation(
        Uri.parse('http://checkout.stripe.com/c/pay/cs_one'),
      ),
      isFalse,
    );
    expect(
      BrowserNavigation.assignExternalLocation(
        Uri.parse('https://user@checkout.stripe.com/c/pay/cs_one'),
      ),
      isFalse,
    );
    expect(web.window.location.href, before);
  });

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
      expect(BrowserNavigation.currentUri.path, '/admin/clients');
      expect(notifications, 1);

      BrowserNavigation.replaceState('/admin/users/user-1');
      expect(web.window.location.pathname, '/admin/users/user-1');
      expect(BrowserNavigation.currentUri.path, '/admin/users/user-1');
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
