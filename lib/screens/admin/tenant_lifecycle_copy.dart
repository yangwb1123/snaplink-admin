/// Operator copy for tenant lifecycle actions whose credential revocation is
/// best-effort in the current Snaplink backend.
abstract final class TenantLifecycleCopy {
  static String confirmation(String id, String next) => next == 'suspended'
      ? 'Suspend $id? New access is blocked, but the current backend does not '
            'report partial refresh-token or session revocation failures. '
            'Verify active credentials after the change.'
      : 'Return $id to active service?';

  static String deletion(String id, String label) =>
      'Delete $label ($id)? This cannot be undone. The current backend does '
      'not report partial credential/session revocation failures, so '
      'surviving access must be checked separately.';

  static const suspendedResult =
      'Tenant suspended. Verify refresh-token and session revocation in the '
      'security inventories.';

  static const deletedResult =
      'Tenant deleted. Verify that no refresh tokens or sessions remain active.';
}
