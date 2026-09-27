import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

void main() {
  test(
    'posts one authenticated append and returns a content-free receipt',
    () async {
      final sent = <http.Request>[];
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          sent.add(request);
          return _json(_appendResponse());
        }),
      );
      addTearDown(api.close);

      final receipt = await api.appendPromptReceipt(
        owner: _owner,
        conversationID: 'conversation-001',
        content: 'send this from another client',
        expectedVersion: 2,
        idempotencyKey: 'prompt-key-003',
      );

      expect(sent, hasLength(1));
      expect(sent.single.method, 'POST');
      expect(
        sent.single.url.path,
        '/api/v1/conversations/conversation-001/prompts',
      );
      expect(sent.single.headers['authorization'], 'Bearer forge-bearer');
      expect(sent.single.headers['idempotency-key'], 'prompt-key-003');
      expect(receipt.owner, _owner);
      expect(receipt.request.conversationID, 'conversation-001');
      expect(receipt.request.expectedVersion, 2);
      expect(receipt.request.role, 'user');
      expect(
        receipt.request.contentSHA256,
        'ba7c92f7b6cf793207184c5eeb0faf9d07f20f822122a3496981848a16237477',
      );
      expect(
        receipt.request.idempotencyKeySHA256,
        '28000a1da51a81095e5dcd089338c3884c551a2538343d090e6459542dc1f3b9',
      );
      expect(receipt.receipt.promptID, 'prompt-003');
      expect(receipt.receipt.aggregateVersion, 3);
      expect(receipt.receipt.contentIncluded, isFalse);
      expect(receipt.isDisplayOnly, isTrue);
      expect(
        jsonEncode(receipt.toJson()),
        isNot(contains('send this from another client')),
      );
    },
  );

  test(
    'rejects CAS, role, conversation, and content drift before returning a receipt',
    () async {
      final responses = <Map<String, dynamic>>[
        _appendResponse()..['aggregate_version'] = 4,
        _appendResponse()
          ..['prompt'] = {
            ...((_appendResponse()['prompt'] as Map).cast<String, dynamic>()),
            'role': 'assistant',
          },
        _appendResponse()
          ..['prompt'] = {
            ...((_appendResponse()['prompt'] as Map).cast<String, dynamic>()),
            'conversation_id': 'conversation-foreign',
          },
        _appendResponse()
          ..['prompt'] = {
            ...((_appendResponse()['prompt'] as Map).cast<String, dynamic>()),
            'content': 'foreign content',
          },
      ];
      for (final response in responses) {
        final api = ForgeConversationsApi(
          baseUrl: 'https://forge.example',
          accessToken: 'token',
          httpClient: MockClient((_) async => _json(response)),
        );
        addTearDown(api.close);
        await expectLater(
          api.appendPromptReceipt(
            owner: _owner,
            conversationID: 'conversation-001',
            content: 'send this from another client',
            expectedVersion: 2,
            idempotencyKey: 'prompt-key-003',
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'does not refresh or replay the authenticated append after 401',
    () async {
      var calls = 0;
      var refreshes = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'token',
        refreshAccessToken: (_) async {
          refreshes++;
          return 'rotated';
        },
        httpClient: MockClient((_) async {
          calls++;
          return _json({
            'code': 'unauthorized',
            'message': 'private',
          }, status: 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.appendPromptReceipt(
          owner: _owner,
          conversationID: 'conversation-001',
          content: 'send this from another client',
          expectedVersion: 2,
          idempotencyKey: 'prompt-key-003',
        ),
        throwsA(
          isA<ForgeConversationsApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(calls, 1);
      expect(refreshes, 0);
    },
  );

  test(
    'rejects malformed owner and append inputs before network access',
    () async {
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'token',
        httpClient: MockClient((_) async {
          calls++;
          return _json(_appendResponse());
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.appendPromptReceipt(
          owner: const ForgeDeviceOwner(
            issuer: '',
            subject: 'user-1',
            tenantID: 'tenant-1',
          ),
          conversationID: 'conversation-001',
          content: 'send this from another client',
          expectedVersion: 2,
          idempotencyKey: 'prompt-key-003',
        ),
        throwsFormatException,
      );
      await expectLater(
        api.appendPromptReceipt(
          owner: _owner,
          conversationID: 'conversation-001',
          content: 'send this from another client',
          expectedVersion: 0,
          idempotencyKey: 'prompt-key-003',
        ),
        throwsArgumentError,
      );
      await expectLater(
        api.appendPromptReceipt(
          owner: _owner,
          conversationID: 'conversation-001',
          content: 'send this from another client',
          expectedVersion: 2,
          idempotencyKey: ' prompt-key-003 ',
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );
}

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _appendResponse() => {
  'prompt': {
    'id': 'prompt-003',
    'conversation_id': 'conversation-001',
    'role': 'user',
    'content': 'send this from another client',
    'created_at_ms': 300,
  },
  'aggregate_version': 3,
  'replayed': false,
};

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);
