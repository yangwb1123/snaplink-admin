import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'admin_module_groups.dart';
import 'tenant_export_download.dart';

/// Operator workflow for GDPR subject requests and retention execution.
///
/// Sensitive exports are sent directly to a browser attachment and are never
/// rendered, copied, or retained in widget state.
class PrivacyComplianceTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const PrivacyComplianceTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<PrivacyComplianceTab> createState() => _PrivacyComplianceTabState();
}

class _PrivacyComplianceTabState extends State<PrivacyComplianceTab> {
  static const _subjectPrefix = '/api/v1/compliance/users';
  static const _retentionPath = '/api/v1/admin/compliance/retention-sweep';

  /// 组色（tenants → amber）：页头与区块图标按组色上色（X7）。
  Color get _accent => adminModuleIconColor('privacy-compliance');

  final _subject = TextEditingController();
  Map<String, dynamic>? _erasurePreview;
  Map<String, dynamic>? _erasureResult;
  Map<String, dynamic>? _retentionReport;
  String? _previewSubject;
  String? _error;
  bool _busy = false;
  Future<void> Function()? _lastOperation;

  bool get _exportable => _has('GET', '$_subjectPrefix/{id}/export');
  bool get _erasable => _has('POST', '$_subjectPrefix/{id}/erase');
  bool get _sweepable => _has('POST', _retentionPath);

  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == method && endpoint.path == path,
      );

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  String? _subjectId() {
    final value = _subject.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter the data subject’s user ID.');
      return null;
    }
    return value;
  }

  Future<void> _export() async {
    final subject = _subjectId();
    if (subject == null) return;
    await _run(() async {
      final attachment = await widget.api.getDownload(
        '$_subjectPrefix/${Uri.encodeComponent(subject)}/export',
      );
      downloadAdminAttachment(
        attachment,
        fallbackFilename: 'snaplink-subject-$subject-export.json',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText(
              'Encrypted transport complete; export downloaded.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _previewErase() async {
    final subject = _subjectId();
    if (subject == null) return;
    await _run(() async {
      final report = await widget.api.post(
        '$_subjectPrefix/${Uri.encodeComponent(subject)}/erase',
        {'dry_run': true},
      );
      if (!mounted) return;
      setState(() {
        _previewSubject = subject;
        _erasurePreview = report;
        _erasureResult = null;
      });
    });
  }

  Future<void> _commitErase() async {
    final subject = _subjectId();
    if (subject == null) return;
    if (_previewSubject != subject || _erasurePreview == null) {
      setState(
        () => _error =
            'Run a fresh dry-run preview for this subject before erasure.',
      );
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Permanently erase subject data?',
      message:
          'This revokes credentials and sessions before deleting the account. '
          'Snaplink does not expose a legal-hold check here; verify the request '
          'against your external hold register first.',
      confirmLabel: 'Erase subject',
      confirmText: subject,
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() async {
      final report = await widget.api.post(
        '$_subjectPrefix/${Uri.encodeComponent(subject)}/erase',
        {'dry_run': false},
      );
      if (!mounted) return;
      setState(() {
        _erasureResult = report;
        _erasurePreview = null;
        _previewSubject = null;
      });
    });
  }

  Future<void> _retention({required bool dryRun}) async {
    if (!dryRun) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Run retention sweep?',
        message:
            'Expired sessions may be destroyed and dormant accounts may be '
            'erased when the server’s AutoEraseDormant policy is enabled.',
        confirmLabel: 'Run sweep',
        confirmText: 'RUN RETENTION',
        destructive: true,
      );
      if (!confirmed) return;
    }
    await _run(() async {
      final report = await widget.api.post(_retentionPath, {'dry_run': dryRun});
      if (mounted) setState(() => _retentionReport = report);
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
      _lastOperation = operation;
    });
    try {
      await operation();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: _accent),
          const SizedBox(width: 8),
          LocalizedText(
            'Privacy and retention',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
      const SizedBox(height: 4),
      const LocalizedText(
        'Execute data-subject requests with preview-first controls and keep '
        'sensitive exports out of the console display.',
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        _errorCard(context),
      ],
      if (_busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (!_exportable && !_erasable && !_sweepable)
        const EmptyState(
          variant: EmptyStateVariant.notEnabled,
          compact: true,
          title: 'No compliance operations are advertised by this replica.',
        )
      else ...[
        const SizedBox(height: 12),
        _subjectCard(context),
        const SizedBox(height: 12),
        _retentionCard(context),
      ],
    ],
  );

  /// 错误区：danger 卡片 + Retry（X4）——`_lastOperation` 提供重试闭包。
  Widget _errorCard(BuildContext context) => Card(
    color: AppColors.danger.withValues(alpha: 0.06),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          if (_lastOperation != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_lastOperation!),
              icon: const Icon(Icons.refresh),
              label: const LocalizedText('Retry'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _subjectCard(BuildContext context) => _section(
    context,
    'Data-subject request',
    'Exports may contain PII. They download directly and are never placed in '
        'console history or clipboard.',
    [
      TextField(
        controller: _subject,
        enabled: !_busy,
        decoration: InputDecoration(labelText: 'User ID'.localized),
        onChanged: (_) {
          if (_previewSubject != _subject.text.trim()) {
            setState(() {
              _erasurePreview = null;
              _previewSubject = null;
            });
          }
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_exportable)
            OutlinedButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.download_outlined), label: const LocalizedText('Download export')),
          if (_erasable)
            OutlinedButton.icon(onPressed: _busy ? null : _previewErase, icon: const Icon(Icons.fact_check_outlined), label: const LocalizedText('Preview erasure')),
          if (_erasable)
            FilledButton.icon(onPressed: _busy || _erasurePreview == null ? null : _commitErase, style: FilledButton.styleFrom(backgroundColor: AppColors.danger), icon: const Icon(Icons.person_remove_outlined), label: const LocalizedText('Commit erasure')),
        ],
      ),
      if (_erasurePreview != null) ...[
        const SizedBox(height: 12),
        _reportCard('Dry-run preview', _erasurePreview!),
      ],
      if (_erasureResult != null) ...[
        const SizedBox(height: 12),
        _reportCard('Erasure report', _erasureResult!),
      ],
    ],
    icon: Icons.manage_accounts_outlined,
  );

  Widget _retentionCard(BuildContext context) => _section(
    context,
    'Retention sweep',
    'A request cannot disable server-enforced dry-run mode. Audit events past '
        'retention are reported, never deleted by this sweep.',
    [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: _busy ? null : () => _retention(dryRun: true),
            child: const LocalizedText('Preview sweep'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _retention(dryRun: false),
            child: const LocalizedText('Run governed sweep'),
          ),
        ],
      ),
      if (_retentionReport != null) ...[
        const SizedBox(height: 12),
        _reportCard('Latest retention report', _retentionReport!),
      ],
    ],
    icon: Icons.history_toggle_off,
  );

  /// 区块卡片：图标按组色上色（X7），标题/副标题 + Divider 分隔内容。
  Widget _section(
    BuildContext context,
    String title,
    String subtitle,
    List<Widget> children, {
    IconData? icon,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: _accent), const SizedBox(width: 8)],
                  LocalizedText(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              LocalizedText(subtitle),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );

  /// 结果卡：报告标题 + 结果状态徽章；API 字段用 Text 渲染（X1/X10）。
  Widget _reportCard(String title, Map<String, dynamic> report) {
    final errors = report['errors'] as List? ?? const [];
    final ok = errors.isEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LocalizedText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (ok)
                  StatusChip(
                    label: 'Success'.localized,
                    color: AppColors.success,
                    icon: Icons.check_circle,
                  )
                else
                  StatusChip.degraded(label: 'Errors'.localized),
              ],
            ),
            for (final entry in report.entries)
              if (entry.key != 'errors')
                Text('${entry.key}: ${entry.value}'),
            if (errors.isNotEmpty)
              LocalizedText('errors: {list}', args: {'list': errors.join(' · ')}),
          ],
        ),
      ),
    );
  }
}
