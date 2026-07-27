typedef DeviceJson = Map<String, dynamic>;

/// Wire paths mounted by Snaplink when its device and login-history stores are
/// configured. These routes are intentionally kept together because they are
/// not currently part of the generated OpenAPI document.
abstract final class DeviceSecurityPaths {
  static const devices = '/api/v1/admin/devices';
  static const stats = '/api/v1/admin/devices/stats';
  static const bulkRevoke = '/api/v1/admin/devices/bulk-revoke';
  static const securityActivity = '/api/v1/admin/security/activity';

  static String userDevices(String userId) =>
      '/api/v1/admin/users/${Uri.encodeComponent(userId)}/devices';

  static String userDevice(String userId, String deviceId) =>
      '${userDevices(userId)}/${Uri.encodeComponent(deviceId)}';

  static String userLoginHistory(String userId) =>
      '/api/v1/admin/users/${Uri.encodeComponent(userId)}/login-history';

  static String activity(String deviceId) =>
      '$devices/${Uri.encodeComponent(deviceId)}/activity';

  static String resetTrust(String deviceId) =>
      '$devices/${Uri.encodeComponent(deviceId)}/trust';
}

List<DeviceJson> deviceListFrom(Object? value, {String key = 'devices'}) {
  final values = value is Map ? value[key] : null;
  if (values is! List) return const [];
  return values
      .whereType<Map>()
      .map((item) => DeviceJson.from(item))
      .toList(growable: false);
}

List<DeviceJson> loginHistoryFrom(Object? value, {String key = 'activity'}) {
  final values = value is Map ? value[key] : null;
  if (values is! List) return const [];
  return values
      .whereType<Map>()
      .map((item) => DeviceJson.from(item))
      .toList(growable: false);
}

double deviceTrustScore(DeviceJson device) {
  final value = device['trust_score'];
  return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

String deviceId(DeviceJson device) =>
    device['id']?.toString() ?? device['device_id']?.toString() ?? '';

/// A bounded bulk-revocation request.
///
/// [toRequestBody] throws for an unbounded request. This is the final guard at
/// the transport boundary in addition to disabled UI controls and typed
/// confirmation.
class DeviceBulkRevokeFilter {
  final double? trustBelow;
  final bool suspiciousOnly;
  final String platform;
  final String deviceType;

  const DeviceBulkRevokeFilter({
    this.trustBelow,
    this.suspiciousOnly = false,
    this.platform = '',
    this.deviceType = '',
  });

  bool get hasCriteria =>
      (trustBelow != null && trustBelow! > 0) ||
      suspiciousOnly ||
      platform.trim().isNotEmpty ||
      deviceType.trim().isNotEmpty;

  Map<String, dynamic> toRequestBody() {
    if (!hasCriteria) {
      throw StateError(
        'Bulk device revocation requires at least one filter condition.',
      );
    }
    return {
      if (trustBelow != null && trustBelow! > 0) 'trust_below': trustBelow,
      if (suspiciousOnly) 'suspicious': true,
      if (platform.trim().isNotEmpty) 'platform': platform.trim(),
      if (deviceType.trim().isNotEmpty) 'device_type': deviceType.trim(),
    };
  }

  bool matches(DeviceJson device) {
    if (trustBelow != null &&
        trustBelow! > 0 &&
        deviceTrustScore(device) >= trustBelow!) {
      return false;
    }
    if (suspiciousOnly && device['suspicious'] != true) return false;
    if (platform.trim().isNotEmpty &&
        device['platform']?.toString() != platform.trim()) {
      return false;
    }
    if (deviceType.trim().isNotEmpty &&
        device['type']?.toString() != deviceType.trim()) {
      return false;
    }
    return true;
  }

  List<DeviceJson> matching(Iterable<DeviceJson> devices) {
    if (!hasCriteria) return const [];
    return devices.where(matches).toList(growable: false);
  }

  String confirmationText(int matchCount) => 'REVOKE $matchCount DEVICES';
}
