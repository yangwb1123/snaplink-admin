part of 'privacy_compliance_tab.dart';

extension _PrivacyComplianceTabView on _PrivacyComplianceTabState {
  Widget _buildPrivacyComplianceTab(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: _accent),
          const SizedBox(width: 8),
          Semantics(
            container: true,
            header: true,
            child: LocalizedText(
              'Privacy and retention',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const LocalizedText(
        'Execute data-subject requests with preview-first controls and keep '
        'sensitive exports out of the console display.',
      ),
      if (_error != null) ...[const SizedBox(height: 12), _errorCard(context)],
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

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）——`_lastOperation`
  /// 提供重试闭包。
  Widget _errorCard(BuildContext context) => ErrorStateCard(
    message: _error!,
    onRetry: _lastOperation == null ? null : () => _run(_lastOperation!),
    retryEnabled: !_busy,
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
            // ignore: invalid_use_of_protected_member
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
            OutlinedButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.file_download_outlined),
              label: const LocalizedText('Download export'),
            ),
          if (_erasable)
            OutlinedButton.icon(
              onPressed: _busy ? null : _previewErase,
              icon: const Icon(Icons.fact_check_outlined),
              label: const LocalizedText('Preview erasure'),
            ),
          if (_erasable)
            FilledButton.icon(
              onPressed: _busy || _erasurePreview == null ? null : _commitErase,
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.person_remove_outlined),
              label: const LocalizedText('Commit erasure'),
            ),
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
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: _accent),
                const SizedBox(width: 8),
              ],
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                // R33：标题 Expanded（窄屏/字号缩放换行而非溢出），状态徽章仍贴右。
                Expanded(
                  child: LocalizedText(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
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
              if (entry.key != 'errors') Text('${entry.key}: ${entry.value}'),
            if (errors.isNotEmpty)
              LocalizedText(
                'errors: {list}',
                args: {'list': errors.join(' · ')},
              ),
          ],
        ),
      ),
    );
  }
}
