import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/services/browser_navigation.dart';

void main() {
  group('fromUri - Level 1: Module', () {
    test('/admin/ -> root', () {
      final r = AdminRoute.fromUri(Uri.parse('http://localhost/admin/'));
      expect(r.module, '');
      expect(r.isList, true);
    });
    test('/admin/clients -> clients module', () {
      final r = AdminRoute.fromUri(Uri.parse('http://localhost/admin/clients'));
      expect(r.module, 'clients');
      expect(r.isList, true);
    });
    test('/admin/governance -> governance module', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/governance'),
      );
      expect(r.module, 'governance');
      expect(r.isList, true);
    });
    test('/admin/emergency-access -> emergency-access module', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/emergency-access'),
      );
      expect(r.module, 'emergency-access');
      expect(r.isList, true);
    });
    test('/admin/token-security -> token-security module', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/token-security'),
      );
      expect(r.module, 'token-security');
      expect(r.isList, true);
    });
  });

  group('fromUri - Level 2: Resource + Action', () {
    test('/admin/clients/new -> create', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/clients/new'),
      );
      expect(r.module, 'clients');
      expect(r.isNew, true);
    });
    test('/admin/domains/new -> create domain', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/domains/new'),
      );
      expect(r.module, 'domains');
      expect(r.isNew, true);
    });
    test('/admin/threat-policies/new -> create policy', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/threat-policies/new'),
      );
      expect(r.module, 'threat-policies');
      expect(r.isNew, true);
    });
    test('/admin/clients/client-abc -> detail view', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/clients/client-abc'),
      );
      expect(r.module, 'clients');
      expect(r.resourceId, 'client-abc');
      expect(r.isDetail, true);
    });
    test('/admin/users/admin -> user detail', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/users/admin'),
      );
      expect(r.module, 'users');
      expect(r.resourceId, 'admin');
      expect(r.isDetail, true);
    });
    test('/admin/clients/client-abc/edit -> edit', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/clients/client-abc/edit'),
      );
      expect(r.module, 'clients');
      expect(r.resourceId, 'client-abc');
      expect(r.isEdit, true);
    });
    test('/admin/threat-policies/pol-1/edit -> edit policy', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/threat-policies/pol-1/edit'),
      );
      expect(r.module, 'threat-policies');
      expect(r.resourceId, 'pol-1');
      expect(r.isEdit, true);
    });
  });

  group('fromUri - Level 3: Sub-resource', () {
    test('/admin/users/user-xyz/sessions', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/users/user-xyz/sessions'),
      );
      expect(r.module, 'users');
      expect(r.resourceId, 'user-xyz');
      expect(r.subresource, 'sessions');
      expect(r.hasSubresource, true);
    });
    test('/admin/users/user-xyz/consents', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/users/user-xyz/consents'),
      );
      expect(r.subresource, 'consents');
    });
    test('/admin/users/user-xyz/mfa', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/users/user-xyz/mfa'),
      );
      expect(r.subresource, 'mfa');
    });
    test('/admin/users/user-xyz/lifecycle', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/users/user-xyz/lifecycle'),
      );
      expect(r.subresource, 'lifecycle');
    });
    test('/admin/tenants/t-1/members', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/tenants/t-1/members'),
      );
      expect(r.module, 'tenants');
      expect(r.resourceId, 't-1');
      expect(r.subresource, 'members');
    });
    test('/admin/tenants/t-1/invitations', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/tenants/t-1/invitations'),
      );
      expect(r.subresource, 'invitations');
    });
    test('/admin/tenants/t-1/usage', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/tenants/t-1/usage'),
      );
      expect(r.subresource, 'usage');
    });
    test('/admin/clients/c-1/rotate-secret', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/clients/c-1/rotate-secret'),
      );
      expect(r.module, 'clients');
      expect(r.resourceId, 'c-1');
      expect(r.subresource, 'rotate-secret');
    });
    test('/admin/permissions/client-abc/roles', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/permissions/client-abc/roles'),
      );
      expect(r.module, 'permissions');
      expect(r.resourceId, 'client-abc');
      expect(r.subresource, 'roles');
    });
    test('/admin/permissions/client-abc/assignments', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/permissions/client-abc/assignments'),
      );
      expect(r.subresource, 'assignments');
    });
    test('/admin/credentials/report', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/credentials/report'),
      );
      expect(r.module, 'credentials');
      expect(r.subresource, 'report');
    });
    test('/admin/crypto-keys/rotate', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/crypto-keys/rotate'),
      );
      expect(r.module, 'crypto-keys');
      expect(r.subresource, 'rotate');
    });
    test('/admin/governance/audit', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/governance/audit'),
      );
      expect(r.module, 'governance');
      expect(r.subresource, 'audit');
    });
    test('/admin/governance/compliance', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/governance/compliance'),
      );
      expect(r.subresource, 'compliance');
    });
    test('/admin/token-security/portfolio', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/token-security/portfolio'),
      );
      expect(r.module, 'token-security');
      expect(r.subresource, 'portfolio');
    });
    test('/admin/token-security/temp', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/token-security/temp'),
      );
      expect(r.subresource, 'temp');
    });
    test('/admin/token-security/revoke', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/token-security/revoke'),
      );
      expect(r.subresource, 'revoke');
    });
  });

  group('fromUri - Edge cases', () {
    test('trailing slash', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/clients/'),
      );
      expect(r.module, 'clients');
      expect(r.isList, true);
    });
    test('unknown module', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/unknown-module'),
      );
      expect(r.module, 'unknown-module');
      expect(r.isList, true);
    });
    test('non-admin path returns empty', () {
      final r = AdminRoute.fromUri(Uri.parse('http://localhost/other/path'));
      expect(r.module, '');
      expect(r.isList, true);
    });
    test('deep path (5 segments)', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/a/b/c/d/e'),
      );
      expect(r.module, 'a');
      expect(r.resourceId, 'b');
      expect(r.subresource, 'c');
      expect(r.subaction, 'd');
    });
    test('missing module', () {
      final r = AdminRoute.fromUri(Uri.parse('/admin/'));
      expect(r.module, '');
      expect(r.isList, true);
    });
    test('id with special chars', () {
      final r = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/clients/client-123_456'),
      );
      expect(r.resourceId, 'client-123_456');
    });
    test('uuid style id', () {
      final r = AdminRoute.fromUri(
        Uri.parse(
          'http://localhost/admin/users/550e8400-e29b-41d4-a716-446655440000/sessions',
        ),
      );
      expect(r.module, 'users');
      expect(r.resourceId, '550e8400-e29b-41d4-a716-446655440000');
      expect(r.subresource, 'sessions');
    });
    test('encoded slash remains inside one resource id', () {
      final r = AdminRoute.fromUri(
        Uri.parse('/admin/clients/team%2Fwest%20console'),
      );
      expect(r.module, 'clients');
      expect(r.resourceId, 'team/west console');
      expect(r.isDetail, isTrue);
    });
  });

  group('url generation', () {
    test(
      'module list',
      () => expect(AdminRoute.url('clients'), '/admin/clients'),
    );
    test(
      'create',
      () => expect(
        AdminRoute.url('clients', action: 'new'),
        '/admin/clients/new',
      ),
    );
    test(
      'detail',
      () => expect(
        AdminRoute.url('clients', resourceId: 'abc'),
        '/admin/clients/abc',
      ),
    );
    test(
      'edit',
      () => expect(
        AdminRoute.url('clients', resourceId: 'abc', action: 'edit'),
        '/admin/clients/abc/edit',
      ),
    );
    test(
      'subresource',
      () => expect(
        AdminRoute.url('users', resourceId: 'xyz', subresource: 'sessions'),
        '/admin/users/xyz/sessions',
      ),
    );
    test(
      'subresource+action',
      () => expect(
        AdminRoute.url(
          'clients',
          resourceId: 'c1',
          subresource: 'rotate-secret',
        ),
        '/admin/clients/c1/rotate-secret',
      ),
    );
    test(
      'governance subresource',
      () => expect(
        AdminRoute.url('governance', subresource: 'audit'),
        '/admin/governance/audit',
      ),
    );
    test(
      'token-security subresource',
      () => expect(
        AdminRoute.url('token-security', subresource: 'portfolio'),
        '/admin/token-security/portfolio',
      ),
    );
    test(
      'credentials subresource',
      () => expect(
        AdminRoute.url('credentials', subresource: 'report'),
        '/admin/credentials/report',
      ),
    );
    test(
      'emergency-access detail',
      () => expect(
        AdminRoute.url('emergency-access', resourceId: 'session-1'),
        '/admin/emergency-access/session-1',
      ),
    );
    test('encodes user-controlled route segments', () {
      expect(
        AdminRoute.url('clients', resourceId: 'team/west console?#'),
        '/admin/clients/team%2Fwest%20console%3F%23',
      );
    });
  });

  group('property checks', () {
    test(
      'isNew',
      () => expect(AdminRoute(module: 'clients', action: 'new').isNew, true),
    );
    test(
      'isDetail',
      () => expect(
        AdminRoute(module: 'clients', resourceId: 'abc').isDetail,
        true,
      ),
    );
    test(
      'isEdit',
      () => expect(
        AdminRoute(module: 'clients', resourceId: 'abc', action: 'edit').isEdit,
        true,
      ),
    );
    test(
      'hasSubresource',
      () => expect(
        AdminRoute(
          module: 'users',
          resourceId: 'x',
          subresource: 'sessions',
        ).hasSubresource,
        true,
      ),
    );
    test(
      'list is not new',
      () => expect(AdminRoute(module: 'clients').isNew, false),
    );
    test(
      'list is not detail',
      () => expect(AdminRoute(module: 'clients').isDetail, false),
    );
    test(
      'new is not list',
      () => expect(AdminRoute(module: 'clients', action: 'new').isList, false),
    );
    test(
      'detail is not edit',
      () => expect(
        AdminRoute(module: 'clients', resourceId: 'abc').isEdit,
        false,
      ),
    );
    test(
      'edit is not detail',
      () => expect(
        AdminRoute(
          module: 'clients',
          resourceId: 'abc',
          action: 'edit',
        ).isDetail,
        false,
      ),
    );
  });

  group('equality and hash', () {
    test('equal routes', () {
      final a = AdminRoute(
        module: 'clients',
        resourceId: 'abc',
        action: 'edit',
      );
      final b = AdminRoute(
        module: 'clients',
        resourceId: 'abc',
        action: 'edit',
      );
      expect(a == b, true);
      expect(a.hashCode, b.hashCode);
    });
    test('different modules', () {
      final a = AdminRoute(module: 'clients');
      final b = AdminRoute(module: 'users');
      expect(a == b, false);
    });
    test('different resource ids', () {
      final a = AdminRoute(module: 'users', resourceId: 'abc');
      final b = AdminRoute(module: 'users', resourceId: 'xyz');
      expect(a == b, false);
      expect(a.detailIdentity, isNot(b.detailIdentity));
    });
  });

  group('production AdminRoute on VM', () {
    test('parses without importing browser-only libraries', () {
      final route = AdminRoute.fromUri(
        Uri.parse('http://localhost/admin/users/user-1/sessions'),
      );

      expect(route.module, 'users');
      expect(route.resourceId, 'user-1');
      expect(route.subresource, 'sessions');
    });

    test('navigation updates the native route and notifies listeners', () {
      var notifications = 0;
      final cancel = BrowserNavigation.listenToLocationChange(
        () => notifications++,
      );
      addTearDown(() {
        cancel();
        BrowserNavigation.replaceState('/');
      });

      AdminRoute.go('clients', resourceId: 'client-1');

      expect(BrowserNavigation.currentUri.path, '/admin/clients/client-1');
      expect(AdminRoute.current().resourceId, 'client-1');
      expect(notifications, 1);
    });
  });
}
