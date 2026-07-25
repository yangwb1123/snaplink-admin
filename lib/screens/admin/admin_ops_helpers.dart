import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';

/// Helpers for admin operations tab.
class AdminOpsHelpers {
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
      path.contains('break-glass') ||
      path.contains('impersonate');

  /// Recursively check if a value contains sensitive fields.
  static bool containsSensitiveField(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('password') ||
            key.contains('secret') ||
            key.contains('token') ||
            key.contains('credential') ||
            key.contains('private_key')) {
          return true;
        }
        if (containsSensitiveField(entry.value)) return true;
      }
    } else if (value is List) {
      return value.any(containsSensitiveField);
    }
    return false;
  }

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
      builder: (context) => AlertDialog(
        title: const Text('One-time credential'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save this value now. It is not retained or shown in the operation response.',
            ),
            if (expiry != null) ...[
              const SizedBox(height: 8),
              Text('Expiry: $expiry'),
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
            child: const Text('I have saved it'),
          ),
        ],
      ),
    );
  }
}
