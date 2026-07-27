import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/jarm_completion.dart';

void main() {
  final signedResponse = _jwt({
    'iss': 'https://issuer.example',
    'aud': 'rp-client',
    'exp': 4102444800,
    'code': 'authorization-code',
    'state': 'state-1',
  });

  group('JARM completion policy', () {
    test('blocks a bare JSON code for query.jwt', () {
      final result = resolveJarmCompletion(
        responseMode: 'query.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: const {'code': 'unsigned-code', 'state': 'state-1'},
        authorizationEndpoint: Uri.parse('https://console.example/auth/login'),
      );

      expect(result.accepted, isFalse);
      expect(result.redirectTarget, isNull);
      expect(result.error, JarmCompletion.blockedMessage);
    });

    test('blocks ordinary tokens for fragment.jwt', () {
      final result = resolveJarmCompletion(
        responseMode: 'fragment.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: const {
          'access_token': 'unsigned-access-token',
          'id_token': 'unsigned-id-token',
        },
      );

      expect(result.accepted, isFalse);
      expect(result.redirectTarget, isNull);
    });

    test('accepts an exact server-owned query continuation', () {
      final continuation = Uri.parse(
        'https://rp.example/callback?tenant=one'
        '&response=${Uri.encodeQueryComponent(signedResponse)}',
      );
      final result = resolveJarmCompletion(
        responseMode: 'jwt',
        redirectUri: 'https://rp.example/callback?tenant=one',
        responseData: const {},
        serverContinuation: continuation,
        authorizationEndpoint: Uri.parse('https://console.example/auth/login'),
      );

      expect(result.accepted, isTrue);
      expect(result.redirectTarget, continuation);
      expect(
        result.redirectTarget!.queryParameters['response'],
        signedResponse,
      );
    });

    test('rejects a continuation with the wrong RP endpoint or channel', () {
      final wrongHost = resolveJarmCompletion(
        responseMode: 'query.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: const {},
        serverContinuation: Uri.parse(
          'https://attacker.example/callback?response=$signedResponse',
        ),
      );
      final wrongChannel = resolveJarmCompletion(
        responseMode: 'fragment.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: const {},
        serverContinuation: Uri.parse(
          'https://rp.example/callback?response=$signedResponse',
        ),
        authorizationEndpoint: Uri.parse('https://console.example/auth/login'),
      );

      expect(wrongHost.accepted, isFalse);
      expect(wrongChannel.accepted, isFalse);
    });

    test('rejects executable, relative, and public insecure redirects', () {
      for (final redirect in [
        'javascript:alert(1)',
        '/relative/callback',
        'http://rp.example/callback',
      ]) {
        final result = resolveJarmCompletion(
          responseMode: 'query.jwt',
          redirectUri: redirect,
          responseData: {'response': signedResponse},
        );
        expect(result.accepted, isFalse, reason: redirect);
      }
    });

    test('delivers only a server-provided compact signed response', () {
      final result = resolveJarmCompletion(
        responseMode: 'fragment.jwt',
        redirectUri: 'https://rp.example/callback?tenant=one',
        responseData: {'response': signedResponse},
      );

      expect(result.accepted, isTrue);
      expect(result.redirectTarget!.queryParameters['tenant'], 'one');
      expect(
        Uri(query: result.redirectTarget!.fragment).queryParameters['response'],
        signedResponse,
      );
    });

    test('rejects an unsigned JWT and mixed bare protocol fields', () {
      final unsigned = _jwt(
        {'code': 'code'},
        algorithm: 'none',
        signature: 'unsigned',
      );
      final unsignedResult = resolveJarmCompletion(
        responseMode: 'query.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: {'response': unsigned},
      );
      final mixedResult = resolveJarmCompletion(
        responseMode: 'query.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: {'response': signedResponse, 'code': 'also-bare'},
      );

      expect(unsignedResult.accepted, isFalse);
      expect(mixedResult.accepted, isFalse);
    });

    test('accepts only a direct server-generated JARM form post', () {
      final html =
          '<form method="POST" '
          'action="https://rp.example/callback?tenant=one&amp;step=two">'
          '<input type="hidden" name="response" value="$signedResponse">'
          '</form>';
      final result = resolveJarmCompletion(
        responseMode: 'form_post.jwt',
        redirectUri: 'https://rp.example/callback?tenant=one&step=two',
        responseData: const {},
        serverFormPost: html,
        serverContinuation: Uri.parse('https://console.example/auth/login'),
        authorizationEndpoint: Uri.parse('https://console.example/auth/login'),
      );

      expect(result.accepted, isTrue);
      expect(result.formPostHtml, html);
    });

    test('rejects a form post that leaks a bare code', () {
      final result = resolveJarmCompletion(
        responseMode: 'form_post.jwt',
        redirectUri: 'https://rp.example/callback',
        responseData: const {},
        serverFormPost:
            '<form method="post" action="https://rp.example/callback">'
            '<input name="response" value="$signedResponse">'
            '<input name="code" value="bare-code">'
            '</form>',
      );

      expect(result.accepted, isFalse);
    });
  });
}

String _jwt(
  Map<String, Object> payload, {
  String algorithm = 'EdDSA',
  String signature = 'signed',
}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': algorithm, 'typ': 'JWT'})}.'
      '${encode(payload)}.'
      '${base64Url.encode(utf8.encode(signature)).replaceAll('=', '')}';
}
