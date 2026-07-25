import 'package:flutter_test/flutter_test.dart';

class _TestAdminRoute {
  final String module;
  final String resourceId;
  final String action;
  final String subresource;
  final String subaction;

  const _TestAdminRoute({this.module='', this.resourceId='', this.action='',
    this.subresource='', this.subaction=''});

  bool get isList => resourceId.isEmpty && action.isEmpty && subresource.isEmpty;
  bool get isNew => action == 'new' && resourceId.isEmpty;
  bool get isDetail => resourceId.isNotEmpty && (action.isEmpty || action == 'view') && subresource.isEmpty;
  bool get isEdit => action == 'edit' && resourceId.isNotEmpty;
  bool get hasSubresource => subresource.isNotEmpty;

  factory _TestAdminRoute.fromUri(Uri uri) {
    final path = uri.path;
    final prefix = '/admin/';
    if (!path.startsWith(prefix)) return const _TestAdminRoute();
    final segments = path.substring(prefix.length).split('/')
        .where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return const _TestAdminRoute();
    if (segments.length == 1) return _TestAdminRoute(module: segments[0]);
    if (segments.length == 2 && segments[1] == 'new') {
      return _TestAdminRoute(module: segments[0], action: 'new');
    }
    // Check for known subresource names
    if (segments.length == 2) {
      const known = <String, Set<String>>{
        'credentials': {'report'},
        'crypto-keys': {'rotate'},
        'governance': {'audit', 'compliance', 'configuration', 'lifecycle', 'write'},
        'token-security': {'portfolio', 'suspicious', 'sessions', 'subjects', 'expiring', 'temp', 'revoke', 'bulk-revoke'},
      };
      final ks = known[segments[0]];
      if (ks != null && ks.contains(segments[1])) {
        return _TestAdminRoute(module: segments[0], subresource: segments[1]);
      }
      return _TestAdminRoute(module: segments[0], resourceId: segments[1], action: 'view');
    }
    if (segments.length == 3 && segments[2] == 'edit') {
      return _TestAdminRoute(module: segments[0], resourceId: segments[1], action: 'edit');
    }
    if (segments.length == 3) {
      return _TestAdminRoute(module: segments[0], resourceId: segments[1], subresource: segments[2]);
    }
    if (segments.length == 4) {
      return _TestAdminRoute(module: segments[0], resourceId: segments[1],
          subresource: segments[2], subaction: segments[3]);
    }
    return _TestAdminRoute(module: segments[0], resourceId: segments[1],
        subresource: segments[2], subaction: segments[3]);
  }

  static String url(String module, {String resourceId='', String action='',
      String subresource='', String subaction=''}) {
    final parts = <String>[module];
    if (resourceId.isNotEmpty) parts.add(resourceId);
    if (action.isNotEmpty && action != 'view') parts.add(action);
    if (subresource.isNotEmpty) parts.add(subresource);
    if (subaction.isNotEmpty) parts.add(subaction);
    return '/admin/${parts.join('/')}';
  }

  @override
  bool operator ==(Object other) =>
      other is _TestAdminRoute &&
      module == other.module &&
      resourceId == other.resourceId &&
      action == other.action &&
      subresource == other.subresource &&
      subaction == other.subaction;

  @override
  int get hashCode => Object.hash(module, resourceId, action, subresource, subaction);
}

void main() {
  group('fromUri - Level 1: Module', () {
    test('/admin/ -> root', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/'));
      expect(r.module, ''); expect(r.isList, true);
    });
    test('/admin/clients -> clients module', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients'));
      expect(r.module, 'clients'); expect(r.isList, true);
    });
    test('/admin/governance -> governance module', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/governance'));
      expect(r.module, 'governance'); expect(r.isList, true);
    });
    test('/admin/emergency-access -> emergency-access module', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/emergency-access'));
      expect(r.module, 'emergency-access'); expect(r.isList, true);
    });
    test('/admin/token-security -> token-security module', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/token-security'));
      expect(r.module, 'token-security'); expect(r.isList, true);
    });
  });

  group('fromUri - Level 2: Resource + Action', () {
    test('/admin/clients/new -> create', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients/new'));
      expect(r.module, 'clients'); expect(r.isNew, true);
    });
    test('/admin/domains/new -> create domain', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/domains/new'));
      expect(r.module, 'domains'); expect(r.isNew, true);
    });
    test('/admin/threat-policies/new -> create policy', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/threat-policies/new'));
      expect(r.module, 'threat-policies'); expect(r.isNew, true);
    });
    test('/admin/clients/client-abc -> detail view', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients/client-abc'));
      expect(r.module, 'clients'); expect(r.resourceId, 'client-abc');
      expect(r.isDetail, true);
    });
    test('/admin/users/admin -> user detail', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/users/admin'));
      expect(r.module, 'users'); expect(r.resourceId, 'admin');
      expect(r.isDetail, true);
    });
    test('/admin/clients/client-abc/edit -> edit', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients/client-abc/edit'));
      expect(r.module, 'clients'); expect(r.resourceId, 'client-abc');
      expect(r.isEdit, true);
    });
    test('/admin/threat-policies/pol-1/edit -> edit policy', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/threat-policies/pol-1/edit'));
      expect(r.module, 'threat-policies'); expect(r.resourceId, 'pol-1');
      expect(r.isEdit, true);
    });
  });

  group('fromUri - Level 3: Sub-resource', () {
    test('/admin/users/user-xyz/sessions', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/users/user-xyz/sessions'));
      expect(r.module, 'users'); expect(r.resourceId, 'user-xyz');
      expect(r.subresource, 'sessions'); expect(r.hasSubresource, true);
    });
    test('/admin/users/user-xyz/consents', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/users/user-xyz/consents'));
      expect(r.subresource, 'consents');
    });
    test('/admin/users/user-xyz/mfa', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/users/user-xyz/mfa'));
      expect(r.subresource, 'mfa');
    });
    test('/admin/users/user-xyz/lifecycle', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/users/user-xyz/lifecycle'));
      expect(r.subresource, 'lifecycle');
    });
    test('/admin/tenants/t-1/members', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/tenants/t-1/members'));
      expect(r.module, 'tenants'); expect(r.resourceId, 't-1');
      expect(r.subresource, 'members');
    });
    test('/admin/tenants/t-1/invitations', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/tenants/t-1/invitations'));
      expect(r.subresource, 'invitations');
    });
    test('/admin/tenants/t-1/usage', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/tenants/t-1/usage'));
      expect(r.subresource, 'usage');
    });
    test('/admin/clients/c-1/rotate-secret', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients/c-1/rotate-secret'));
      expect(r.module, 'clients'); expect(r.resourceId, 'c-1');
      expect(r.subresource, 'rotate-secret');
    });
    test('/admin/permissions/client-abc/roles', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/permissions/client-abc/roles'));
      expect(r.module, 'permissions'); expect(r.resourceId, 'client-abc');
      expect(r.subresource, 'roles');
    });
    test('/admin/permissions/client-abc/assignments', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/permissions/client-abc/assignments'));
      expect(r.subresource, 'assignments');
    });
    test('/admin/credentials/report', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/credentials/report'));
      expect(r.module, 'credentials'); expect(r.subresource, 'report');
    });
    test('/admin/crypto-keys/rotate', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/crypto-keys/rotate'));
      expect(r.module, 'crypto-keys'); expect(r.subresource, 'rotate');
    });
    test('/admin/governance/audit', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/governance/audit'));
      expect(r.module, 'governance'); expect(r.subresource, 'audit');
    });
    test('/admin/governance/compliance', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/governance/compliance'));
      expect(r.subresource, 'compliance');
    });
    test('/admin/token-security/portfolio', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/token-security/portfolio'));
      expect(r.module, 'token-security'); expect(r.subresource, 'portfolio');
    });
    test('/admin/token-security/temp', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/token-security/temp'));
      expect(r.subresource, 'temp');
    });
    test('/admin/token-security/revoke', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/token-security/revoke'));
      expect(r.subresource, 'revoke');
    });
  });

  group('fromUri - Edge cases', () {
    test('trailing slash', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients/'));
      expect(r.module, 'clients'); expect(r.isList, true);
    });
    test('unknown module', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/unknown-module'));
      expect(r.module, 'unknown-module'); expect(r.isList, true);
    });
    test('non-admin path returns empty', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/other/path'));
      expect(r.module, ''); expect(r.isList, true);
    });
    test('deep path (5 segments)', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/a/b/c/d/e'));
      expect(r.module, 'a'); expect(r.resourceId, 'b');
      expect(r.subresource, 'c'); expect(r.subaction, 'd');
    });
    test('missing module', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('/admin/'));
      expect(r.module, ''); expect(r.isList, true);
    });
    test('id with special chars', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/clients/client-123_456'));
      expect(r.resourceId, 'client-123_456');
    });
    test('uuid style id', () {
      final r = _TestAdminRoute.fromUri(Uri.parse('http://localhost/admin/users/550e8400-e29b-41d4-a716-446655440000/sessions'));
      expect(r.module, 'users');
      expect(r.resourceId, '550e8400-e29b-41d4-a716-446655440000');
      expect(r.subresource, 'sessions');
    });
  });

  group('url generation', () {
    test('module list', () => expect(_TestAdminRoute.url('clients'), '/admin/clients'));
    test('create', () => expect(_TestAdminRoute.url('clients', action: 'new'), '/admin/clients/new'));
    test('detail', () => expect(_TestAdminRoute.url('clients', resourceId: 'abc'), '/admin/clients/abc'));
    test('edit', () => expect(_TestAdminRoute.url('clients', resourceId: 'abc', action: 'edit'), '/admin/clients/abc/edit'));
    test('subresource', () => expect(_TestAdminRoute.url('users', resourceId: 'xyz', subresource: 'sessions'), '/admin/users/xyz/sessions'));
    test('subresource+action', () => expect(
      _TestAdminRoute.url('clients', resourceId: 'c1', subresource: 'rotate-secret'),
      '/admin/clients/c1/rotate-secret'));
    test('governance subresource', () => expect(
      _TestAdminRoute.url('governance', subresource: 'audit'),
      '/admin/governance/audit'));
    test('token-security subresource', () => expect(
      _TestAdminRoute.url('token-security', subresource: 'portfolio'),
      '/admin/token-security/portfolio'));
    test('credentials subresource', () => expect(
      _TestAdminRoute.url('credentials', subresource: 'report'),
      '/admin/credentials/report'));
    test('emergency-access detail', () => expect(
      _TestAdminRoute.url('emergency-access', resourceId: 'session-1'),
      '/admin/emergency-access/session-1'));
  });

  group('property checks', () {
    test('isNew', () => expect(_TestAdminRoute(module: 'clients', action: 'new').isNew, true));
    test('isDetail', () => expect(_TestAdminRoute(module: 'clients', resourceId: 'abc').isDetail, true));
    test('isEdit', () => expect(_TestAdminRoute(module: 'clients', resourceId: 'abc', action: 'edit').isEdit, true));
    test('hasSubresource', () => expect(_TestAdminRoute(module: 'users', resourceId: 'x', subresource: 'sessions').hasSubresource, true));
    test('list is not new', () => expect(_TestAdminRoute(module: 'clients').isNew, false));
    test('list is not detail', () => expect(_TestAdminRoute(module: 'clients').isDetail, false));
    test('new is not list', () => expect(_TestAdminRoute(module: 'clients', action: 'new').isList, false));
    test('detail is not edit', () => expect(_TestAdminRoute(module: 'clients', resourceId: 'abc').isEdit, false));
    test('edit is not detail', () => expect(_TestAdminRoute(module: 'clients', resourceId: 'abc', action: 'edit').isDetail, false));
  });

  group('equality and hash', () {
    test('equal routes', () {
      final a = _TestAdminRoute(module: 'clients', resourceId: 'abc', action: 'edit');
      final b = _TestAdminRoute(module: 'clients', resourceId: 'abc', action: 'edit');
      expect(a == b, true);
      expect(a.hashCode, b.hashCode);
    });
    test('different modules', () {
      final a = _TestAdminRoute(module: 'clients');
      final b = _TestAdminRoute(module: 'users');
      expect(a == b, false);
    });
    test('different resource ids', () {
      final a = _TestAdminRoute(module: 'users', resourceId: 'abc');
      final b = _TestAdminRoute(module: 'users', resourceId: 'xyz');
      expect(a == b, false);
    });
  });
}
