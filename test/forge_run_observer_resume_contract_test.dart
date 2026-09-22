import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_RUN_RESUME_CONTRACT_FIXTURE'];

  test(
    'accepts the shared read-only Run observer resume fixture',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      expect(root.keys.toSet(), {
        'api_version',
        'conversation_id',
        'run_id',
        'limit',
        'pages',
        'expected_sequences',
      });
      expect(root['api_version'], 'forgeos.run-observer-resume-contract/v1');
      final conversationID = root['conversation_id'] as String;
      final runID = root['run_id'] as String;
      final limit = root['limit'] as int;
      final pages = root['pages'] as List;
      var afterSequence = 0;
      final sequences = <int>[];
      for (final raw in pages) {
        final page = ForgeRunTimelinePage.fromJson(
          Map<String, dynamic>.from(raw as Map),
          requestedConversationID: conversationID,
          requestedRunID: runID,
          requestedAfterSequence: afterSequence,
          limit: limit,
        );
        sequences.addAll(page.events.map((event) => event.sequence));
        afterSequence = page.scannedThroughSequence;
      }
      expect(sequences, root['expected_sequences']);
      expect(afterSequence, 5);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
