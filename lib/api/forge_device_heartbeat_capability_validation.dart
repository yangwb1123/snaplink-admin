part of 'forge_device_heartbeat.dart';

const _forgeHeartbeatMaxCPUCoreCount = 4096;
final _forgeHeartbeatMaxCapabilityBytes = BigInt.one << 60;
const _forgeHeartbeatMaxGPUCount = 32;
const _forgeHeartbeatMaxRuntimeCount = 64;
const _forgeHeartbeatMaxRuntimeNameBytes = 64;

BigInt _heartbeatReferenceCPUCoreCount(Object? value) {
  final number = _heartbeatReferenceUint64(value);
  if (number == BigInt.zero ||
      number > BigInt.from(_forgeHeartbeatMaxCPUCoreCount)) {
    throw const FormatException('Invalid Forge heartbeat CPU core count.');
  }
  return number;
}

BigInt _heartbeatReferenceCapabilityBytes(
  Object? value, {
  required bool requireNonzero,
}) {
  final number = _heartbeatReferenceUint64(value);
  if (number > _forgeHeartbeatMaxCapabilityBytes ||
      (requireNonzero && number == BigInt.zero)) {
    throw const FormatException('Invalid Forge heartbeat capability capacity.');
  }
  return number;
}

String _heartbeatReferenceTag(Object? value) {
  final text = _heartbeatReferenceText(value);
  if (text.length > _forgeHeartbeatMaxRuntimeNameBytes ||
      text.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) ||
                (code >= 0x41 && code <= 0x5a) ||
                (code >= 0x61 && code <= 0x7a) ||
                code == 0x2e ||
                code == 0x5f ||
                code == 0x2d ||
                code == 0x2b),
      )) {
    throw const FormatException('Invalid Forge heartbeat capability tag.');
  }
  return text.toLowerCase();
}

String _heartbeatReferenceLabel(Object? value) {
  if (value is! String) {
    throw const FormatException('Invalid Forge heartbeat capability label.');
  }
  final text = value.trim();
  if (text.isEmpty ||
      utf8.encode(text).length > _forgeHeartbeatMaxRuntimeNameBytes ||
      text.codeUnits.any(
        (code) => (code <= 0x1f) || (code >= 0x7f && code <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge heartbeat capability label.');
  }
  return text;
}

bool _hasDuplicateStrings(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (values[index - 1] == values[index]) return true;
  }
  return false;
}
