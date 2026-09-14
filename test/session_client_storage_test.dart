import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/session.dart';

void main() {
  setUp(() {
    Session.clear();
    Session.clearForClient('forge-console');
  });

  test('client-scoped token storage preserves the default Console session', () {
    expect(Session.store('admin-token', clientId: 'sso-admin-console'), isTrue);
    expect(
      Session.storeForClient(
        'forge-console',
        'forge-token',
        sessionId: 'sid',
        refreshToken: 'forge-refresh',
      ),
      isTrue,
    );

    expect(Session.read(), 'admin-token');
    expect(Session.readClientId(), 'sso-admin-console');
    expect(Session.readForClient('forge-console'), 'forge-token');
    expect(Session.readRefreshTokenForClient('forge-console'), 'forge-refresh');
    expect(Session.readSessionIdForClient('forge-console'), 'sid');
    expect(Session.readClientIdForClient('forge-console'), 'forge-console');

    Session.clearForClient('forge-console');
    expect(Session.readForClient('forge-console'), isNull);
    expect(Session.readRefreshTokenForClient('forge-console'), isNull);
    expect(Session.read(), 'admin-token');
  });

  test(
    'clearing the Console session removes scoped client credentials too',
    () {
      expect(Session.storeForClient('forge-console', 'forge-token'), isTrue);

      Session.clear();

      expect(Session.readForClient('forge-console'), isNull);
      expect(Session.readRefreshTokenForClient('forge-console'), isNull);
      expect(Session.readClientIdForClient('forge-console'), isNull);
    },
  );
}
