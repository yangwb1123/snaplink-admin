import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'forge_run_observed.dart';
import 'forge_session_runner_receipt_observation.dart';

/// One atomically accepted pair of independently read, content-free Run and
/// Runner-receipt observations.
///
/// This value only validates and retains metadata. It does not authenticate
/// the owner, persist a receipt, reserve a target, dispatch, or execute work.
class ForgeRunReceiptObservationConvergence {
  final ForgeRunObserved runObserved;
  final ForgeSessionRunnerReceiptObservation receiptObserved;

  const ForgeRunReceiptObservationConvergence._({
    required this.runObserved,
    required this.receiptObserved,
  });

  factory ForgeRunReceiptObservationConvergence.fromObservations({
    required ForgeRunObserved runObserved,
    required ForgeSessionRunnerReceiptObservation receiptObserved,
    required String conversationID,
    required String runID,
    required String promptID,
    required int runCreatedAtMS,
    required int runLatestSequence,
    required String runStatus,
  }) {
    final run = ForgeRunObserved.fromJson(runObserved.toJson());
    final receipt = ForgeSessionRunnerReceiptObservation.fromJson(
      receiptObserved.toJson(),
    );
    final terminal = receipt.receiptObservation;
    if (!run.isDisplayOnly ||
        !receipt.isDisplayOnly ||
        !run.isFor(conversationID, runID) ||
        !receipt.isFor(conversationID, runID) ||
        run.promptID != promptID ||
        receipt.promptID != promptID ||
        run.createdAtMS != runCreatedAtMS ||
        run.latestSequence != runLatestSequence ||
        run.status != runStatus ||
        run.ownerRef != _ownerReference(receipt) ||
        terminal.attemptID.isEmpty ||
        terminal.commandID.isEmpty ||
        terminal.targetID.isEmpty ||
        terminal.commandSHA256.length != 64 ||
        terminal.dispositionKind.isEmpty ||
        terminal.observedAtMS < 0 ||
        terminal.uncertain != terminal.reconciliationRequired) {
      throw const FormatException(
        'Run and session Runner receipt observations did not converge.',
      );
    }
    return ForgeRunReceiptObservationConvergence._(
      runObserved: run,
      receiptObserved: receipt,
    );
  }

  /// Canonical metadata fingerprint containing every binding in the pair.
  String get metadataFingerprint => jsonEncode({
    'owner_ref': runObserved.ownerRef,
    'conversation_id': runObserved.conversationID,
    'prompt_id': runObserved.promptID,
    'run_id': runObserved.runID,
    'run_created_at_ms': runObserved.createdAtMS,
    'run_latest_sequence': runObserved.latestSequence,
    'run_status': runObserved.status,
    'attempt_id': receiptObserved.receiptObservation.attemptID,
    'command_id': receiptObserved.receiptObservation.commandID,
    'target_id': receiptObserved.receiptObservation.targetID,
    'command_sha256': receiptObserved.receiptObservation.commandSHA256,
    'disposition_kind': receiptObserved.receiptObservation.dispositionKind,
    'receipt_observed_at_ms': receiptObserved.receiptObservation.observedAtMS,
    'uncertain': receiptObserved.receiptObservation.uncertain,
    'reconciliation_required':
        receiptObserved.receiptObservation.reconciliationRequired,
  });
}

String _ownerReference(ForgeSessionRunnerReceiptObservation receipt) {
  final bytes = BytesBuilder(copy: false)
    ..add(utf8.encode('forge.run.observed.v1/owner\u0000'));
  for (final value in <String>[
    receipt.owner.issuer,
    receipt.owner.subject,
    receipt.owner.tenantID,
  ]) {
    final encoded = utf8.encode(value);
    final length = ByteData(8)..setUint64(0, encoded.length, Endian.big);
    bytes
      ..add(length.buffer.asUint8List())
      ..add(encoded);
  }
  return crypto.sha256.convert(bytes.takeBytes()).toString();
}
