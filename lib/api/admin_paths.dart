/// Canonical wire paths shared by the Admin API clients and screens.
///
/// Values ending in `Template` are capability/catalog patterns only. Request
/// builders accept raw opaque identifiers and encode each path component once;
/// callers must use a builder when sending a request.
abstract final class AdminPaths {
  static const endpointInventory = '/api/v1/admin/endpoints';
  static const adminEventStream = '/api/v1/admin/events/stream';

  static const clients = '/api/v1/admin/clients';

  static String client(String id) => '$clients/${_encoded(id)}';

  /// Only the two published client-review verbs are accepted here.
  static String clientReview(String id, String action) {
    if (action != 'approve' && action != 'reject') {
      throw ArgumentError.value(action, 'action', 'Unsupported client review');
    }
    return '${client(id)}/$action';
  }

  static String clientApprove(String id) => clientReview(id, 'approve');
  static String clientReject(String id) => clientReview(id, 'reject');

  static const tenantMembersTemplate = '/api/v1/admin/tenants/:id/members';
  static const tenantMemberTemplate =
      '/api/v1/admin/tenants/:id/members/:user_id';
  static const tenantInvitationsTemplate =
      '/api/v1/admin/tenants/:id/invitations';
  static const tenantInvitationTemplate =
      '/api/v1/admin/tenants/:id/invitations/:email';

  static String tenantMembers(String tenantId) =>
      '/api/v1/admin/tenants/${_encoded(tenantId)}/members';

  static String tenantMember(String tenantId, String userId) =>
      '${tenantMembers(tenantId)}/${_encoded(userId)}';

  static String tenantInvitations(String tenantId) =>
      '/api/v1/admin/tenants/${_encoded(tenantId)}/invitations';

  static String tenantInvitation(String tenantId, String email) =>
      '${tenantInvitations(tenantId)}/${_encoded(email)}';

  static const webhookSubscriptions = '/api/v1/admin/webhooks/subscriptions';
  static const webhookDeadletters = '/api/v1/admin/webhooks/deadletters';

  static String webhookSubscription(String id) =>
      '$webhookSubscriptions/${_encoded(id)}';

  static String webhookDeadletterReplay(String id) =>
      '$webhookDeadletters/${_encoded(id)}/replay';

  static const breakGlass = '/api/v1/admin/break-glass';

  static String breakGlassSession(String id) => '$breakGlass/${_encoded(id)}';

  static String approveBreakGlass(String id) =>
      '${breakGlassSession(id)}/approve';

  static const credentials = '/api/v1/admin/credentials';

  static String credentialCompromise(String type) =>
      '$credentials/${_encoded(type)}/compromise';

  static const cryptoKeys = '/api/v1/admin/crypto/keys';

  static String cryptoKeyCompromise(String id) =>
      '$cryptoKeys/${_encoded(id)}/compromise';

  static const domains = '/api/v1/admin/domains';

  static String domain(String hostname) => '$domains/${_encoded(hostname)}';

  static const accessPolicies = '/api/v1/admin/access-policies';
  static const threatPolicies = '/api/v1/admin/threat-policies';

  static String threatPolicy(String name) =>
      '$threatPolicies/${_encoded(name)}';

  static const branding = '/api/v1/admin/branding';

  static const permissionBaseTemplate = '/api/v1/admin/permissions/:client_id';
  static const permissionRolesTemplate = '$permissionBaseTemplate/roles';
  static const permissionAssignmentsTemplate =
      '$permissionBaseTemplate/assignments';

  static String permissionRoles(String clientId) =>
      '/api/v1/admin/permissions/${_encoded(clientId)}/roles';

  static String permissionAssignments(String clientId) =>
      '/api/v1/admin/permissions/${_encoded(clientId)}/assignments';

  static const userSessionsTemplate = '/api/v1/admin/users/:id/sessions';
  static const userConsentsTemplate = '/api/v1/admin/users/:id/consents';
  static const userMfaTemplate = '/api/v1/admin/users/:id/mfa';
  static const userLifecycleTemplate = '/api/v1/admin/users/:id/lifecycle';

  static String userResource(String userId, String suffix) =>
      '/api/v1/admin/users/${_encoded(userId)}$suffix';

  static String userSessions(String userId) =>
      userResource(userId, '/sessions');

  static String userConsents(String userId) =>
      userResource(userId, '/consents');

  static String userConsent(String userId, String clientId) =>
      '${userConsents(userId)}/${_encoded(clientId)}';

  static String userMfa(String userId) => userResource(userId, '/mfa');

  static String userMfaFactor(String userId, String factorId) =>
      '${userMfa(userId)}/${_encoded(factorId)}';

  static String userLifecycle(String userId) =>
      userResource(userId, '/lifecycle');

  static const commercePlans = '/api/v1/admin/commerce/plans';

  static String _encoded(String value) => Uri.encodeComponent(value);
}
