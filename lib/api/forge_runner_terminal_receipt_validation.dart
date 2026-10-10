part of 'forge_runner_terminal_receipt.dart';

String _terminalSchema(Object? value) {
  if (value != forgeRunnerTerminalReceiptSchema) {
    throw const FormatException('Invalid Runner terminal receipt schema.');
  }
  return forgeRunnerTerminalReceiptSchema;
}

String _terminalMode(Object? value) {
  if (value != forgeRunnerTerminalReceiptEvaluationMode) {
    throw const FormatException('Invalid Runner terminal receipt mode.');
  }
  return forgeRunnerTerminalReceiptEvaluationMode;
}

String _terminalCommandIDValue(Object? value) {
  if (value is! String || !_terminalCommandID(value)) {
    throw const FormatException('Invalid Runner terminal command ID.');
  }
  return value;
}

String _terminalDigestValue(Object? value) {
  if (value is! String || !_terminalDigest(value)) {
    throw const FormatException('Invalid Runner terminal digest.');
  }
  return value;
}

String _terminalLeaseIdentityValue(Object? value) {
  if (value is! String || !_terminalLeaseIdentity(value)) {
    throw const FormatException('Invalid Runner terminal lease identity.');
  }
  return value;
}

String _terminalDispositionValue(Object? value) {
  if (value is! String ||
      !const {'completed', 'failed', 'uncertain'}.contains(value)) {
    throw const FormatException('Invalid Runner terminal disposition.');
  }
  return value;
}

int _terminalUint64Value(Object? value) {
  if (value is int && _terminalUint64(value)) {
    return value;
  }
  // Some Flutter Web JSON paths materialize integral JSON numbers as `double`.
  // Accept only an exactly integral, finite value that remains within the
  // platform-safe bound; fractional or rounded values still fail closed.
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    final coerced = value.toInt();
    if (_terminalUint64(coerced) && coerced.toDouble() == value.toDouble()) {
      return coerced;
    }
  }
  throw const FormatException('Invalid Runner terminal observation time.');
}

String _terminalFollowUpValue(Object? value) {
  if (value is! String ||
      !const {'none', 'reconciliation_manual'}.contains(value)) {
    throw const FormatException('Invalid Runner terminal follow-up.');
  }
  return value;
}

void _validateCommand(ForgeRunnerExecutionCommand command) {
  if (command.version != forgeRunnerTerminalReceiptABI ||
      !_terminalCommandID(command.commandID) ||
      !_terminalLeaseProof(command.leaseProof) ||
      !_terminalTextBounded(command.idempotencyKey, 256, trimmed: true) ||
      !_terminalTextBounded(command.workspaceRef, 256, trimmed: true) ||
      command.argv.isEmpty ||
      command.argv.length > 64 ||
      command.timeoutMS < 1 ||
      command.timeoutMS > forgeRunnerTerminalReceiptMaxLeaseTTLMS ||
      command.maxOutputBytes < 1 ||
      command.maxOutputBytes > 8 * 1024 * 1024 ||
      !_terminalArguments(command.argv)) {
    throw const ForgeRunnerTerminalReceiptError('invalid_command');
  }
}

void _validateGrant(ForgeRunnerTerminalReceiptGrant grant) {
  if (grant.version != forgeRunnerTerminalReceiptABI ||
      !_terminalLeaseIdentity(grant.attemptID) ||
      !_terminalLeaseIdentity(grant.targetID) ||
      grant.epoch <= 0 ||
      !_terminalLeaseToken(grant.fencingToken) ||
      !_terminalUint64(grant.issuedAtMS) ||
      !_terminalUint64(grant.expiresAtMS) ||
      grant.expiresAtMS <= grant.issuedAtMS ||
      grant.expiresAtMS - grant.issuedAtMS <
          forgeRunnerTerminalReceiptMinLeaseTTLMS ||
      grant.expiresAtMS - grant.issuedAtMS >
          forgeRunnerTerminalReceiptMaxLeaseTTLMS) {
    throw const ForgeRunnerTerminalReceiptError('invalid_grant');
  }
}

void _validateReceipt(ForgeRunnerTerminalReceipt receipt) {
  if (receipt.version != forgeRunnerTerminalReceiptABI ||
      !_terminalCommandID(receipt.commandID) ||
      !_terminalDigest(receipt.commandSHA256) ||
      !_terminalLeaseProof(receipt.proof) ||
      !_terminalUint64(receipt.observedAtMS)) {
    throw const ForgeRunnerTerminalReceiptError('invalid_receipt');
  }
  final disposition = receipt.disposition;
  if (disposition.kind == 'completed') {
    if (disposition.receiptSHA256 == null ||
        !_terminalDigest(disposition.receiptSHA256!)) {
      throw const ForgeRunnerTerminalReceiptError('invalid_disposition');
    }
  } else if (disposition.kind == 'failed' || disposition.isUncertain) {
    if (disposition.reason == null || !_terminalReason(disposition.reason!)) {
      throw const ForgeRunnerTerminalReceiptError('invalid_disposition');
    }
  } else {
    throw const ForgeRunnerTerminalReceiptError('invalid_disposition');
  }
}

bool _terminalArguments(List<String> arguments) {
  var totalBytes = 0;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    final bytes = utf8.encode(argument).length;
    if (!_terminalTextBounded(argument, 4096, allowEmpty: index != 0) ||
        totalBytes > 65536 - bytes) {
      return false;
    }
    totalBytes += bytes;
  }
  return true;
}

bool _terminalLeaseProof(ForgeRunnerExecutionLeaseProof proof) =>
    _terminalLeaseIdentity(proof.attemptID) &&
    _terminalLeaseIdentity(proof.targetID) &&
    proof.epoch > 0 &&
    _terminalLeaseToken(proof.fencingToken);

bool _sameProof(
  ForgeRunnerExecutionLeaseProof left,
  ForgeRunnerExecutionLeaseProof right,
) =>
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken;

bool _terminalCommandID(String value) =>
    _terminalTextBounded(value, 128, trimmed: true);

bool _terminalLeaseIdentity(String value) => _terminalLeaseText(value, 128);

bool _terminalLeaseToken(String value) => _terminalLeaseText(value, 256);

bool _terminalReason(String value) =>
    value.isNotEmpty &&
    _terminalWellFormedUnicode(value) &&
    utf8.encode(value).length <= forgeRunnerTerminalReceiptMaxReasonBytes &&
    !value.contains('\u0000');

bool _terminalLeaseText(String value, int maxBytes) =>
    value.isNotEmpty &&
    _terminalWellFormedUnicode(value) &&
    utf8.encode(value).length <= maxBytes &&
    value.trim() == value &&
    !value.contains('\u0000') &&
    !value.contains('\r') &&
    !value.contains('\n');

bool _terminalDigest(String value) =>
    value.length == 64 &&
    value.codeUnits.every(
      (code) =>
          (code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66),
    );

bool _terminalUint64(int value) =>
    value >= 0 && value <= forgeRunnerTerminalReceiptMaxRepresentableInteger;

bool _terminalTextBounded(
  String value,
  int maxBytes, {
  bool allowEmpty = false,
  bool trimmed = false,
  bool rejectCRLF = false,
}) {
  if ((!allowEmpty && value.isEmpty) ||
      !_terminalWellFormedUnicode(value) ||
      utf8.encode(value).length > maxBytes ||
      (trimmed && value.trim() != value)) {
    return false;
  }
  return value.codeUnits.every(
    (unit) =>
        unit > 0x1f &&
        !(unit >= 0x7f && unit <= 0x9f) &&
        (!rejectCRLF || (unit != 0x0a && unit != 0x0d)),
  );
}

/// Dart strings can contain an isolated UTF-16 surrogate even though JSON
/// and the Go/Rust ABI require well-formed Unicode scalar sequences. Reject
/// those code units before [utf8.encode], which otherwise replaces them and
/// could make an invalid value appear bounded and valid.
bool _terminalWellFormedUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= (0xdb00 + 0xff)) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(index + 1);
      if (next < 0xdc00 || next > 0xdfff) return false;
      index++;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

Map<String, dynamic> _terminalObject(Object? value) {
  if (value is! Map) throw const FormatException('Expected Runner object.');
  return Map<String, dynamic>.from(value);
}

void _terminalExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Runner terminal fields.');
  }
}

String _terminalText(Object? value) {
  if (value is! String) throw const FormatException('Expected Runner text.');
  return value;
}

int _terminalInt(Object? value) {
  if (value is! int) throw const FormatException('Expected Runner integer.');
  return value;
}

bool _terminalBool(Object? value) {
  if (value is! bool) throw const FormatException('Expected Runner boolean.');
  return value;
}
