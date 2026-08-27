@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';
import 'package:sso_admin/screens/portal/portal_security_contract.dart';

const _portalSourceDir = 'lib/screens/portal';
const _contractRelativePath = 'portal_security_contract.dart';
const _portalApiShimRelativePath = 'portal_api.dart';
const _portalPathOwnerFiles = <String>{
  _contractRelativePath,
  _portalApiShimRelativePath,
};

class _DartStringLiteral {
  final String content;
  final int line;

  const _DartStringLiteral(this.content, this.line);
}

/// Returns Dart string literals without treating comments as source. This is
/// deliberately a small lexer rather than a regex: path-looking text in
/// comments, including commented-out requests, is not an ownership finding.
List<_DartStringLiteral> _dartStringLiterals(String source) {
  final literals = <_DartStringLiteral>[];
  var index = 0;
  var line = 1;

  void advanceOne() {
    if (source[index] == '\n') line++;
    index++;
  }

  while (index < source.length) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (char == '/' && next == '/') {
      index += 2;
      while (index < source.length && source[index] != '\n') {
        index++;
      }
      continue;
    }
    if (char == '/' && next == '*') {
      var depth = 1;
      index += 2;
      while (index < source.length && depth > 0) {
        final blockChar = source[index];
        final blockNext = index + 1 < source.length ? source[index + 1] : '';
        if (blockChar == '/' && blockNext == '*') {
          depth++;
          index += 2;
        } else if (blockChar == '*' && blockNext == '/') {
          depth--;
          index += 2;
        } else {
          advanceOne();
        }
      }
      continue;
    }

    final raw = char == 'r' && (next == "'" || next == '"');
    final quoteIndex = raw ? index + 1 : index;
    final isQuote = char == "'" || char == '"';
    if (!isQuote && !raw) {
      advanceOne();
      continue;
    }

    final quote = source[quoteIndex];
    final triple =
        quoteIndex + 2 < source.length &&
        source[quoteIndex + 1] == quote &&
        source[quoteIndex + 2] == quote;
    final literalLine = line;
    index = quoteIndex + (triple ? 3 : 1);
    final content = StringBuffer();

    while (index < source.length) {
      if (triple &&
          index + 2 < source.length &&
          source[index] == quote &&
          source[index + 1] == quote &&
          source[index + 2] == quote) {
        index += 3;
        break;
      }
      if (!triple && source[index] == quote) {
        index++;
        break;
      }
      if (!raw && source[index] == '\\') {
        content.write(source[index]);
        index++;
        if (index < source.length) {
          content.write(source[index]);
          if (source[index] == '\n') line++;
          index++;
        }
        continue;
      }
      content.write(source[index]);
      if (source[index] == '\n') line++;
      index++;
    }
    literals.add(_DartStringLiteral(content.toString(), literalLine));
  }
  return literals;
}

/// The contract source supplies the path roots. No consumer file gets a
/// second, test-owned route allowlist; adding a route to the contract is an
/// intentional contract change and is pinned by the wire-value tests below.
Set<String> _portalPathRoots(String contractSource) {
  final roots = <String>{};
  for (final literal in _dartStringLiterals(contractSource)) {
    final content = literal.content.trim();
    if (!content.startsWith('/')) continue;
    final dollar = content.indexOf(r'$');
    roots.add(dollar == -1 ? content : content.substring(0, dollar));
  }
  return roots;
}

String? _matchingPortalRoot(String content, Set<String> roots) {
  // A user-facing message can contain a route-looking fragment (the portal
  // UI currently explains the /me/devices shape this way). API endpoint
  // literals cannot contain source whitespace; rejecting it keeps the guard
  // focused on wire strings rather than prose.
  if (content.contains(RegExp(r'\s'))) return null;
  final ordered = roots.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final root in ordered) {
    if (!content.startsWith(root)) continue;
    if (content.length == root.length || root.endsWith('=')) return root;
    final next = content[root.length];
    if (next == '/' || next == '?' || next == r'$') return root;
  }
  return null;
}

List<String> scanPortalPathSource(
  String source,
  String fileLabel,
  Set<String> contractRoots,
) {
  if (_portalPathOwnerFiles.contains(fileLabel)) return const [];
  return [
    for (final literal in _dartStringLiterals(source))
      if (_matchingPortalRoot(literal.content, contractRoots) case final root?)
        '$fileLabel:${literal.line}: API path literal "${literal.content}" '
            'is owned by $_contractRelativePath (matched "$root")',
  ];
}

List<String> scanPortalPathOwnership([String directory = _portalSourceDir]) {
  final root = Directory(directory).absolute;
  final contractFile = File(
    '${root.path}${Platform.pathSeparator}$_contractRelativePath',
  );
  if (!contractFile.existsSync()) {
    throw StateError('Portal path contract not found: ${contractFile.path}');
  }
  final contractRoots = _portalPathRoots(contractFile.readAsStringSync());
  final violations = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    violations.addAll(
      scanPortalPathSource(entity.readAsStringSync(), relative, contractRoots),
    );
  }
  return violations;
}

String _readPortalFile(String relativePath) => File(
  '${Directory(_portalSourceDir).path}${Platform.pathSeparator}'
  '${relativePath.replaceAll('/', Platform.pathSeparator)}',
).readAsStringSync();

void main() {
  group('Portal path ownership guard', () {
    test('all governed API literals stay in the contract file', () {
      final violations = scanPortalPathOwnership();
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('the guard is non-vacuous and the API shim stays re-export-only', () {
      final contract = _readPortalFile(_contractRelativePath);
      final roots = _portalPathRoots(contract);
      expect(roots, contains('/me'));
      expect(roots, contains('/me/notifications'));
      expect(_portalPathOwnerFiles, {
        _contractRelativePath,
        _portalApiShimRelativePath,
      });

      final shimLines = _readPortalFile(_portalApiShimRelativePath)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('//'))
          .toList();
      expect(shimLines, ["export 'package:sso_admin/api/portal_api.dart';"]);
    });

    test('ignores comments, server data, and /portal UI routes', () {
      final roots = _portalPathRoots(_readPortalFile(_contractRelativePath));
      final source = [
        "// await api.get('/me/notifications');",
        '/* await api.post("/me/password"); */',
        "final endpoint = payload['path'];",
        "final route = '/portal/settings';",
      ].join('\n');
      expect(
        scanPortalPathSource(source, 'notifications_tab.dart', roots),
        isEmpty,
      );
    });

    test('flags a raw consumer literal, including an interpolated id', () {
      final roots = _portalPathRoots(_readPortalFile(_contractRelativePath));
      final source = "final endpoint = '/me/notifications/\${id}/read';";
      final violations = scanPortalPathSource(
        source,
        'notifications_tab.dart',
        roots,
      );
      expect(violations, hasLength(1), reason: violations.join('\n'));
      expect(violations.single, contains('owned by $_contractRelativePath'));
    });
  });

  group('PortalPaths wire contract', () {
    test('pins every static path to its existing wire value', () {
      expect(PortalPaths.me, '/me');
      expect(PortalPaths.identities, '/me/identities');
      expect(PortalPaths.organizations, '/me/organizations');
      expect(PortalPaths.notifications, '/me/notifications');
      expect(
        PortalPaths.notificationPreferences,
        '/me/notifications/preferences',
      );
      expect(PortalPaths.notificationStream, '/me/notifications/stream');
      expect(PortalPaths.mfa, '/me/mfa');
      expect(PortalPaths.mfaRecoveryCodes, '/me/mfa/recovery-codes');
      expect(PortalPaths.webauthnBegin, '/me/mfa/webauthn/begin');
      expect(PortalPaths.totpBegin, '/me/mfa/totp/begin');
      expect(PortalPaths.totpConfirm, '/me/mfa/totp/confirm');
      expect(PortalPaths.password, '/me/password');
      expect(PortalPaths.emailChange, '/me/email/change');
      expect(PortalPaths.emailVerify, '/me/email/verify');
      expect(PortalPaths.dataExport, '/me/data-export');
      expect(PortalPaths.accountErase, '/me/account/erase');
      expect(PortalPaths.consents, '/consents/me');
      expect(PortalPaths.roles, '/roles/me');
      expect(PortalPaths.permissions, '/permissions/me');
      expect(PortalPaths.menus, '/menus/me');
      expect(PortalPaths.invitationAccept, '/me/invitations/accept');
    });

    test('encodes every resource id in its wire position', () {
      expect(
        PortalPaths.identity('identity / one'),
        '/me/identities/identity%20%2F%20one',
      );
      expect(
        PortalPaths.organization('tenant / one'),
        '/me/organizations/tenant%20%2F%20one',
      );
      expect(
        PortalPaths.organizationMembers('tenant / one'),
        '/me/organizations/tenant%20%2F%20one/members',
      );
      expect(
        PortalPaths.organizationMember('tenant / one', 'user / one'),
        '/me/organizations/tenant%20%2F%20one/members/user%20%2F%20one',
      );
      expect(
        PortalPaths.organizationInvitations('tenant / one'),
        '/me/organizations/tenant%20%2F%20one/invitations',
      );
      expect(
        PortalPaths.organizationInvitation('tenant / one', 'a+b@example.com'),
        '/me/organizations/tenant%20%2F%20one/invitations/a%2Bb%40example.com',
      );
      expect(
        PortalPaths.notificationRead('notification / one'),
        '/me/notifications/notification%20%2F%20one/read',
      );
      expect(
        PortalPaths.consent('client / one'),
        '/consents/me/client%20%2F%20one',
      );
      expect(
        PortalPaths.mfaFactor('factor / one'),
        '/me/mfa/factor%20%2F%20one',
      );
      expect(
        PortalPaths.webauthnFinish('transaction / one'),
        '/me/mfa/webauthn/finish?session_id=transaction%20%2F%20one',
      );
    });
  });

  group('device response classification', () {
    test('builds the mounted physical-device subresource paths', () {
      expect(
        PortalSecurityPaths.device('phone / one'),
        '/me/devices/phone%20%2F%20one',
      );
      expect(
        PortalSecurityPaths.trustedDevice('browser / one'),
        '/me/trusted-devices/browser%20%2F%20one',
      );
      expect(
        PortalSecurityPaths.trustCurrentBrowser,
        '/me/trusted-devices/trust',
      );
      expect(
        PortalSecurityPaths.deviceActivity('device-1'),
        '/me/devices/device-1/activity',
      );
      expect(
        PortalSecurityPaths.deviceSessions('device-1'),
        '/me/devices/device-1/sessions',
      );
      expect(
        PortalSecurityPaths.deviceTrust('device-1'),
        '/me/devices/device-1/trust',
      );
      expect(
        PortalSecurityPaths.deviceLost('device-1'),
        '/me/devices/device-1/lost',
      );
      expect(
        PortalSecurityPaths.legacySession('session / one'),
        '/sessions/me/session%20%2F%20one',
      );
    });

    test('distinguishes physical devices from MFA trusted grants', () {
      final physical = <String, dynamic>{
        'id': 'device-1',
        'fingerprint': 'opaque-fingerprint',
        'platform': 'macOS',
        'device_name': 'Work Mac',
      };
      final grant = <String, dynamic>{
        'id': 'grant-1',
        'client_id': 'portal',
        'label': 'Chrome',
        'expires_at': '2026-08-01T00:00:00Z',
      };

      expect(isPhysicalDeviceRecord(physical), isTrue);
      expect(isTrustedDeviceGrant(physical), isFalse);
      expect(isPhysicalDeviceRecord(grant), isFalse);
      expect(isTrustedDeviceGrant(grant), isTrue);
      expect(
        classifyDeviceCollection([physical]),
        PortalDeviceCollectionKind.physical,
      );
      expect(
        classifyDeviceCollection([grant]),
        PortalDeviceCollectionKind.trustedGrants,
      );
      expect(
        classifyDeviceCollection([physical, grant]),
        PortalDeviceCollectionKind.ambiguous,
      );
    });

    test('does not classify an unknown record as a trusted grant', () {
      expect(isTrustedDeviceGrant({'id': 'unknown'}), isFalse);
      expect(
        classifyDeviceCollection([
          {'id': 'unknown'},
        ]),
        PortalDeviceCollectionKind.ambiguous,
      );
    });
  });

  group('enriched session loading', () {
    test('uses enriched sessions without probing the legacy route', () async {
      final paths = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/me') return http.Response('{}', 200);
          if (request.url.path == '/me/sessions/enriched') {
            return http.Response(
              '{"sessions":[{"id":"s1","device_name":"Work Mac"}]}',
              200,
            );
          }
          return http.Response('', 500);
        }),
      );
      await api.login('token');

      final result = await loadPortalSessions(api);

      expect(result.usedLegacyEndpoint, isFalse);
      expect(result.sessions.single['device_name'], 'Work Mac');
      expect(paths, ['/me', '/me/sessions/enriched']);
    });

    for (final fallbackStatus in [404, 501]) {
      test('falls back only for $fallbackStatus from enriched route', () async {
        final paths = <String>[];
        final api = PortalApi(
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path == '/me') return http.Response('{}', 200);
            if (request.url.path == '/me/sessions/enriched') {
              return http.Response('', fallbackStatus);
            }
            if (request.url.path == '/sessions/me') {
              return http.Response('{"sessions":[{"id":"legacy"}]}', 200);
            }
            return http.Response('', 500);
          }),
        );
        await api.login('token');

        final result = await loadPortalSessions(api);

        expect(result.usedLegacyEndpoint, isTrue);
        expect(result.sessions.single['id'], 'legacy');
        expect(paths, ['/me', '/me/sessions/enriched', '/sessions/me']);
      });
    }

    test('does not hide an enriched endpoint server failure', () async {
      final paths = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/me') return http.Response('{}', 200);
          return http.Response('', 500);
        }),
      );
      await api.login('token');

      await expectLater(
        loadPortalSessions(api),
        throwsA(
          isA<PortalApiError>().having((error) => error.status, 'status', 500),
        ),
      );
      expect(paths, ['/me', '/me/sessions/enriched']);
    });
  });
}
