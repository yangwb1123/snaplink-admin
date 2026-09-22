import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';

http.Response _emptyConversations({int status = 200}) => http.Response(
  jsonEncode({'conversations': <Object>[], 'has_more': false}),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  test('preserves a malformed 401 for the one-time token refresh', () async {
    final requests = <http.Request>[];
    var refreshCount = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'old-access',
      refreshAccessToken: (failedToken) async {
        expect(failedToken, 'old-access');
        refreshCount++;
        return 'new-access';
      },
      httpClient: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response.bytes(
            const [0xff],
            401,
            headers: const {'content-type': 'application/json'},
          );
        }
        return _emptyConversations();
      }),
    );
    addTearDown(api.close);

    final page = await api.listConversations();

    expect(page.conversations, isEmpty);
    expect(refreshCount, 1);
    expect(requests, hasLength(2));
    expect(requests[0].headers['authorization'], 'Bearer old-access');
    expect(requests[1].headers['authorization'], 'Bearer new-access');
  });

  test('preserves status after malformed transient read exhaustion', () async {
    var requestCount = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-access',
      httpClient: MockClient((_) async {
        requestCount++;
        return http.Response.bytes(
          const [0xff],
          503,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.listConversations(),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 503)
            .having((error) => error.code, 'code', 'invalid_response'),
      ),
    );
    expect(requestCount, 3);
  });

  test('preserves status after oversized transient read exhaustion', () async {
    var requestCount = 0;
    final oversizedBody = List<int>.filled(1024 * 1024 + 1, 0);
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-access',
      httpClient: MockClient((_) async {
        requestCount++;
        return http.Response.bytes(
          oversizedBody,
          503,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.listConversations(),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 503)
            .having((error) => error.code, 'code', 'response_too_large'),
      ),
    );
    expect(requestCount, 3);
  });
}
