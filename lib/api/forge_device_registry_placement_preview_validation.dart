part of 'forge_device_registry_placement_preview.dart';

List<ForgeDeviceRegistryPlacementDecision> _registryPlacementDecisions(
  Object? value,
) {
  if (value is! List ||
      value.length > forgeDeviceRegistryPlacementPreviewMaxDecisions) {
    throw const FormatException('Invalid Forge registry placement decisions.');
  }
  final decisions = value
      .map(ForgeDeviceRegistryPlacementDecision.fromJson)
      .toList(growable: false);
  final pairs = <String>{};
  for (var index = 0; index < decisions.length; index++) {
    final decision = decisions[index];
    if (!pairs.add('${decision.deviceID}\u0000${decision.instanceID}')) {
      throw const FormatException(
        'Forge registry placement decisions repeat a candidate.',
      );
    }
    if (index > 0) {
      final previous = decisions[index - 1];
      final deviceOrder = _registryPlacementCompare(
        previous.deviceID,
        decision.deviceID,
      );
      if (deviceOrder > 0 ||
          (deviceOrder == 0 &&
              _registryPlacementCompare(
                    previous.instanceID,
                    decision.instanceID,
                  ) >=
                  0)) {
        throw const FormatException(
          'Forge registry placement decisions are unsorted.',
        );
      }
    }
  }
  return decisions;
}

Map<String, dynamic> _registryPlacementObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge registry placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _registryPlacementExactKeys(
  Map<String, dynamic> value,
  Set<String> expected,
) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge registry placement fields.');
  }
}

int _registryPlacementSafePositiveInt(Object? value) {
  final parsed = _registryPlacementSafeNonNegativeInt(value);
  if (parsed <= 0) {
    throw const FormatException('Invalid Forge registry placement integer.');
  }
  return parsed;
}

int _registryPlacementSafeNonNegativeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > _forgeDeviceRegistryPlacementPreviewMaxSafeInteger) {
    throw const FormatException('Invalid Forge registry placement integer.');
  }
  return value;
}

int _registryPlacementBoundedInt(Object? value, int maximum) {
  final parsed = _registryPlacementSafeNonNegativeInt(value);
  if (parsed > maximum) {
    throw const FormatException('Invalid Forge registry placement count.');
  }
  return parsed;
}

String _registryPlacementIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_registryPlacementASCIIIdentifier(value)) {
    throw const FormatException('Invalid Forge registry placement identifier.');
  }
  return value;
}

bool _registryPlacementASCIIIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2d;
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

List<String> _registryPlacementReasons(Object? value) {
  if (value is! List || value.length > 64) {
    throw const FormatException('Invalid Forge registry placement reasons.');
  }
  final reasons = <String>[];
  for (final item in value) {
    if (item is! String || item.isEmpty || item.length > 128) {
      throw const FormatException('Invalid Forge registry placement reason.');
    }
    if (item.runes.any(
      (rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f),
    )) {
      throw const FormatException('Invalid Forge registry placement reason.');
    }
    reasons.add(item);
  }
  for (var index = 1; index < reasons.length; index++) {
    if (_registryPlacementCompare(reasons[index - 1], reasons[index]) >= 0) {
      throw const FormatException(
        'Forge registry placement reasons are unsorted.',
      );
    }
  }
  return reasons;
}

int _registryPlacementCompare(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
