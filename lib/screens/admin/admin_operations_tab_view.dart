part of 'admin_operations_tab.dart';

extension _AdminOperationsTabView on _AdminOperationsTabState {
  Widget _buildAdminOperationsTab(BuildContext context) =>
      _adminEndpoints.isEmpty ? _emptyState(context) : _workbench(context);

  Widget _emptyState(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      const SizedBox(height: 4),
      _header(context),
      const SizedBox(height: 16),
      const EmptyState(
        variant: EmptyStateVariant.empty,
        icon: Icons.terminal_outlined,
        title:
            'No optional administration routes are registered on this replica.',
      ),
    ],
  );

  Widget _workbench(BuildContext context) {
    final endpoint = _selected;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        const SizedBox(height: 4),
        _header(context),
        const SizedBox(height: 8),
        const LocalizedText(
          'Documented Snaplink administration routes are listed here; runtime inventory marks routes the current replica reports as active. Server-side feature gates remain authoritative. Write operations are audited and require explicit confirmation.',
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Provider and connection reads are server-redacted, secret fields remain write-only, and ordinary snapshot detail is server-redacted. High-impact workflows with dedicated preview or reconciliation screens cannot be bypassed here.',
          style: TextStyle(color: AppColors.warning),
        ),
        const SizedBox(height: 16),
        _picker(context),
        if (endpoint != null) ...[
          const SizedBox(height: 12),
          _availability(context),
          for (final entry in _pathCtrls.entries) ...[
            const SizedBox(height: 12),
            _field(entry.value, label: 'Path parameter: ${entry.key}'),
          ],
          const SizedBox(height: 12),
          _field(
            _queryCtrl,
            label: 'Query parameters JSON',
            maxLines: 3,
            helper: 'Use {} when none are required.',
            mono: true,
          ),
          if (_isMutation) ...[
            const SizedBox(height: 12),
            _field(
              _bodyCtrl,
              label: 'Request body JSON',
              maxLines: 8,
              mono: true,
            ),
            const SizedBox(height: 12),
            // 确认提示只依赖路径参数文本：仅监听这些控制器局部重建。
            ListenableBuilder(
              listenable: Listenable.merge(_pathCtrls.values),
              builder: (context, _) => _field(
                _confirmCtrl,
                label: 'Exact write confirmation',
                helper: _confirmationHint,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitConfirmation(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _runButton(context),
        ],
        if (_mutationOutcomeUnknown) ...[
          const SizedBox(height: 16),
          AdminOpsHelpers.unknownOutcomeCard(
            context,
            onAcknowledge: _running ? null : _acknowledgeReconciliation,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: AdminOpsHelpers.errorCard(context, _error!),
          ),
        ],
        if (_running && _response == null && _rawResponse == null) ...[
          const SizedBox(height: 16),
          AdminOpsHelpers.loadingCard(),
        ],
        if (_response != null || _rawResponse != null) ...[
          const SizedBox(height: 16),
          AdminOpsHelpers.responseCard(
            context,
            body: AdminOpsHelpers.responseText(_response, _rawResponse),
            onCopy: _copyResponse,
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context) => Row(
    children: [
      Icon(Icons.terminal_outlined, color: _accent, size: 28),
      const SizedBox(width: 12),
      Expanded(
        child: Semantics(
          container: true,
          header: true,
          child: Text(
            AppStrings.of(context).adminOperations,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );

  Widget _picker(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader('Administration endpoint', count: _adminEndpoints.length),
      const SizedBox(height: 8),
      DropdownButtonFormField<SnaplinkAdminEndpoint>(
        initialValue: _selected,
        isExpanded: true,
        items: _adminEndpoints
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  '${item.method} ${item.path}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: _running ? null : _select,
      ),
    ],
  );

  Widget _availability(BuildContext context) {
    final documented = _selected!.feature == 'documented';
    return Row(
      children: [
        StatusChip(
          label: documented
              ? context.tr('Documented only')
              : _selected!.feature,
          color: documented ? AppColors.muted : AppColors.success,
          icon: documented
              ? Icons.description_outlined
              : Icons.check_circle_outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LocalizedText(
            documented
                ? 'Availability: documented contract; this replica has not advertised the route.'
                : 'Runtime feature surface: {feature}',
            args: documented ? null : {'feature': _selected!.feature},
          ),
        ),
      ],
    );
  }

  Widget _runButton(BuildContext context) => FilledButton.icon(
    onPressed: _running || (_isMutation && _mutationOutcomeUnknown)
        ? null
        : _run,
    icon: _running
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.play_arrow),
    label: LocalizedText(
      'Run {endpoint_method}',
      args: {'endpoint_method': _selected!.method},
    ),
  );

  void _submitConfirmation() {
    if (_running || (_isMutation && _mutationOutcomeUnknown)) return;
    _run();
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    int maxLines = 1,
    String? helper,
    bool mono = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    enabled: !_running && (!_isMutation || !_mutationOutcomeUnknown),
    textInputAction: textInputAction,
    onSubmitted: onSubmitted,
    style: mono ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : null,
    decoration: InputDecoration(
      labelText: label.localized,
      helperText: helper?.localized,
    ),
  );

  Future<void> _copyResponse() async {
    await Clipboard.setData(
      ClipboardData(
        text: AdminOpsHelpers.responseText(_response, _rawResponse),
      ),
    );
    if (mounted) {
      showCopySnackBar(
        context,
        content: LocalizedText('Response copied to clipboard.'),
      );
    }
  }
}
