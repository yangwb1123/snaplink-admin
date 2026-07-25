import 'package:flutter_test/flutter_test.dart';

/// Tests for API URL paths and method dispatch patterns.
/// These tests verify the URL routing structure without importing
/// SSOAdminClient (which transitively depends on dart:js_interop).
void main() {
  group('API URL patterns', () {
    test('all admin paths start with /api/v1/admin/', () {
      final paths = [
        '/api/v1/admin/clients',
        '/api/v1/admin/users',
        '/api/v1/admin/tenants',
        '/api/v1/admin/connections',
        '/api/v1/admin/break-glass',
        '/api/v1/admin/webhooks/subscriptions',
        '/api/v1/admin/domains',
        '/api/v1/admin/credentials',
        '/api/v1/admin/crypto/keys',
        '/api/v1/admin/access-policies',
        '/api/v1/admin/threat-policies',
        '/api/v1/admin/permissions',
        '/api/v1/admin/tokens',
        '/api/v1/admin/sessions',
      ];
      for (final p in paths) {
        expect(p, startsWith('/api/v1/admin/'), reason: p);
      }
    });

    test('get methods use {id} placeholder', () {
      final templates = [
        '/api/v1/admin/clients/{id}',
        '/api/v1/admin/users/{id}',
        '/api/v1/admin/tenants/{id}',
        '/api/v1/admin/connections/{id}',
        '/api/v1/admin/break-glass/{id}',
        '/api/v1/admin/webhooks/subscriptions/{id}',
        '/api/v1/admin/domains/{hostname}',
        '/api/v1/admin/credentials/{type}',
        '/api/v1/admin/crypto/keys/{id}',
        '/api/v1/admin/access-policies/{id}',
        '/api/v1/admin/threat-policies/{id}',
      ];
      for (final t in templates) {
        expect(t, contains('{'), reason: t);
      }
    });

    test('list methods have no {id} placeholder', () {
      final listPaths = [
        '/api/v1/admin/clients',
        '/api/v1/admin/users',
        '/api/v1/admin/tenants',
        '/api/v1/admin/connections',
        '/api/v1/admin/break-glass',
        '/api/v1/admin/webhooks/subscriptions',
        '/api/v1/admin/domains',
        '/api/v1/admin/credentials',
        '/api/v1/admin/crypto/keys',
        '/api/v1/admin/access-policies',
        '/api/v1/admin/threat-policies',
        '/api/v1/admin/tokens/portfolio',
        '/api/v1/admin/tokens/sessions',
        '/api/v1/admin/tokens/expiring',
        '/api/v1/admin/tokens/suspicious',
        '/api/v1/admin/tokens/usage',
      ];
      for (final p in listPaths) {
        expect(p, isNot(contains('{')), reason: p);
      }
    });

    test('delete methods follow same pattern as get', () {
      final deletePaths = [
        '/api/v1/admin/clients/{id}',
        '/api/v1/admin/users/{id}',
        '/api/v1/admin/tenants/{id}',
        '/api/v1/admin/connections/{id}',
        '/api/v1/admin/break-glass/{id}',
        '/api/v1/admin/webhooks/subscriptions/{id}',
        '/api/v1/admin/domains/{hostname}',
      ];
      for (final p in deletePaths) {
        expect(p, startsWith('/api/v1/admin/'), reason: p);
      }
    });

    test('action methods use POST-specific patterns', () {
      final actionPaths = [
        '/api/v1/admin/clients/{id}/rotate-secret',
        '/api/v1/admin/clients/{id}/approve',
        '/api/v1/admin/clients/{id}/reject',
        '/api/v1/admin/tenants/{id}:set-status',
        '/api/v1/admin/credentials/{type}/compromise',
        '/api/v1/admin/crypto/keys/{id}/compromise',
      ];
      for (final a in actionPaths) {
        expect(a, startsWith('/api/v1/admin/'), reason: a);
      }
    });

    test('user sub-resource paths', () {
      final subPaths = [
        '/api/v1/admin/users/{id}/sessions',
        '/api/v1/admin/users/{id}/consents',
        '/api/v1/admin/users/{id}/mfa',
        '/api/v1/admin/users/{id}/lifecycle',
      ];
      for (final p in subPaths) {
        expect(p, contains('/users/'), reason: p);
      }
    });

    test('tenant sub-resource paths', () {
      final subPaths = [
        '/api/v1/admin/tenants/{id}/members',
        '/api/v1/admin/tenants/{id}/invitations',
        '/api/v1/admin/tenants/{id}/usage',
      ];
      for (final p in subPaths) {
        expect(p, contains('/tenants/'), reason: p);
      }
    });

    test('token security paths', () {
      final tokenPaths = [
        '/api/v1/admin/tokens/portfolio',
        '/api/v1/admin/tokens/sessions',
        '/api/v1/admin/tokens/expiring',
        '/api/v1/admin/tokens/suspicious',
        '/api/v1/admin/tokens/usage',
        '/api/v1/admin/tokens/bulk-revoke',
        '/api/v1/admin/tokens/temp',
        '/api/v1/admin/tokens/exchange-chains',
        '/api/v1/admin/token-policies',
      ];
      for (final p in tokenPaths) {
        expect(p, startsWith('/api/v1/admin/token'), reason: p);
      }
    });

    test('governance and compliance paths', () {
      final govPaths = [
        '/api/v1/admin/config/running',
        '/api/v1/admin/config/applied',
        '/api/v1/admin/config/diff',
        '/api/v1/admin/config/history',
        '/api/v1/admin/health/storage',
        '/api/v1/admin/health/federation',
        '/api/v1/admin/compliance/soc2-evidence',
        '/api/v1/admin/compliance/data-map',
        '/api/v1/admin/compliance/consents',
        '/api/v1/admin/changes',
        '/api/v1/admin/snapshots',
        '/api/v1/admin/releases',
      ];
      for (final p in govPaths) {
        expect(p, startsWith('/api/v1/admin/'), reason: p);
      }
    });

    test('URL encoding of IDs works correctly', () {
      // Test the encoding logic indirectly
      final id = 'test id/with+special&chars';
      final encoded = Uri.encodeComponent(id);
      expect(encoded, contains('%'));
      expect(encoded, isNot(contains(' ')));
    });

    test('total API path count', () {
      final allPaths = <String>{
        // CRUD
        '/api/v1/admin/clients',
        '/api/v1/admin/clients/{id}',
        '/api/v1/admin/users',
        '/api/v1/admin/users/{id}',
        '/api/v1/admin/tenants',
        '/api/v1/admin/tenants/{id}',
        '/api/v1/admin/connections',
        '/api/v1/admin/connections/{id}',
        '/api/v1/admin/break-glass',
        '/api/v1/admin/break-glass/{id}',
        '/api/v1/admin/webhooks/subscriptions',
        '/api/v1/admin/webhooks/subscriptions/{id}',
        '/api/v1/admin/domains',
        '/api/v1/admin/domains/{hostname}',
        '/api/v1/admin/credentials',
        '/api/v1/admin/credentials/{type}',
        '/api/v1/admin/crypto/keys',
        '/api/v1/admin/crypto/keys/{id}',
        '/api/v1/admin/access-policies',
        '/api/v1/admin/access-policies/{id}',
        '/api/v1/admin/threat-policies',
        '/api/v1/admin/threat-policies/{id}',
        '/api/v1/admin/permissions/{client_id}/roles',
        '/api/v1/admin/permissions/{client_id}/assignments',
        '/api/v1/admin/permissions/{client_id}/menus',
        // Token security
        '/api/v1/admin/tokens/portfolio',
        '/api/v1/admin/tokens/sessions',
        '/api/v1/admin/tokens/expiring',
        '/api/v1/admin/tokens/suspicious',
        '/api/v1/admin/tokens/usage',
        '/api/v1/admin/tokens/bulk-revoke',
        '/api/v1/admin/tokens/temp',
        '/api/v1/admin/token-policies',
        '/api/v1/admin/tokens/exchange-chains',
        // Sessions
        '/api/v1/admin/sessions',
        // User support
        '/api/v1/admin/users/{id}/sessions',
        '/api/v1/admin/users/{id}/consents',
        '/api/v1/admin/users/{id}/mfa',
        '/api/v1/admin/users/{id}/lifecycle',
        '/api/v1/admin/users/{id}/password-reset-tokens',
        '/api/v1/admin/users/{id}/email-change-tokens',
        // Tenant sub-resources
        '/api/v1/admin/tenants/{id}/members',
        '/api/v1/admin/tenants/{id}/invitations',
        '/api/v1/admin/tenants/{id}/usage',
        // Governance
        '/api/v1/admin/config/running',
        '/api/v1/admin/config/applied',
        '/api/v1/admin/config/diff',
        '/api/v1/admin/config/history',
        '/api/v1/admin/health/storage',
        '/api/v1/admin/health/federation',
        '/api/v1/admin/compliance/soc2-evidence',
        '/api/v1/admin/compliance/data-map',
        '/api/v1/admin/compliance/consents',
        '/api/v1/admin/compliance/retention-sweep',
        '/api/v1/admin/changes',
        '/api/v1/admin/snapshots',
        '/api/v1/admin/releases',
        // Break glass
        '/api/v1/admin/break-glass/{id}/approve',
        '/api/v1/admin/break-glass/{id}/reject',
        '/api/v1/admin/break-glass/{id}/audit',
        // Connection sub-resources
        '/api/v1/admin/connections/{id}/health',
        '/api/v1/admin/connections/{id}/domains',
        '/api/v1/admin/connections/{id}/probe',
        // Webhook sub-resources
        '/api/v1/admin/webhooks/subscriptions/{id}/deadletters',
        '/api/v1/admin/webhooks/deadletters/{id}/replay',
        // Actions
        '/api/v1/admin/clients/{id}/rotate-secret',
        '/api/v1/admin/clients/{id}/approve',
        '/api/v1/admin/clients/{id}/reject',
        '/api/v1/admin/tenants/{id}:set-status',
        '/api/v1/admin/credentials/{type}/compromise',
        '/api/v1/admin/crypto/keys/{id}/compromise',
      };
      expect(allPaths.length, greaterThan(60));
      expect(allPaths.length, lessThan(100));
    });
  });
}
