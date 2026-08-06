@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/oidc_login/federated_login.dart';
import 'package:sso_admin/services/session_storage.dart';
import 'package:web/web.dart' as web;

void main() {
  test('accepts only the exact server continuation fragment', () {
    final transactionId = 'A' * 43;
    expect(
      hostedFederatedTransactionId(
        Uri.parse(
          'https://console.example/login/?client_id=rp'
          '#login_transaction_id=$transactionId',
        ),
      ),
      transactionId,
    );
    expect(
      hostedFederatedTransactionId(
        Uri.parse(
          'https://console.example/login/'
          '#login_transaction_id=$transactionId&extra=value',
        ),
      ),
      isNull,
    );
    expect(
      hostedFederatedTransactionId(
        Uri.parse(
          'https://console.example/login/#login_transaction_id=too-short',
        ),
      ),
      isNull,
    );
  });

  test('recognizes only this tab\'s pending PKCE callback', () {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    addTearDown(() {
      web.window.history.replaceState(null, '', originalLocation);
      SessionStorage.removeItem('sso_pkce_state');
    });

    const callback = 'https://console.example/login/?state=owned-state';
    web.window.history.replaceState(null, '', '/login/?state=owned-state');
    expect(
      FederatedLogin.hasPendingReturn(location: Uri.parse(callback)),
      isFalse,
    );

    SessionStorage.setItem('sso_pkce_state', 'other-state');
    expect(
      FederatedLogin.hasPendingReturn(location: Uri.parse(callback)),
      isFalse,
    );

    SessionStorage.setItem('sso_pkce_state', 'owned-state');
    expect(
      FederatedLogin.hasPendingReturn(location: Uri.parse(callback)),
      isTrue,
    );
    expect(
      FederatedLogin.hasPendingReturn(
        location: Uri.parse(
          'https://console.example/login/?state=owned-state&state=owned-state',
        ),
      ),
      isFalse,
    );
  });

  test(
    'keeps the local return target out of OAuth state and scrubs callback',
    () async {
      final originalLocation =
          '${web.window.location.pathname}'
          '${web.window.location.search}'
          '${web.window.location.hash}';
      addTearDown(
        () => web.window.history.replaceState(null, '', originalLocation),
      );

      final beginUrl = FederatedLogin.beginLoginUrl(
        connectionId: 'workforce',
        clientId: 'console-client',
        redirectTarget: '/portal/?flow=invitation&token=account-action-secret',
      );
      final state = Uri.parse(beginUrl).queryParameters['state']!;

      expect(state, isNot(contains('|')));
      expect(beginUrl, isNot(contains('account-action-secret')));

      web.window.history.replaceState(
        null,
        '',
        '/login/?code=authorization-secret&state=${Uri.encodeComponent(state)}'
            '#callback-fragment',
      );
      final client = MockClient((request) async {
        expect(web.window.location.pathname, '/login/');
        expect(web.window.location.search, isEmpty);
        expect(web.window.location.hash, isEmpty);
        expect(request.url.path, '/token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 'authorization-secret');
        expect(body['code_verifier'], isNotEmpty);
        return http.Response('{"access_token":"federated-access"}', 200);
      });

      final result = await FederatedLogin.consumeReturnIfPresent(
        httpClient: client,
      );

      expect(result?.accessToken, 'federated-access');
      expect(
        result?.redirectTarget,
        '/portal/?flow=invitation&token=account-action-secret',
      );
      expect(web.window.location.href, isNot(contains('authorization-secret')));
      expect(web.window.location.href, isNot(contains(state)));
    },
  );

  test(
    'consumes and scrubs a matching provider error without exchange',
    () async {
      final originalLocation =
          '${web.window.location.pathname}'
          '${web.window.location.search}'
          '${web.window.location.hash}';
      addTearDown(
        () => web.window.history.replaceState(null, '', originalLocation),
      );

      final beginUrl = FederatedLogin.beginLoginUrl(
        connectionId: 'workforce',
        clientId: 'console-client',
        redirectTarget: '/admin/',
      );
      final state = Uri.parse(beginUrl).queryParameters['state']!;
      web.window.history.replaceState(
        null,
        '',
        '/login/?error=access_denied&error_description=Denied&'
            'state=${Uri.encodeComponent(state)}',
      );

      await expectLater(
        FederatedLogin.consumeReturnIfPresent(),
        throwsA(isA<StateError>()),
      );

      expect(web.window.location.pathname, '/login/');
      expect(web.window.location.search, isEmpty);
      expect(web.window.location.hash, isEmpty);
      expect(await FederatedLogin.consumeReturnIfPresent(), isNull);
    },
  );

  test('rejects duplicate matching callback state and scrubs it', () async {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    addTearDown(() {
      web.window.history.replaceState(null, '', originalLocation);
      SessionStorage.removeItem('sso_pkce_state');
    });

    final beginUrl = FederatedLogin.beginLoginUrl(
      connectionId: 'workforce',
      clientId: 'console-client',
      redirectTarget: '/admin/',
    );
    final state = Uri.parse(beginUrl).queryParameters['state']!;
    web.window.history.replaceState(
      null,
      '',
      '/login/?code=authorization-secret&state=${Uri.encodeComponent(state)}'
          '&state=${Uri.encodeComponent(state)}',
    );

    await expectLater(
      FederatedLogin.consumeReturnIfPresent(),
      throwsA(isA<StateError>()),
    );
    expect(web.window.location.search, isEmpty);
    expect(SessionStorage.getItem('sso_pkce_state'), isNull);
  });
}
