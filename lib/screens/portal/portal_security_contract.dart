import 'portal_api.dart';

/// Self-service security paths mounted by Snaplink.
abstract final class PortalSecurityPaths {
  static const devices = '/me/devices';
  static const trustedDevices = '/me/trusted-devices';
  static const trustCurrentBrowser = '/me/trusted-devices/trust';
  static const enrichedSessions = '/me/sessions/enriched';
  static const legacySessions = '/sessions/me';
  static const securityActivity = '/me/security/activity';
  static const loginHistory = '/me/login-history';

  static String device(String id) => '$devices/${Uri.encodeComponent(id)}';
  static String trustedDevice(String id) =>
      '$trustedDevices/${Uri.encodeComponent(id)}';
  static String legacySession(String id) =>
      '$legacySessions/${Uri.encodeComponent(id)}';
  static String deviceActivity(String id) => '${device(id)}/activity';
  static String deviceSessions(String id) => '${device(id)}/sessions';
  static String deviceTrust(String id) => '${device(id)}/trust';
  static String deviceLost(String id) => '${device(id)}/lost';
}

enum PortalDeviceCollectionKind { empty, physical, trustedGrants, ambiguous }

/// Physical-device records carry posture/fingerprint fields. Classification
/// remains a defensive schema check even though trusted grants now use their
/// own resource path.
bool isPhysicalDeviceRecord(Map<String, dynamic> value) =>
    value.containsKey('fingerprint') ||
    value.containsKey('device_name') ||
    value.containsKey('platform') ||
    value.containsKey('trust_score') ||
    value.containsKey('first_seen_at') ||
    value.containsKey('last_seen_at') ||
    value.containsKey('active_sessions');

bool isTrustedDeviceGrant(Map<String, dynamic> value) =>
    !isPhysicalDeviceRecord(value) &&
    (value.containsKey('client_id') ||
        (value.containsKey('label') && value.containsKey('expires_at')));

PortalDeviceCollectionKind classifyDeviceCollection(
  Iterable<Map<String, dynamic>> devices,
) {
  final values = devices.toList(growable: false);
  if (values.isEmpty) return PortalDeviceCollectionKind.empty;
  final physical = values.where(isPhysicalDeviceRecord).length;
  final grants = values.where(isTrustedDeviceGrant).length;
  if (physical == values.length) return PortalDeviceCollectionKind.physical;
  if (grants == values.length) {
    return PortalDeviceCollectionKind.trustedGrants;
  }
  return PortalDeviceCollectionKind.ambiguous;
}

List<Map<String, dynamic>> portalObjectList(
  Map<String, dynamic> payload,
  String key,
) {
  final raw = payload[key];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

class PortalSessionsResult {
  final List<Map<String, dynamic>> sessions;
  final bool usedLegacyEndpoint;

  const PortalSessionsResult({
    required this.sessions,
    required this.usedLegacyEndpoint,
  });
}

/// Prefer the device-enriched contract. Only an explicit "not mounted" or
/// "not implemented" response falls back; server/auth failures must remain
/// visible instead of silently degrading to a second request.
Future<PortalSessionsResult> loadPortalSessions(PortalApi api) async {
  final enriched = await api.get(PortalSecurityPaths.enrichedSessions);
  if (enriched.statusCode == 200) {
    return PortalSessionsResult(
      sessions: portalObjectList(PortalApi.decode(enriched), 'sessions'),
      usedLegacyEndpoint: false,
    );
  }
  if (enriched.statusCode != 404 && enriched.statusCode != 501) {
    throw PortalApiError(
      enriched.statusCode,
      enriched.statusCode == 401
          ? 'Your session has expired.'
          : 'Active sessions are not available.',
    );
  }

  final legacy = await api.get(PortalSecurityPaths.legacySessions);
  if (legacy.statusCode != 200) {
    throw PortalApiError(
      legacy.statusCode,
      legacy.statusCode == 401
          ? 'Your session has expired.'
          : 'Active sessions are not available.',
    );
  }
  return PortalSessionsResult(
    sessions: portalObjectList(PortalApi.decode(legacy), 'sessions'),
    usedLegacyEndpoint: true,
  );
}
