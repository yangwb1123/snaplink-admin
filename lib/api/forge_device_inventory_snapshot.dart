import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'forge_device_inventory_declaration.dart';

const forgeDeviceInventorySnapshotCanonicalDomain =
    'forge.device-inventory-snapshot-canonical/v1';
const forgeDeviceInventorySnapshotMaxRows = 128;
const _snapshotMaxSafeInteger = 9007199254740991;

/// A caller-declared owner-scoped inventory snapshot. It is a pure value and
/// carries no authenticated identity, persistence, or execution authority.
class ForgeDeviceInventorySnapshot {
  final String snapshotID;
  final int observedAtMS;
  final ForgeDeviceOwner owner;
  final List<ForgeDeviceInventorySnapshotRow> rows;

  const ForgeDeviceInventorySnapshot({
    required this.snapshotID,
    required this.observedAtMS,
    required this.owner,
    required this.rows,
  });

  factory ForgeDeviceInventorySnapshot.fromJson(Object? value) {
    final json = _snapshotObject(value);
    _snapshotExactKeys(json, {
      'snapshot_id',
      'observed_at_ms',
      'owner',
      'rows',
    });
    final rawRows = json['rows'];
    if (rawRows is! List ||
        rawRows.length > forgeDeviceInventorySnapshotMaxRows) {
      throw const ForgeDeviceInventorySnapshotError('too_many_rows');
    }
    return ForgeDeviceInventorySnapshot(
      snapshotID: _snapshotText(json['snapshot_id']),
      observedAtMS: _snapshotInteger(json['observed_at_ms']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      rows: rawRows
          .map((row) => ForgeDeviceInventorySnapshotRow.fromJson(row))
          .toList(growable: false),
    );
  }
}

class ForgeDeviceInventorySnapshotRow {
  final String deviceID;
  final String instanceID;
  final ForgeDeviceOwner owner;

  const ForgeDeviceInventorySnapshotRow({
    required this.deviceID,
    required this.instanceID,
    required this.owner,
  });

  factory ForgeDeviceInventorySnapshotRow.fromJson(Object? value) {
    final json = _snapshotObject(value);
    _snapshotExactKeys(json, {'device_id', 'instance_id', 'owner'});
    return ForgeDeviceInventorySnapshotRow(
      deviceID: _snapshotText(json['device_id']),
      instanceID: _snapshotText(json['instance_id']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
    );
  }
}

class ForgeDeviceInventorySnapshotError implements Exception {
  final String code;

  const ForgeDeviceInventorySnapshotError(this.code);

  @override
  String toString() => 'ForgeDeviceInventorySnapshotError($code)';
}

/// Validates and copies a snapshot with rows sorted by device ID then
/// instance ID. The input list remains untouched.
ForgeDeviceInventorySnapshot canonicalizeForgeDeviceInventorySnapshot(
  ForgeDeviceInventorySnapshot snapshot,
) {
  if (!_snapshotIdentifier(snapshot.snapshotID)) {
    throw const ForgeDeviceInventorySnapshotError('invalid_snapshot_id');
  }
  if (snapshot.observedAtMS <= 0) {
    throw const ForgeDeviceInventorySnapshotError('invalid_observed_at');
  }
  if (!_snapshotOwnerValid(snapshot.owner)) {
    throw const ForgeDeviceInventorySnapshotError('invalid_owner');
  }
  if (snapshot.rows.length > forgeDeviceInventorySnapshotMaxRows) {
    throw const ForgeDeviceInventorySnapshotError('too_many_rows');
  }
  final rows = List<ForgeDeviceInventorySnapshotRow>.of(snapshot.rows);
  for (final row in rows) {
    if (!_snapshotIdentifier(row.deviceID) ||
        !_snapshotIdentifier(row.instanceID)) {
      throw const ForgeDeviceInventorySnapshotError('invalid_snapshot_id');
    }
    if (row.owner != snapshot.owner) {
      throw const ForgeDeviceInventorySnapshotError('owner_mismatch');
    }
    if (!_snapshotOwnerValid(row.owner)) {
      throw const ForgeDeviceInventorySnapshotError('invalid_owner');
    }
  }
  rows.sort((left, right) {
    final devices = _snapshotCompareIDs(left.deviceID, right.deviceID);
    return devices == 0
        ? _snapshotCompareIDs(left.instanceID, right.instanceID)
        : devices;
  });
  for (var index = 1; index < rows.length; index++) {
    if (rows[index - 1].deviceID == rows[index].deviceID &&
        rows[index - 1].instanceID == rows[index].instanceID) {
      throw const ForgeDeviceInventorySnapshotError('duplicate_row');
    }
  }
  return ForgeDeviceInventorySnapshot(
    snapshotID: snapshot.snapshotID,
    observedAtMS: snapshot.observedAtMS,
    owner: snapshot.owner,
    rows: List.unmodifiable(rows),
  );
}

/// Computes the stable digest of the canonical unverified declaration.
String digestForgeDeviceInventorySnapshot(
  ForgeDeviceInventorySnapshot snapshot,
) {
  final canonical = canonicalizeForgeDeviceInventorySnapshot(snapshot);
  final bytes = <int>[];
  bytes.addAll(utf8.encode(forgeDeviceInventorySnapshotCanonicalDomain));
  bytes.add(0);
  void appendField(String value) {
    final encoded = utf8.encode(value);
    bytes.addAll(utf8.encode(encoded.length.toString()));
    bytes.add(0x3a);
    bytes.addAll(encoded);
    bytes.add(0);
  }

  void appendOwner(ForgeDeviceOwner owner) {
    appendField(owner.issuer);
    appendField(owner.subject);
    appendField(owner.tenantID);
  }

  appendField(canonical.snapshotID);
  appendField(canonical.observedAtMS.toString());
  appendOwner(canonical.owner);
  for (final row in canonical.rows) {
    appendField(row.deviceID);
    appendField(row.instanceID);
    appendOwner(row.owner);
  }
  return crypto.sha256.convert(bytes).toString();
}

Map<String, dynamic> _snapshotObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge inventory snapshot object.');
  }
  return Map<String, dynamic>.from(value);
}

void _snapshotExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge inventory snapshot fields.');
  }
}

String _snapshotText(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge inventory snapshot text.');
  }
  return value;
}

int _snapshotInteger(Object? value) {
  if (value is! int || value < 0 || value > _snapshotMaxSafeInteger) {
    throw const FormatException('Invalid Forge inventory snapshot integer.');
  }
  return value;
}

bool _snapshotIdentifier(String value) {
  if (value.isEmpty || value.length > 128) return false;
  final codes = value.codeUnits;
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
  return first(codes.first) && codes.skip(1).every(rest);
}

bool _snapshotOwnerValid(ForgeDeviceOwner owner) =>
    _snapshotOwnerPartValid(owner.issuer) &&
    _snapshotOwnerPartValid(owner.subject) &&
    _snapshotOwnerPartValid(owner.tenantID);

bool _snapshotOwnerPartValid(String value) =>
    value.isNotEmpty &&
    utf8.encode(value).length <= 512 &&
    value.trim() == value &&
    !value.runes.any((rune) => rune <= 0x1f || (rune >= 0x7f && rune <= 0x9f));

int _snapshotCompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
