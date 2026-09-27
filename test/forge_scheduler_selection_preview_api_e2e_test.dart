import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';

/// Lets this opt-in test call the authenticated Forge server instead of the
/// test binding's synthetic HTTP client.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_SCHEDULER_SELECTION_PREVIEW_E2E_INPUT'];

  test(
    'Console Web App and Mobile clients consume the accepted scheduler preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final clientKinds = _requiredTextList(input, 'client_kinds');
      final request = ForgeSchedulerSelectionPreviewRequest.fromJson(
        input['request'],
      );
      final expectedConversationID = _requiredText(
        input,
        'expected_conversation_id',
      );
      final expectedRunID = _requiredText(input, 'expected_run_id');
      final expectedAttemptID = _requiredText(input, 'expected_attempt_id');
      final expectedSelectionAvailable = _requiredBool(
        input,
        'expected_selection_available',
      );
      final expectedSelectionReason = _requiredText(
        input,
        'expected_selection_reason',
      );
      final expectedDeviceID = _optionalText(input, 'expected_device_id');
      final expectedInstanceID = _optionalText(input, 'expected_instance_id');
      if (!request.isFor(expectedConversationID, expectedRunID) ||
          request.attemptID != expectedAttemptID) {
        throw const FormatException(
          'Scheduler preview input has inconsistent Run binding.',
        );
      }

      expect(clientKinds, ['web', 'app', 'mobile']);
      for (final clientKind in clientKinds) {
        final api = ForgeConversationsApi(
          baseUrl: apiURL,
          accessToken: accessToken,
          timeout: const Duration(seconds: 5),
        );
        try {
          final preview = await api.previewSchedulerSelection(
            request: request,
            candidateOrigin: apiURL,
          );
          expect(preview.owner, owner, reason: clientKind);
          expect(
            preview.isFor(expectedConversationID, expectedRunID),
            isTrue,
            reason: clientKind,
          );
          expect(preview.attemptID, expectedAttemptID, reason: clientKind);
          expect(preview.previewOnly, isTrue, reason: clientKind);
          expect(
            preview.selectionAvailable,
            expectedSelectionAvailable,
            reason: clientKind,
          );
          expect(
            preview.selectionReason,
            expectedSelectionReason,
            reason: clientKind,
          );
          if (expectedSelectionAvailable) {
            expect(
              preview.selectedDeviceID,
              expectedDeviceID,
              reason: clientKind,
            );
            expect(
              preview.selectedInstanceID,
              expectedInstanceID,
              reason: clientKind,
            );
            expect(
              preview.eligibleCandidateCount,
              greaterThan(0),
              reason: clientKind,
            );
          } else {
            expect(preview.selectedDeviceID, isNull, reason: clientKind);
            expect(preview.selectedInstanceID, isNull, reason: clientKind);
            expect(preview.eligibleCandidateCount, 0, reason: clientKind);
          }
          expect(
            preview.candidateCount,
            greaterThanOrEqualTo(1),
            reason: clientKind,
          );
          expect(preview.authority.anyGranted, isFalse, reason: clientKind);
        } finally {
          api.close();
        }
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE + P4 Console harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge scheduler selection preview E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(
      'Missing Forge scheduler selection preview E2E $key.',
    );
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! bool) {
    throw FormatException(
      'Missing Forge scheduler selection preview E2E $key.',
    );
  }
  return value;
}

String? _optionalText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value == null || value == '') return null;
  if (value is! String) {
    throw FormatException(
      'Invalid Forge scheduler selection preview E2E $key.',
    );
  }
  return value;
}

List<String> _requiredTextList(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! List ||
      value.isEmpty ||
      value.any((item) => item is! String || item.isEmpty)) {
    throw FormatException(
      'Missing Forge scheduler selection preview E2E $key.',
    );
  }
  return value.cast<String>();
}
