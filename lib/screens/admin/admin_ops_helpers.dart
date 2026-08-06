import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';
import 'package:sso_admin/services/sensitive_data.dart';

/// Helpers for admin operations tab.
class AdminOpsHelpers {
  /// Kept as a compatibility hook for old callers. Snaplink now serves
  /// redacted provider read DTOs, so no documented provider route is hidden.
  static bool exposesUnredactedProviderConfig(SnaplinkAdminEndpoint endpoint) =>
      false;

  /// Snapshot detail is now unconditionally redacted by the server before it
  /// reaches an ordinary admin read, so the compatibility filter is empty.
  static bool exposesDecodedSnapshotResources(SnaplinkAdminEndpoint endpoint) =>
      false;

  /// High-impact routes with richer validation, preview, or reconciliation
  /// requirements must not be bypassed through the generic JSON composer.
  static bool requiresDedicatedWorkflow(SnaplinkAdminEndpoint endpoint) {
    final path = endpoint.path.replaceAllMapped(
      RegExp(r'\{[^}]+\}'),
      (_) => ':id',
    );
    if (path == '/api/v1/admin/branding' ||
        path == '/api/v1/scim/v2/Bulk' ||
        path == '/api/v1/admin/devices/bulk-revoke' ||
        path == '/api/v1/admin/tokens/bulk-revoke' ||
        path == '/api/v1/admin/compliance/retention-sweep' ||
        path == '/api/v1/admin/tenants/:id/export' ||
        path == '/api/v1/compliance/users/:id/erase') {
      return true;
    }
    if (endpoint.method == 'GET') return false;
    return path.startsWith('/api/v1/admin/snapshots') ||
        path.startsWith('/api/v1/admin/releases') ||
        path.startsWith('/api/v1/admin/break-glass') ||
        path.startsWith('/api/v1/admin/changes');
  }

  /// Whether the endpoint returns a subject export (handled as download, not JSON).
  static bool isSubjectExport(SnaplinkAdminEndpoint endpoint) =>
      endpoint.method == 'GET' &&
      (endpoint.path == '/api/v1/compliance/users/{id}/export' ||
          endpoint.path == '/api/v1/compliance/users/:id/export');

  /// Whether the endpoint returns a one-time credential that must be shown once.
  static bool returnsOneTimeCredential(SnaplinkAdminEndpoint endpoint) =>
      endpoint.method == 'POST' &&
      (endpoint.path == '/api/v1/admin/tokens/temp' ||
          endpoint.path == '/api/v1/admin/clients/{id}/rotate-secret' ||
          endpoint.path == '/api/v1/admin/clients/:id/rotate-secret' ||
          endpoint.path == '/api/v1/admin/break-glass/{id}/impersonate' ||
          endpoint.path == '/api/v1/admin/break-glass/:id/impersonate');

  /// Check if a path may receive sensitive input that should be cleared after submit.
  static bool pathMayReceiveSensitiveInput(String path) =>
      path.contains('password') ||
      path.contains('token') ||
      path.contains('secret') ||
      path.contains('webhook') ||
      path.contains('provider') ||
      path.contains('connection') ||
      path.contains('break-glass') ||
      path.contains('impersonate');

  /// Recursively check if a value contains sensitive fields.
  static bool containsSensitiveField(Object? value) =>
      SensitiveData.containsSensitiveField(value);

  /// Binds an approval to the exact method and resolved resource path.
  static String writeConfirmation(String method, String resolvedPath) =>
      'CONFIRM ${method.toUpperCase()} $resolvedPath';

  /// A write receiving one of these statuses may have crossed the commit
  /// boundary even though the browser did not receive a usable success
  /// response. The caller must reconcile authoritative state before allowing
  /// the operator to submit another mutation.
  static bool isAmbiguousWriteStatus(int status) =>
      status == 408 || status == 429 || status >= 500;

  /// Sanitize a generic response before it is retained, rendered, or copied.
  static Map<String, dynamic> redactResponse(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(SensitiveData.redact(response)! as Map);

  /// Show a dialog for one-time credentials.
  static Future<void> showOneTimeCredential(
    BuildContext context,
    Map<String, dynamic> response,
    SnaplinkAdminEndpoint endpoint,
  ) async {
    final credential = switch (endpoint.path) {
      '/api/v1/admin/tokens/temp' => response['token']?.toString(),
      '/api/v1/admin/clients/{id}/rotate-secret' ||
      '/api/v1/admin/clients/:id/rotate-secret' =>
        response['secret']?.toString(),
      _ => response['access_token']?.toString(),
    };
    if (credential == null || credential.isEmpty) return;
    final expiry = response['expires_at_unix'] ?? response['expires_in'];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const LocalizedText('One-time credential'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LocalizedText(
                'Save this value now. It is not retained or shown in the operation response.',
              ),
              if (expiry != null) ...[
                const SizedBox(height: 8),
                LocalizedText('Expiry: {expiry}', args: {'expiry': expiry}),
              ],
              const SizedBox(height: 12),
              SelectableText(
                credential,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const LocalizedText('I have saved it'),
            ),
          ],
        ),
      ),
    );
  }
}
