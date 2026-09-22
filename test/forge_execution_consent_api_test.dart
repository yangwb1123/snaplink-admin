import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

const _profileDigest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _preview({String conversationID = 'conversation-1'}) => {
  'conversation_id': conversationID,
  'project_id': 'project-1',
  'profile_id': 'profile-1',
  'profile_sha256': _profileDigest,
  'maximum_ttl_ms': 2592000000,
};

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  test('parses and round-trips the exact five-field preview', () {
    final parsed = ForgeExecutionConsentPreview.fromJson(_preview());

    expect(parsed.conversationID, 'conversation-1');
    expect(parsed.projectID, 'project-1');
    expect(parsed.profileID, 'profile-1');
    expect(parsed.profileSHA256, _profileDigest);
    expect(parsed.maximumTTLMS, 2592000000);
    expect(parsed.toJson(), _preview());
  });

  test('rejects expanded, incomplete, and malformed preview responses', () {
    final expanded = _preview()..['extra'] = true;
    expect(
      () => ForgeExecutionConsentPreview.fromJson(expanded),
      throwsA(isA<FormatException>()),
    );

    final incomplete = _preview()..remove('maximum_ttl_ms');
    expect(
      () => ForgeExecutionConsentPreview.fromJson(incomplete),
      throwsA(isA<FormatException>()),
    );

    for (final malformed in [
      {..._preview(), 'profile_sha256': _profileDigest.toUpperCase()},
      {..._preview(), 'profile_sha256': 'not-a-digest'},
      {..._preview(), 'project_id': 'project/foreign'},
      {..._preview(), 'maximum_ttl_ms': 0},
      {..._preview(), 'maximum_ttl_ms': 2592000001},
      {..._preview(), 'maximum_ttl_ms': 9007199254740992},
    ]) {
      expect(
        () => ForgeExecutionConsentPreview.fromJson(malformed),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'GETs the owner-scoped preview without a body or write headers',
    () async {
      late http.Request sent;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          sent = request;
          return _json(_preview());
        }),
      );
      addTearDown(api.close);

      final preview = await api.getExecutionConsentPreview(
        conversationID: 'conversation-1',
      );

      expect(preview.conversationID, 'conversation-1');
      expect(sent.method, 'GET');
      expect(
        sent.url.path,
        '/api/v1/conversations/conversation-1/execution-consents',
      );
      expect(sent.url.query, isEmpty);
      expect(sent.body, isEmpty);
      expect(sent.headers['accept'], 'application/json');
      expect(sent.headers['authorization'], 'Bearer forge-bearer');
      expect(sent.headers['cache-control'], 'no-store');
      expect(sent.headers.containsKey('content-type'), isFalse);
      expect(sent.headers.containsKey('idempotency-key'), isFalse);
    },
  );

  test(
    'retries a transient preview GET and keeps its exact request shape',
    () async {
      final requests = <http.Request>[];
      var requestCount = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          requests.add(request);
          requestCount++;
          if (requestCount == 1) {
            return _json({'code': 'temporary'}, status: 503);
          }
          return _json(_preview());
        }),
      );
      addTearDown(api.close);

      final preview = await api.getExecutionConsentPreview(
        conversationID: 'conversation-1',
      );

      expect(preview.profileID, 'profile-1');
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/v1/conversations/conversation-1/execution-consents',
        );
        expect(request.body, isEmpty);
        expect(request.headers['authorization'], 'Bearer forge-bearer');
        expect(request.headers.containsKey('content-type'), isFalse);
        expect(request.headers.containsKey('idempotency-key'), isFalse);
      }
    },
  );

  test(
    'does not refresh or replay when unauthorized retry is disabled',
    () async {
      var requestCount = 0;
      var refreshCount = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        refreshAccessToken: (_) async {
          refreshCount++;
          return 'rotated-bearer';
        },
        httpClient: MockClient((request) async {
          requestCount++;
          return _json({'code': 'unauthorized'}, status: 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.getExecutionConsentPreview(
          conversationID: 'conversation-1',
          retryUnauthorized: false,
        ),
        throwsA(isA<ForgeConversationsApiException>()),
      );
      expect(requestCount, 1);
      expect(refreshCount, 0);
    },
  );

  test('rejects a preview bound to another conversation', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient(
        (_) async => _json(_preview(conversationID: 'conversation-foreign')),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.getExecutionConsentPreview(conversationID: 'conversation-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsafe conversation IDs before any request', () async {
    var requests = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        requests++;
        return _json(_preview());
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.getExecutionConsentPreview(conversationID: 'conversation/foreign'),
      throwsArgumentError,
    );
    expect(requests, 0);
  });
}
