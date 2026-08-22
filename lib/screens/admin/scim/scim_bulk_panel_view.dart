part of 'scim_bulk_panel.dart';

/// Visual composition for [ScimBulkPanel]. Network and reconciliation state
/// remain owned by the state object; this part only maps that state to widgets.
extension _ScimBulkPanelView on _ScimBulkPanelState {
  Widget _buildBulkPanel(BuildContext context) {
    if (_unavailable) return ScimUnavailable(onRetry: _loadProfile);
    final preview = _preview;
    final supported = _profile?.bulk == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulkHeader(context, supported),
        const SizedBox(height: 8),
        _bulkLimits(),
        const SizedBox(height: 12),
        _safetyNotice(context),
        const SizedBox(height: 12),
        _requestEditor(preview, supported),
        const SizedBox(height: 12),
        _previewActions(preview, supported),
        ..._stateNotices(supported),
        ..._resultWidgets(context),
      ],
    );
  }

  Widget _bulkHeader(BuildContext context, bool supported) {
    return Row(
      children: [
        // R33: title wraps under narrow viewports while actions stay trailing.
        Expanded(
          child: LocalizedText(
            'SCIM Bulk',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (_loadingProfile)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed:
              _submitting || _loadingProfile || !supported || _outcomeUnknown
              ? null
              : _loadTemplate,
          icon: const Icon(Icons.description_outlined),
          label: const LocalizedText('Load template'),
        ),
      ],
    );
  }

  Widget _bulkLimits() {
    return LocalizedText(
      'Bounded expert mode · max {maxOperations} operations · '
      'max {maxPayload}. POST operations require bulkId; targets are '
      'limited to /Users and /Groups.',
      args: {
        'maxOperations': '$_maxOperations',
        'maxPayload': formatScimBytes(_maxPayload),
      },
    );
  }

  Widget _safetyNotice(BuildContext context) {
    return _NoticeCard(
      background: Theme.of(context).colorScheme.secondaryContainer,
      icon: Icons.security_outlined,
      title: 'Validate before execution',
      subtitle:
          'Empty, malformed, oversized, recursive, or unsupported '
          'requests cannot be sent. Keep credentials and secrets out of '
          'the editor; the server returns per-operation status.',
    );
  }

  Widget _requestEditor(ScimBulkPreview? preview, bool supported) {
    return TextField(
      controller: _controller,
      enabled: !_submitting && supported && !_outcomeUnknown,
      minLines: 14,
      maxLines: 24,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: 'BulkRequest JSON'.localized,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        errorText: _controller.text.isEmpty ? null : preview?.error,
      ),
    );
  }

  Widget _previewActions(ScimBulkPreview? preview, bool supported) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ScimMetric(
          label: 'Operations',
          value: '${preview?.operationCount ?? 0}',
        ),
        ScimMetric(
          label: 'Payload',
          value: formatScimBytes(preview?.payloadBytes ?? 0),
        ),
        for (final entry in (preview?.methodCounts ?? const {}).entries)
          ScimMetric(label: entry.key, value: '${entry.value}'),
        FilledButton.icon(
          onPressed:
              preview?.isValid == true &&
                  !_submitting &&
                  supported &&
                  !_outcomeUnknown
              ? _submit
              : null,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: const LocalizedText('Execute bulk'),
        ),
      ],
    );
  }

  List<Widget> _stateNotices(bool supported) {
    return [
      if (!supported && !_loadingProfile && _error == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LocalizedText(
            'This service provider does not advertise Bulk.',
          ),
        ),
      if (_outcomeUnknown)
        _NoticeCard(
          icon: Icons.sync_problem_outlined,
          title: 'Previous bulk outcome is unknown',
          subtitle:
              'The retained request is locked until server state has '
              'been reconciled.',
          trailing: TextButton(
            onPressed: _acknowledgeReconciliation,
            child: const LocalizedText('I reconciled server state'),
          ),
        ),
      if (_error != null)
        _NoticeCard(
          icon: Icons.error_outline,
          title: _error!,
          trailing: _profile == null && !_outcomeUnknown
              ? TextButton.icon(
                  onPressed: _loadingProfile ? null : _loadProfile,
                  icon: const Icon(Icons.refresh),
                  label: const LocalizedText('Retry discovery'),
                )
              : null,
        ),
    ];
  }

  List<Widget> _resultWidgets(BuildContext context) {
    final result = _result;
    if (result == null) return const [];
    return [
      ScimBulkResultSummary(result: result),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: true,
        title: const LocalizedText('Bulk response'),
        subtitle: const LocalizedText(
          'Per-operation status; overall HTTP is 200',
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent(
                '  ',
              ).convert(SensitiveData.redact(result)),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    ];
  }
}

/// Bulk-panel message card shared by safety, unknown-outcome and error states.
class _NoticeCard extends StatelessWidget {
  final Color? background;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _NoticeCard({
    this.background,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: background ?? Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: Icon(icon),
      title: LocalizedText(title),
      subtitle: subtitle == null ? null : LocalizedText(subtitle!),
      trailing: trailing,
    ),
  );
}
