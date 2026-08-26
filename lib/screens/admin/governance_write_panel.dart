part of 'governance_widgets.dart';

/// Governed write composer: operation picker + JSON body + exact-phrase
/// confirmation. Pre-flight validation (ID, JSON, sensitive fields, typed
/// confirmation, destructive dialog) happens here; the tab owns the wire.
class GovernanceWritePanel extends StatefulWidget {
  final List<GovernanceWriteOperation> operations;
  final bool writing;
  final Color accent;
  final Future<String?> Function(
    String method,
    String path,
    Map<String, dynamic> body,
    String label,
  )
  onWrite;
  const GovernanceWritePanel({
    super.key,
    required this.operations,
    required this.writing,
    required this.accent,
    required this.onWrite,
  });
  @override
  State<GovernanceWritePanel> createState() => _GovernanceWritePanelState();
}

class _GovernanceWritePanelState extends State<GovernanceWritePanel> {
  GovernanceWriteOperation _op = governanceWriteOperations.first;
  final _resourceId = TextEditingController();
  final _writeBody = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  @override
  void initState() {
    super.initState();
    _resourceId.addListener(_onInputChanged);
    _writeBody.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _resourceId.dispose();
    _writeBody.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_confirm.text.isNotEmpty) _confirm.clear();
  }

  String get _confirmationHint {
    var path = _op.path;
    if (path.contains(':id')) {
      final id = _resourceId.text.trim();
      if (id.isEmpty) return 'CONFIRM ${_op.method} <resolved path>';
      path = path.replaceAll(':id', Uri.encodeComponent(id));
    }
    return AdminOpsHelpers.writeConfirmation(_op.method, path);
  }

  Future<void> _run() async {
    var path = _op.path;
    if (path.contains(':id')) {
      final id = _resourceId.text.trim();
      if (id.isEmpty) {
        setState(
          () => _error = 'Enter the affected snapshot, release, or change ID.',
        );
        return;
      }
      path = path.replaceAll(':id', Uri.encodeComponent(id));
    }
    final body = _jsonBody();
    if (body == null) return;
    if (SensitiveData.containsSensitiveField(body)) {
      setState(
        () => _error =
            'Generic governance payloads are retained in reports and approval records. Do not include passwords, tokens, or private keys.',
      );
      return;
    }
    if (!await _confirmed(path)) return;
    final error = await widget.onWrite(_op.method, path, body, _op.label);
    if (!mounted) return;
    if (error != null) setState(() => _error = error);
  }

  Map<String, dynamic>? _jsonBody() {
    try {
      final value = jsonDecode(
        _writeBody.text.trim().isEmpty ? '{}' : _writeBody.text,
      );
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      // Invalid JSON; handled below
    }
    setState(() => _error = 'Request body must be a JSON object.');
    return null;
  }

  Future<bool> _confirmed(String resolvedPath) async {
    final required = AdminOpsHelpers.writeConfirmation(
      _op.method,
      resolvedPath,
    );
    if (_confirm.text.trim() != required) {
      setState(() => _error = 'Type the exact confirmation phrase: $required');
      return false;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm',
      message: context.tr('Run {selected_label}?', {
        'selected_label': _op.label,
      }),
      confirmLabel: 'Run operation',
      destructive: true,
    );
    _confirm.clear();
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.operations.isEmpty) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        compact: true,
        title: 'This feature is not enabled on the connected replica.',
      );
    }
    final selected = widget.operations.contains(_op)
        ? _op
        : widget.operations.first;
    if (_op != selected) _op = selected;
    return GovernanceSection(
      title: 'Governed write composer',
      icon: Icons.edit_outlined,
      accent: widget.accent,
      children: [
        const LocalizedText(
          'Use this for snapshots, deployments, disaster recovery, retention, and two-person change control.',
        ),
        const SizedBox(height: 8),
        if (_error != null) ...[
          Semantics(
            liveRegion: true,
            child: GovernanceErrorBanner(error: _error!),
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<GovernanceWriteOperation>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Operation'.localized),
          items: [
            for (final item in widget.operations)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: widget.writing
              ? null
              : (value) => setState(() {
                  _op = value!;
                  _resourceId.clear();
                  _writeBody.text = value.example;
                  _confirm.clear();
                }),
        ),
        if (selected.path.contains(':id')) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _resourceId,
            enabled: !widget.writing,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Resource ID'.localized),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _writeBody,
          maxLines: 6,
          enabled: !widget.writing,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(labelText: 'Request JSON'.localized),
        ),
        const SizedBox(height: 12),
        // 确认提示只依赖输入文本：仅监听这些控制器局部重建。
        ListenableBuilder(
          listenable: Listenable.merge([_resourceId, _writeBody]),
          builder: (context, _) => TextField(
            controller: _confirm,
            enabled: !widget.writing,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!widget.writing) _run();
            },
            decoration: InputDecoration(
              labelText: 'Exact write confirmation'.localized,
              helperText: _confirmationHint,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.writing ? null : _run,
          icon: widget.writing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.warning_amber_outlined),
          label: LocalizedText(
            'Run {selected_label}',
            args: {'selected_label': selected.label},
          ),
        ),
      ],
    );
  }
}
