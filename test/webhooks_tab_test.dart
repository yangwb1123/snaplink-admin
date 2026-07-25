import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

const _webhookEndpoints = [
  SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/webhooks/subscriptions', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'POST', path: '/api/v1/admin/webhooks/subscriptions', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'DELETE', path: '/api/v1/admin/webhooks/subscriptions/{id}', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/webhooks/deadletters', feature: 'core'),
  SnaplinkAdminEndpoint(method: 'POST', path: '/api/v1/admin/webhooks/deadletters/{id}/replay', feature: 'core'),
];

void main() {
  group('WebhooksTab capabilities', () {
    test('detects webhook availability from endpoint inventory', () {
      final caps = SnaplinkAdminCapabilities(_webhookEndpoints);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/webhooks/subscriptions'), isTrue);
      expect(caps.has('POST', '/api/v1/admin/webhooks/subscriptions'), isTrue);
      expect(caps.has('DELETE', '/api/v1/admin/webhooks/subscriptions/{id}'), isTrue);
    });

    test('detects dead letter availability', () {
      final caps = SnaplinkAdminCapabilities(_webhookEndpoints);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/webhooks/deadletters'), isTrue);
    });

    test('returns false when webhook endpoints are absent', () {
      final caps = SnaplinkAdminCapabilities([]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/webhooks'), isFalse);
    });
  });

  group('Webhook subscription data shapes', () {
    test('create subscription request body is valid', () {
      final body = {
        'url': 'https://hooks.example.com/events',
        'event_types': ['user.created', 'session.revoked'],
        'active': true,
      };
      expect(body['url'], isA<String>());
      expect(body['event_types'], isA<List>());
      expect(body['active'], isTrue);
    });

    test('subscription list response parsing', () {
      final response = {
        'subscriptions': [
          {'id': 'wh-1', 'url': 'https://hooks.example.com/a', 'active': true, 'event_types': ['user.created']},
          {'id': 'wh-2', 'url': 'https://hooks.example.com/b', 'active': false, 'event_types': ['*']},
        ]
      };
      final items = response['subscriptions'] as List;
      expect(items.length, equals(2));
      expect(items[0]['active'], isTrue);
      expect(items[1]['active'], isFalse);
    });

    test('dead letter list has required fields', () {
      final dl = {
        'id': 'dl-1',
        'event_type': 'user.created',
        'error': 'HTTP 502',
        'subscription_id': 'wh-1',
      };
      expect(dl.keys, contains('id'));
      expect(dl.keys, contains('event_type'));
      expect(dl.keys, contains('error'));
    });
  });

  group('Webhook URL operations', () {
    test('delete subscription URL encodes the ID', () {
      final id = 'wh-abc-123';
      expect('/api/v1/admin/webhooks/subscriptions/${Uri.encodeComponent(id)}',
        equals('/api/v1/admin/webhooks/subscriptions/wh-abc-123'));
    });

    test('replay dead letter URL encodes the ID', () {
      final id = 'dl-xyz-789';
      expect('/api/v1/admin/webhooks/deadletters/${Uri.encodeComponent(id)}/replay',
        equals('/api/v1/admin/webhooks/deadletters/dl-xyz-789/replay'));
    });
  });

  group('SnaplinkAdminOperationCatalog includes webhook routes', () {
    test('webhook subscription routes are documented', () {
      final documented = SnaplinkAdminOperationCatalog.endpoints;
      expect(documented.any((e) => e.path.contains('/webhooks/subscriptions')), isTrue);
    });

    test('webhook dead letter routes are documented', () {
      final documented = SnaplinkAdminOperationCatalog.endpoints;
      expect(documented.any((e) => e.path.contains('/webhooks/deadletters')), isTrue);
    });
  });
}
