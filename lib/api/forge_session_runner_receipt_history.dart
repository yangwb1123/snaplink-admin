import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';
import 'forge_session_runner_receipt_observation.dart';

/// Bounded, ordered, display-only history for one session Run's Runner
/// receipt observations. Importing this value never polls Forge, persists a
/// receipt, selects a target, authorizes execution, or retries an uncertain
/// command.
const forgeSessionRunnerReceiptHistorySchema =
    'forge.session-runner-receipt-history/v1';
const forgeSessionRunnerReceiptHistoryEvaluationMode =
    'pure_session_runner_receipt_history_only';
const forgeSessionRunnerReceiptHistoryMaxBytes = 2 * 1024 * 1024;
// Keep the client bound identical to Core/Runtime's canonical value. A
// consumer must never accept a longer history than the producer contract.
const forgeSessionRunnerReceiptHistoryMaxReceipts = 16;

typedef ForgeSessionRunnerReceiptHistoryFileReader = Future<String?> Function();

class ForgeSessionRunnerReceiptHistory {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String promptID;
  final String runID;
  final List<ForgeSessionRunnerReceiptObservation> receipts;
  final int attemptCount;
  final String latestAttemptID;
  final String latestCommandID;
  final String latestTargetID;
  final String latestDispositionKind;
  final int latestObservedAtMS;
  final bool reconciliationRequired;
  final bool manualReviewRequired;
  final bool automaticRetry;
  final String followUp;
  final String? selectedTargetID;
  final bool previewOnly;
  final ForgeSessionRunnerReceiptObservationAuthority authority;

  const ForgeSessionRunnerReceiptHistory({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.promptID,
    required this.runID,
    required this.receipts,
    required this.attemptCount,
    required this.latestAttemptID,
    required this.latestCommandID,
    required this.latestTargetID,
    required this.latestDispositionKind,
    required this.latestObservedAtMS,
    required this.reconciliationRequired,
    required this.manualReviewRequired,
    required this.automaticRetry,
    required this.followUp,
    required this.selectedTargetID,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeSessionRunnerReceiptHistory.fromJsonText(String source) {
    if (source.isEmpty ||
        source.length > forgeSessionRunnerReceiptHistoryMaxBytes) {
      throw const FormatException(
        'Session Runner receipt history exceeds the size limit.',
      );
    }
    rejectDuplicateForgeJsonKeys(source);
    return ForgeSessionRunnerReceiptHistory.fromJson(jsonDecode(source));
  }

  factory ForgeSessionRunnerReceiptHistory.fromJson(Object? value) {
    final json = _historyObject(value, 'root');
    _historyExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'prompt_id',
      'run_id',
      'receipts',
      'attempt_count',
      'latest_attempt_id',
      'latest_command_id',
      'latest_target_id',
      'latest_disposition_kind',
      'latest_observed_at_ms',
      'reconciliation_required',
      'manual_review_required',
      'automatic_retry',
      'follow_up',
      'selected_target_id',
      'preview_only',
      'authority',
    });

    final receiptsValue = json['receipts'];
    if (receiptsValue is! List ||
        receiptsValue.isEmpty ||
        receiptsValue.length > forgeSessionRunnerReceiptHistoryMaxReceipts) {
      throw const FormatException(
        'Session Runner receipt history has an invalid bounded receipt list.',
      );
    }
    final receipts = receiptsValue
        .map(ForgeSessionRunnerReceiptObservation.fromJson)
        .toList(growable: false);
    final history = ForgeSessionRunnerReceiptHistory(
      schemaVersion: _historySchema(json['schema_version']),
      evaluationMode: _historyMode(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _historyIdentifier(json['conversation_id']),
      promptID: _historyIdentifier(json['prompt_id']),
      runID: _historyIdentifier(json['run_id']),
      receipts: List.unmodifiable(receipts),
      attemptCount: _historyPositiveInt(json['attempt_count']),
      latestAttemptID: _historyIdentifier(json['latest_attempt_id']),
      latestCommandID: _historyIdentifier(json['latest_command_id']),
      latestTargetID: _historyIdentifier(json['latest_target_id']),
      latestDispositionKind: _historyDisposition(
        json['latest_disposition_kind'],
      ),
      latestObservedAtMS: _historySafeInt(json['latest_observed_at_ms']),
      reconciliationRequired: _historyBool(json['reconciliation_required']),
      manualReviewRequired: _historyBool(json['manual_review_required']),
      automaticRetry: _historyBool(json['automatic_retry']),
      followUp: _historyFollowUp(json['follow_up']),
      selectedTargetID: _historyNullableIdentifier(json['selected_target_id']),
      previewOnly: _historyBool(json['preview_only']),
      authority: ForgeSessionRunnerReceiptObservationAuthority.fromJson(
        json['authority'],
      ),
    );
    history._validate();
    return history;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'prompt_id': promptID,
    'run_id': runID,
    'receipts': receipts
        .map((receipt) => receipt.toJson())
        .toList(growable: false),
    'attempt_count': attemptCount,
    'latest_attempt_id': latestAttemptID,
    'latest_command_id': latestCommandID,
    'latest_target_id': latestTargetID,
    'latest_disposition_kind': latestDispositionKind,
    'latest_observed_at_ms': latestObservedAtMS,
    'reconciliation_required': reconciliationRequired,
    'manual_review_required': manualReviewRequired,
    'automatic_retry': automaticRetry,
    'follow_up': followUp,
    'selected_target_id': selectedTargetID,
    'preview_only': previewOnly,
    'authority': authority.toJson(),
  };

  bool get isDisplayOnly =>
      schemaVersion == forgeSessionRunnerReceiptHistorySchema &&
      evaluationMode == forgeSessionRunnerReceiptHistoryEvaluationMode &&
      receipts.isNotEmpty &&
      receipts.length <= forgeSessionRunnerReceiptHistoryMaxReceipts &&
      authority.isOffline &&
      previewOnly &&
      selectedTargetID == null &&
      automaticRetry == false;

  bool get hasUncertainTerminal =>
      receipts.last.receiptObservation.dispositionKind == 'uncertain';

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  void _validate() {
    if (!isDisplayOnly || attemptCount != receipts.length) {
      throw const FormatException(
        'Session Runner receipt history is not display-only or count-bound.',
      );
    }

    final attemptIDs = <String>{};
    var previousObservedAtMS = -1;
    String? previousAttemptID;
    String? previousDisposition;
    for (final receipt in receipts) {
      if (!receipt.isDisplayOnly ||
          receipt.owner != owner ||
          !receipt.isFor(conversationID, runID) ||
          receipt.promptID != promptID ||
          !attemptIDs.add(receipt.receiptObservation.attemptID) ||
          receipt.receiptObservation.observedAtMS < previousObservedAtMS ||
          (receipt.receiptObservation.observedAtMS == previousObservedAtMS &&
              previousAttemptID != null &&
              previousAttemptID.compareTo(
                    receipt.receiptObservation.attemptID,
                  ) >=
                  0)) {
        throw const FormatException(
          'Session Runner receipt history is not owner-bound and ordered.',
        );
      }
      final disposition = receipt.receiptObservation.dispositionKind;
      // An uncertain result is terminal evidence requiring reconciliation. A
      // later receipt cannot silently turn it into a retry or a new attempt.
      if (previousDisposition == 'completed' ||
          previousDisposition == 'uncertain' ||
          (disposition == 'uncertain' &&
              previousDisposition != null &&
              previousDisposition != 'failed')) {
        throw const FormatException(
          'Session Runner receipt history has an invalid uncertain transition.',
        );
      }
      previousDisposition = disposition;
      previousObservedAtMS = receipt.receiptObservation.observedAtMS;
      previousAttemptID = receipt.receiptObservation.attemptID;
    }

    final latest = receipts.last.receiptObservation;
    if (latestAttemptID != latest.attemptID ||
        latestCommandID != latest.commandID ||
        latestTargetID != latest.targetID ||
        latestDispositionKind != latest.dispositionKind ||
        latestObservedAtMS != latest.observedAtMS ||
        reconciliationRequired != latest.reconciliationRequired ||
        manualReviewRequired != latest.manualReviewRequired ||
        automaticRetry != latest.automaticRetry ||
        followUp != latest.followUp ||
        latest.uncertain != reconciliationRequired ||
        latest.uncertain != manualReviewRequired ||
        (latest.uncertain && latestDispositionKind != 'uncertain') ||
        (!latest.uncertain && latestDispositionKind == 'uncertain')) {
      throw const FormatException(
        'Session Runner receipt history summary drifted from its latest receipt.',
      );
    }
  }
}

Map<String, dynamic> _historyObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Expected session Runner receipt history $label object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _historyExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException(
      'Unknown or missing session Runner receipt history field.',
    );
  }
}

String _historySchema(Object? value) {
  if (value != forgeSessionRunnerReceiptHistorySchema) {
    throw const FormatException(
      'Invalid session Runner receipt history schema.',
    );
  }
  return forgeSessionRunnerReceiptHistorySchema;
}

String _historyMode(Object? value) {
  if (value != forgeSessionRunnerReceiptHistoryEvaluationMode) {
    throw const FormatException('Invalid session Runner receipt history mode.');
  }
  return forgeSessionRunnerReceiptHistoryEvaluationMode;
}

String _historyIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_historyToken(value)) {
    throw const FormatException(
      'Invalid session Runner receipt history identifier.',
    );
  }
  return value;
}

String? _historyNullableIdentifier(Object? value) {
  if (value == null) return null;
  return _historyIdentifier(value);
}

bool _historyToken(String value) {
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    final alphaNumeric =
        (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a);
    if (!alphaNumeric &&
        !(code == 0x2e ||
            code == 0x5f ||
            code == 0x3a ||
            code == 0x2b ||
            code == 0x2f ||
            code == 0x2d)) {
      return false;
    }
  }
  return true;
}

int _historySafeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeSessionRunnerReceiptObservationMaxSafeInteger) {
    throw const FormatException(
      'Invalid session Runner receipt history integer.',
    );
  }
  return value;
}

int _historyPositiveInt(Object? value) {
  final parsed = _historySafeInt(value);
  if (parsed == 0 || parsed > forgeSessionRunnerReceiptHistoryMaxReceipts) {
    throw const FormatException(
      'Invalid session Runner receipt history count.',
    );
  }
  return parsed;
}

bool _historyBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Invalid session Runner receipt history boolean.',
    );
  }
  return value;
}

String _historyDisposition(Object? value) {
  if (value is! String ||
      !const {'completed', 'failed', 'uncertain'}.contains(value)) {
    throw const FormatException(
      'Invalid session Runner receipt history disposition.',
    );
  }
  return value;
}

String _historyFollowUp(Object? value) {
  if (value is! String ||
      !const {'none', 'reconciliation_manual'}.contains(value)) {
    throw const FormatException(
      'Invalid session Runner receipt history follow-up.',
    );
  }
  return value;
}
