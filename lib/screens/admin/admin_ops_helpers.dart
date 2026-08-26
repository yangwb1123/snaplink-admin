import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import 'tenant_export_download.dart';

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
  static Map<String, dynamic> redactResponse(Map<String, dynamic> response) {
    final redacted = SensitiveData.redact(response);
    return Map<String, dynamic>.from(_redactUriValues(redacted)! as Map);
  }

  static Object? _redactUriValues(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _redactUriValues(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_redactUriValues).toList(growable: false);
    }
    if (value is String) return _redactUri(value);
    return value;
  }

  static String _redactUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    var changed = uri.userInfo.isNotEmpty;
    final queryParameters = <String, dynamic>{};
    for (final entry in uri.queryParametersAll.entries) {
      final sensitive = SensitiveData.isSensitiveKey(entry.key);
      changed = changed || sensitive;
      queryParameters[entry.key] = entry.value.length == 1
          ? (sensitive ? SensitiveData.redacted : entry.value.single)
          : [
              for (final item in entry.value)
                sensitive ? SensitiveData.redacted : item,
            ];
    }
    if (!changed) return value;
    return uri
        .replace(
          userInfo: uri.userInfo.isEmpty ? null : SensitiveData.redacted,
          queryParameters: queryParameters,
        )
        .toString();
  }

  /// 请求体/查询 JSON 解析：必须解码为 JSON 对象。
  static Map<String, dynamic> parseJsonObject(String value, String label) {
    Object? decoded;
    try {
      decoded = jsonDecode(value.trim().isEmpty ? '{}' : value);
    } on FormatException {
      // Normalized below so the operator sees which input needs correction.
    }
    if (decoded is Map) {
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded);
    }
    throw FormatException('$label must be a JSON object.');
  }

  /// 查询参数映射（值字符串化）。
  static Map<String, String> stringMap(String value, String label) =>
      parseJsonObject(
        value,
        label,
      ).map((key, item) => MapEntry(key, item.toString()));

  /// 按端点契约派发单个请求；GET /docs 返回 null，文档文本由调用方单独拉取。
  static Future<Map<String, dynamic>?> dispatchRequest(
    SnaplinkAdminApi api,
    SnaplinkAdminEndpoint endpoint,
    String path,
    Map<String, String> query,
    Object? body,
  ) async {
    if (endpoint.method == 'GET' && endpoint.path == '/api/v1/admin/docs') {
      return null;
    }
    final contentType = endpoint.path.startsWith('/api/v1/scim/')
        ? 'application/scim+json'
        : 'application/json';
    return switch (endpoint.method) {
      'GET' => await api.get(path, query: query),
      'POST' => await api.post(path, body, contentType),
      'PUT' => await api.put(path, body, contentType),
      'PATCH' => await api.patch(path, body, contentType),
      'DELETE' => await api.delete(path, body, contentType),
      _ => throw ArgumentError.value(
        endpoint.method,
        'method',
        'Unsupported HTTP method',
      ),
    };
  }

  /// 主体导出：直接触发浏览器下载，不在控制台预览。
  static Future<void> downloadSubjectExport(
    BuildContext context,
    SnaplinkAdminApi api,
    String path,
    Map<String, String> query,
  ) async {
    final export = await api.getDownload(path, query: query);
    if (!context.mounted) return;
    downloadAdminAttachment(
      export,
      fallbackFilename: 'snaplink-subject-export.json',
    );
    showAppSnackBar(
      context,
      content: LocalizedText(
        'Subject export downloaded without previewing it.',
      ),
    );
  }

  /// 响应文本：JSON（缩进）或原始文档；供面板与复制共用。
  static String responseText(
    Map<String, dynamic>? response,
    String? rawResponse,
  ) => response == null
      ? rawResponse ?? ''
      : const JsonEncoder.withIndent('  ').convert(response);

  /// 结果未知锁：上一写入可能已提交 → 输入锁定，必须先核对权威状态。
  static Widget unknownOutcomeCard(
    BuildContext context, {
    required VoidCallback? onAcknowledge,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sync_problem_outlined, color: scheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const LocalizedText(
                        'Previous write outcome is unknown',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const LocalizedText(
                'Mutation inputs are locked. Select and run a safe GET, or '
                'use the dedicated resource screen, then explicitly '
                'acknowledge reconciliation.',
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAcknowledge,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const LocalizedText('I reconciled server state'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 三态-error：danger 容器错误卡；错误文本动态渲染（FM-1）。
  /// 刻意不提供 Retry——重放写入会破坏“结果未知不重放”语义。
  static Widget errorCard(BuildContext context, String error) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              // Backend error text is runtime data, not an i18n key. Keeping
              // it as Text also prevents an error that happens to match a
              // catalog entry from being silently rewritten.
              child: Text(error, style: TextStyle(color: scheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  /// 三态-loading：运行中（响应未回）时响应面板显示骨架。
  static Widget loadingCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader('Response'),
      const SizedBox(height: 8),
      const SkeletonListTile(itemCount: 2),
    ],
  );

  /// 响应面板：SectionHeader + 复制 + monospace 只读 JSON。
  static Widget responseCard(
    BuildContext context, {
    required String body,
    required VoidCallback onCopy,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Response',
            action: TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const LocalizedText('Copy'),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: SelectableText(
                body,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );

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
