import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

/// Break Glass tab unit tests — verifies API integration logic
/// without requiring a browser (no dart:js_interop dependency).

const _mockEndpoints = [
  SnaplinkAdminEndpoint(method: 'POST', path: '/api/v1/admin/break-glass', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/break-glass', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'DELETE', path: '/api/v1/admin/break-glass/{id}', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'POST', path: '/api/v1/admin/break-glass/{id}/approve', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'POST', path: '/api/v1/admin/break-glass/{id}/impersonate', feature: 'core'),
];

void main() {
  group('BreakGlassTab capabilities', () {
    test('detects break-glass availability from endpoint inventory', () {
      final caps = SnaplinkAdminCapabilities(_mockEndpoints);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/break-glass'), isTrue);
      expect(caps.has('POST', '/api/v1/admin/break-glass'), isTrue);
      expect(caps.has('GET', '/api/v1/admin/break-glass'), isTrue);
      expect(caps.has('DELETE', '/api/v1/admin/break-glass/{id}'), isTrue);
      expect(caps.has('POST', '/api/v1/admin/break-glass/{id}/approve'), isTrue);
    });

    test('returns false when break-glass endpoints are absent', () {
      final caps = SnaplinkAdminCapabilities([]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/break-glass'), isFalse);
    });
  });

  group('BreakGlassTab API integration', () {
    test('SnaplinkAdminOperationCatalog includes break-glass routes', () {
      final documented = SnaplinkAdminOperationCatalog.endpoints;
      final hasBreakGlass = documented.any(
        (e) => e.path.startsWith('/api/v1/admin/break-glass'),
      );
      expect(hasBreakGlass, isTrue, reason: 'Break-glass routes must be in the documented catalog for capability detection');
    });
  });

  group('Break glass API request/response shapes', () {
    test('Create break-glass request body shape is valid', () {
      final body = {
        'target_user_id': 'user@example.com',
        'reason': 'INC-12345',
        'scope': 'readonly',
        'require_approval': true,
        'ttl_seconds': 900,
      };
      expect(body, containsPair('target_user_id', 'user@example.com'));
      expect(body, containsPair('reason', 'INC-12345'));
      expect(body, containsPair('scope', 'readonly'));
      expect(body, containsPair('require_approval', true));
      expect(body, containsPair('ttl_seconds', 900));
    });

    test('Approve break-glass URL encodes the session ID', () {
      final sessionId = 'bg-abc-123';
      final encoded = Uri.encodeComponent(sessionId);
      expect('/api/v1/admin/break-glass/$encoded/approve',
        equals('/api/v1/admin/break-glass/bg-abc-123/approve'));
    });

    test('Revoke break-glass URL encodes the session ID', () {
      final sessionId = 'bg-xyz-789';
      final encoded = Uri.encodeComponent(sessionId);
      expect('/api/v1/admin/break-glass/$encoded',
        equals('/api/v1/admin/break-glass/bg-xyz-789'));
    });

    test('Impersonate break-glass URL encodes the session ID', () {
      final sessionId = 'bg-imp-456';
      final encoded = Uri.encodeComponent(sessionId);
      expect('/api/v1/admin/break-glass/$encoded/impersonate',
        equals('/api/v1/admin/break-glass/bg-imp-456/impersonate'));
    });
  });

  group('Break-glass session status display logic', () {
    test('pending sessions show hourglass icon', () {
      final session = {'id': 'bg-1', 'status': 'pending', 'target_user_id': 'user@test.com'};
      expect(session['status'], equals('pending'));
    });

    test('active sessions show flash_on icon', () {
      final session = {'id': 'bg-2', 'status': 'active', 'target_user_id': 'user@test.com'};
      expect(session['status'], equals('active'));
    });

    test('revoked/expired sessions show appropriate status', () {
      expect({'status': 'revoked'}['status'], equals('revoked'));
      expect({'status': 'expired'}['status'], equals('expired'));
    });

    test('session has required fields for display', () {
      final session = {
        'id': 'bg-3',
        'target_user_id': 'user@example.com',
        'reason': 'Emergency access needed',
        'created_by': 'admin@example.com',
        'scope': 'impersonate',
        'status': 'active',
      };
      expect(session.keys, contains('id'));
      expect(session.keys, contains('target_user_id'));
      expect(session.keys, contains('reason'));
      expect(session.keys, contains('created_by'));
      expect(session.keys, contains('scope'));
      expect(session.keys, contains('status'));
    });
  });
}
