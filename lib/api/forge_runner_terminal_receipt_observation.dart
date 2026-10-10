part of 'forge_runner_terminal_receipt.dart';

/// Validates a terminal receipt against the exact command and current lease.
///
/// This is a read-only value operation. It deliberately does not adopt the
/// lease, record the receipt, or retry an uncertain command.
ForgeRunnerTerminalReceiptObservation observeForgeRunnerTerminalReceipt(
  ForgeRunnerTerminalReceiptRequest request,
) {
  _validateCommand(request.command);
  _validateGrant(request.grant);
  _validateReceipt(request.receipt);

  final receipt = request.receipt;
  final command = request.command;
  if (receipt.version != forgeRunnerTerminalReceiptABI) {
    throw const ForgeRunnerTerminalReceiptError('unsupported_receipt_version');
  }
  if (receipt.commandID != command.commandID) {
    throw const ForgeRunnerTerminalReceiptError('command_mismatch');
  }
  if (receipt.commandSHA256 != command.commandSHA256()) {
    throw const ForgeRunnerTerminalReceiptError('command_digest_mismatch');
  }
  if (!_sameProof(receipt.proof, command.leaseProof)) {
    throw const ForgeRunnerTerminalReceiptError('proof_mismatch');
  }
  if (!_sameProof(receipt.proof, request.grant.proof)) {
    throw const ForgeRunnerTerminalReceiptError('lease_mismatch');
  }
  if (receipt.observedAtMS < request.grant.issuedAtMS ||
      receipt.observedAtMS >= request.grant.expiresAtMS) {
    throw const ForgeRunnerTerminalReceiptError('lease_expired');
  }

  final uncertain = receipt.disposition.isUncertain;
  return ForgeRunnerTerminalReceiptObservation(
    schemaVersion: forgeRunnerTerminalReceiptSchema,
    evaluationMode: forgeRunnerTerminalReceiptEvaluationMode,
    commandID: receipt.commandID,
    commandSHA256: receipt.commandSHA256,
    attemptID: receipt.proof.attemptID,
    targetID: receipt.proof.targetID,
    dispositionKind: receipt.disposition.kind,
    observedAtMS: receipt.observedAtMS,
    receiptValid: true,
    previewOnly: true,
    uncertain: uncertain,
    reconciliationRequired: uncertain,
    manualReviewRequired: uncertain,
    automaticRetry: false,
    followUp: uncertain ? 'reconciliation_manual' : 'none',
    authority: const ForgeRunnerTerminalReceiptAuthority.offline(),
  );
}
