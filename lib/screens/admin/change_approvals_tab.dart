import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/services/sensitive_data.dart';

import 'change_approval_models.dart';

/// Two-person approval workflow for high-impact administrative changes.
class ChangeApprovalsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const ChangeApprovalsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<ChangeApprovalsTab> createState() => _ChangeApprovalsTabState();
}

class _ChangeApprovalsTabState extends State<ChangeApprovalsTab> {
  static const _basePath = '/api/v1/admin/changes';

  List<Map<String, dynamic>> _changes = const [];
  String _status = 'all';
  String? _error;
  bool _loading = false;
  bool _mutating = false;

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_basePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_basePath);

  List<Map<String, dynamic>> get _visible => _status == 'all'
      ? _changes
      : _changes
            .where((change) => change['status']?.toString() == _status)
            .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_available) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_basePath, forceRefresh: true);
      final values = data['changes'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _changes = values
            .whereType<Map>()
            .map(normalizeChangeApproval)
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _propose() async {
    final draft = await showDialog<_ChangeDraft>(
      context: context,
      builder: (_) => const _ChangeProposalDialog(),
    );
    if (draft == null || !mounted) return;
    await _write(
      () => widget.api.post(_basePath, draft.body),
      'Change proposed for second-admin approval.',
    );
  }

  Future<void> _decide(Map<String, dynamic> change, bool approve) async {
    final id = change['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final action = approve ? 'approve' : 'reject';
    final confirmed = await ConfirmDialog.show(
      context,
      title: approve ? 'Approve this change?' : 'Reject this change?',
      message: approve
          ? 'Approval may immediately apply ${change['action_type'] ?? 'the requested action'}. You must be a different administrator from the proposer.'
          : 'Reject ${change['action_type'] ?? 'this request'}? It will never be applied.',
      confirmLabel: approve ? 'Approve' : 'Reject',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    await _write(
      () =>
          widget.api.post('$_basePath/${Uri.encodeComponent(id)}/$action', {}),
      approve ? 'Change approved.' : 'Change rejected.',
    );
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() operation,
    String success,
  ) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: Text('Two-person administrative approvals are not enabled.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        Row(
          children: [
            Text(
              'Change approvals',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading || _mutating ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _mutating ? null : _propose,
              icon: const Icon(Icons.add_task),
              label: const Text('Propose change'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'High-impact changes require an independent administrator to approve them before application.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final status in const [
              'all',
              'pending',
              'approved',
              'applied',
              'rejected',
              'failed',
            ])
              ChoiceChip(
                label: Text(status),
                selected: _status == status,
                onSelected: (_) => setState(() => _status = status),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncView<List<Map<String, dynamic>>>(
          loading: _loading,
          error: _error,
          data: _visible,
          onRetry: _load,
          emptyTitle: 'No change requests',
          emptySubtitle: _status == 'all'
              ? 'No governed changes have been proposed.'
              : 'No requests currently have this status.',
          dataBuilder: (changes) => Column(
            children: [
              for (final change in changes) _changeCard(context, change),
            ],
          ),
        ),
      ],
    );
  }

  Widget _changeCard(BuildContext context, Map<String, dynamic> change) {
    final status = change['status']?.toString() ?? 'unknown';
    final pending = status == 'pending';
    final decidedBy = change['approved_by']?.toString().trim() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(
          _statusIcon(status),
          color: _statusColor(context, status),
        ),
        title: Text(change['action_type']?.toString() ?? 'Change request'),
        subtitle: Text(
          '$status · proposed by ${change['proposed_by'] ?? 'unknown'}\n${change['reason'] ?? ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(
              SensitiveData.redact(
                change['payload'] ?? const <String, dynamic>{},
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          if (change['failure_note']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              change['failure_note'].toString(),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Created ${change['created_at'] ?? ''}'
            '${decidedBy.isEmpty ? '' : ' · decided by $decidedBy'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (pending) ...[
            const SizedBox(height: 10),
            OverflowBar(
              children: [
                OutlinedButton(
                  onPressed: _mutating ? null : () => _decide(change, false),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: _mutating ? null : () => _decide(change, true),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _statusIcon(String status) => switch (status) {
    'pending' => Icons.hourglass_top,
    'approved' => Icons.verified_outlined,
    'applied' => Icons.check_circle_outline,
    'rejected' => Icons.block,
    'failed' => Icons.error_outline,
    _ => Icons.help_outline,
  };

  Color _statusColor(BuildContext context, String status) => switch (status) {
    'pending' => Colors.orange,
    'approved' || 'applied' => Colors.green,
    'rejected' || 'failed' => Colors.red,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

class _ChangeDraft {
  final String actionType;
  final String reason;
  final Map<String, dynamic> payload;

  const _ChangeDraft({
    required this.actionType,
    required this.reason,
    required this.payload,
  });

  Map<String, dynamic> get body => {
    'action_type': actionType,
    'reason': reason,
    'payload': payload,
  };
}

class _ChangeProposalDialog extends StatefulWidget {
  const _ChangeProposalDialog();

  @override
  State<_ChangeProposalDialog> createState() => _ChangeProposalDialogState();
}

class _ChangeProposalDialogState extends State<_ChangeProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _typeCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController(text: '{}');
  String? _error;

  @override
  void dispose() {
    _typeCtrl.dispose();
    _reasonCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final decoded = jsonDecode(_payloadCtrl.text);
      if (decoded is! Map) throw const FormatException();
      if (SensitiveData.containsSensitiveField(decoded)) {
        setState(
          () => _error =
              'Approval payloads are persisted. Reference a secret by ID; '
              'do not include passwords, tokens, or credentials.',
        );
        return;
      }
      Navigator.pop(
        context,
        _ChangeDraft(
          actionType: _typeCtrl.text.trim(),
          reason: _reasonCtrl.text.trim(),
          payload: Map<String, dynamic>.from(decoded),
        ),
      );
    } on FormatException {
      setState(() => _error = 'Payload must be a JSON object.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Propose governed change'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _typeCtrl,
              decoration: const InputDecoration(
                labelText: 'Action type',
                helperText: 'Must match an action enabled by the server.',
              ),
              validator: (value) =>
                  value?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Business justification / ticket',
              ),
              maxLines: 2,
              validator: (value) =>
                  value?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _payloadCtrl,
              decoration: const InputDecoration(labelText: 'Payload JSON'),
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Propose')),
    ],
  );
}
