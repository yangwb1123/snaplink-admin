import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform.environment['FORGE_EXECUTION_CONSENT_E2E_INPUT'];

  test(
    'Flutter reads the authenticated execution-consent preview candidate',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final conversationID = input['conversation_id'];
      if (apiURL is! String ||
          accessToken is! String ||
          conversationID is! String) {
        throw const FormatException(
          'Invalid Forge execution-consent E2E input.',
        );
      }

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
      );
      try {
        final preview = await api.getExecutionConsentPreview(
          conversationID: conversationID,
        );
        expect(preview.conversationID, conversationID);
        _expectOptionalString(input, 'expected_project_id', preview.projectID);
        _expectOptionalString(input, 'expected_profile_id', preview.profileID);
        _expectOptionalString(
          input,
          'expected_profile_sha256',
          preview.profileSHA256,
        );
        final expectedTTL = input['expected_maximum_ttl_ms'];
        if (expectedTTL != null) {
          if (expectedTTL is! int) {
            throw const FormatException(
              'Invalid expected_maximum_ttl_ms in E2E input.',
            );
          }
          expect(preview.maximumTTLMS, expectedTTL);
        }
      } finally {
        api.close();
      }
    },
    skip: inputPath == null || inputPath.isEmpty
        ? 'Set FORGE_EXECUTION_CONSENT_E2E_INPUT to a live-test JSON file.'
        : false,
  );
}

void _expectOptionalString(
  Map<String, dynamic> input,
  String key,
  String actual,
) {
  final expected = input[key];
  if (expected == null) return;
  if (expected is! String) {
    throw FormatException('Invalid $key in E2E input.');
  }
  expect(actual, expected);
}
