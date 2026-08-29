import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/admin_paths.dart';

void main() {
  test('keeps the canonical Admin collection and stream paths', () {
    expect(AdminPaths.endpointInventory, '/api/v1/admin/endpoints');
    expect(AdminPaths.adminEventStream, '/api/v1/admin/events/stream');
    expect(AdminPaths.clients, '/api/v1/admin/clients');
    expect(
      AdminPaths.webhookSubscriptions,
      '/api/v1/admin/webhooks/subscriptions',
    );
    expect(AdminPaths.webhookDeadletters, '/api/v1/admin/webhooks/deadletters');
    expect(AdminPaths.breakGlass, '/api/v1/admin/break-glass');
    expect(AdminPaths.credentials, '/api/v1/admin/credentials');
    expect(AdminPaths.cryptoKeys, '/api/v1/admin/crypto/keys');
    expect(AdminPaths.domains, '/api/v1/admin/domains');
    expect(AdminPaths.accessPolicies, '/api/v1/admin/access-policies');
    expect(AdminPaths.threatPolicies, '/api/v1/admin/threat-policies');
    expect(AdminPaths.branding, '/api/v1/admin/branding');
    expect(AdminPaths.commercePlans, '/api/v1/admin/commerce/plans');
  });

  test('keeps templates for capability and catalog matching only', () {
    expect(
      AdminPaths.tenantMembersTemplate,
      '/api/v1/admin/tenants/:id/members',
    );
    expect(
      AdminPaths.tenantMemberTemplate,
      '/api/v1/admin/tenants/:id/members/:user_id',
    );
    expect(
      AdminPaths.permissionRolesTemplate,
      '/api/v1/admin/permissions/:client_id/roles',
    );
    expect(AdminPaths.userConsentsTemplate, '/api/v1/admin/users/:id/consents');
  });

  test('encodes opaque identifiers as path components', () {
    expect(
      AdminPaths.clientApprove('client /+'),
      '/api/v1/admin/clients/client%20%2F%2B/approve',
    );
    expect(
      AdminPaths.tenantMember('tenant /+', 'user /+'),
      '/api/v1/admin/tenants/tenant%20%2F%2B/members/user%20%2F%2B',
    );
    expect(
      AdminPaths.tenantInvitation('tenant /+', 'person+ops@example.test'),
      '/api/v1/admin/tenants/tenant%20%2F%2B/invitations/person%2Bops%40example.test',
    );
    expect(
      AdminPaths.domain('host name/+'),
      '/api/v1/admin/domains/host%20name%2F%2B',
    );
    expect(
      AdminPaths.credentialCompromise('credential /+'),
      '/api/v1/admin/credentials/credential%20%2F%2B/compromise',
    );
    expect(
      AdminPaths.userMfaFactor('user /+', 'factor /+'),
      '/api/v1/admin/users/user%20%2F%2B/mfa/factor%20%2F%2B',
    );
  });

  test('preserves the published review and detail wire values', () {
    expect(
      AdminPaths.clientReject('pending-client'),
      '/api/v1/admin/clients/pending-client/reject',
    );
    expect(
      AdminPaths.approveBreakGlass('grant-1'),
      '/api/v1/admin/break-glass/grant-1/approve',
    );
    expect(
      AdminPaths.webhookDeadletterReplay('dead-letter-1'),
      '/api/v1/admin/webhooks/deadletters/dead-letter-1/replay',
    );
    expect(
      AdminPaths.permissionAssignments('client-1'),
      '/api/v1/admin/permissions/client-1/assignments',
    );
    expect(
      AdminPaths.userLifecycle('user-1'),
      '/api/v1/admin/users/user-1/lifecycle',
    );
  });

  test('owner builders preserve the existing Admin wire paths', () {
    expect(AdminPaths.client('client-1'), '/api/v1/admin/clients/client-1');
    expect(
      AdminPaths.clientApprove('client-1'),
      '/api/v1/admin/clients/client-1/approve',
    );
    expect(
      AdminPaths.tenantMembers('tenant-1'),
      '/api/v1/admin/tenants/tenant-1/members',
    );
    expect(
      AdminPaths.tenantInvitations('tenant-1'),
      '/api/v1/admin/tenants/tenant-1/invitations',
    );
    expect(
      AdminPaths.webhookSubscription('sub-1'),
      '/api/v1/admin/webhooks/subscriptions/sub-1',
    );
    expect(
      AdminPaths.breakGlassSession('grant-1'),
      '/api/v1/admin/break-glass/grant-1',
    );
    expect(
      AdminPaths.cryptoKeyCompromise('key-1'),
      '/api/v1/admin/crypto/keys/key-1/compromise',
    );
    expect(
      AdminPaths.threatPolicy('strict'),
      '/api/v1/admin/threat-policies/strict',
    );
    expect(
      AdminPaths.permissionRoles('client-1'),
      '/api/v1/admin/permissions/client-1/roles',
    );
    expect(
      AdminPaths.userSessions('user-1'),
      '/api/v1/admin/users/user-1/sessions',
    );
    expect(
      AdminPaths.userConsents('user-1'),
      '/api/v1/admin/users/user-1/consents',
    );
    expect(
      AdminPaths.userConsent('user-1', 'client-1'),
      '/api/v1/admin/users/user-1/consents/client-1',
    );
    expect(AdminPaths.userMfa('user-1'), '/api/v1/admin/users/user-1/mfa');
    expect(
      AdminPaths.userMfaFactor('user-1', 'factor-1'),
      '/api/v1/admin/users/user-1/mfa/factor-1',
    );
  });

  test('does not turn an arbitrary action into a new client endpoint', () {
    expect(
      () => AdminPaths.clientReview('client-1', 'rotate-secret'),
      throwsArgumentError,
    );
  });
}
