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

/// Root-level self-service portal paths mounted by Snaplink. Keep these
/// values aligned with the existing wire contract; resource helpers encode
/// opaque identifiers before placing them in a path segment or query value.
abstract final class PortalPaths {
  static const me = '/me';
  static const identities = '/me/identities';
  static const organizations = '/me/organizations';
  static const notifications = '/me/notifications';
  static const notificationPreferences = '/me/notifications/preferences';
  static const notificationStream = '/me/notifications/stream';
  static const mfa = '/me/mfa';
  static const mfaRecoveryCodes = '/me/mfa/recovery-codes';
  static const webauthnBegin = '/me/mfa/webauthn/begin';
  static const totpBegin = '/me/mfa/totp/begin';
  static const totpConfirm = '/me/mfa/totp/confirm';
  static const password = '/me/password';
  static const emailChange = '/me/email/change';
  static const emailVerify = '/me/email/verify';
  static const dataExport = '/me/data-export';
  static const accountErase = '/me/account/erase';
  static const consents = '/consents/me';
  static const roles = '/roles/me';
  static const permissions = '/permissions/me';
  static const menus = '/menus/me';
  static const invitationAccept = '/me/invitations/accept';

  static String identity(String id) => '$identities/${Uri.encodeComponent(id)}';

  static String organization(String tenantId) =>
      '$organizations/${Uri.encodeComponent(tenantId)}';

  static String organizationMembers(String tenantId) =>
      '${organization(tenantId)}/members';

  static String organizationMember(String tenantId, String userId) =>
      '${organizationMembers(tenantId)}/${Uri.encodeComponent(userId)}';

  static String organizationInvitations(String tenantId) =>
      '${organization(tenantId)}/invitations';

  static String organizationInvitation(String tenantId, String email) =>
      '${organizationInvitations(tenantId)}/${Uri.encodeComponent(email)}';

  static String notificationRead(String id) =>
      '$notifications/${Uri.encodeComponent(id)}/read';

  static String consent(String clientId) =>
      '$consents/${Uri.encodeComponent(clientId)}';

  static String mfaFactor(String id) => '$mfa/${Uri.encodeComponent(id)}';

  static String webauthnFinish(String sessionId) =>
      '/me/mfa/webauthn/finish?session_id=${Uri.encodeComponent(sessionId)}';
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
