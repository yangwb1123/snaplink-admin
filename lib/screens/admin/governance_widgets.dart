import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/screens/admin/admin_ops_helpers.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/timeline_list.dart';
import 'governance_models.dart';
/// Section wrapper used in governance views (title + optional accent icon).
class GovernanceSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  final Color? accent;
  const GovernanceSection({super.key, required this.title, required this.children, this.icon, this.accent});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 18, color: accent), const SizedBox(width: 8)],
          Flexible(
            child: LocalizedText(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ]),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}
/// A card wrapper used in governance views.
class GovernanceCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const GovernanceCard({super.key, this.title, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            LocalizedText(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    ),
  );
}
/// A card displaying JSON data with a copy button.
class GovernanceJsonCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  const GovernanceJsonCard({super.key, required this.title, required this.data});
  @override
  Widget build(BuildContext context) {
    final jsonText = const JsonEncoder.withIndent('  ').convert(SensitiveData.redact(data));
    return GovernanceCard(
      title: title,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: SelectableText(jsonText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: LocalizedText('JSON copied.')));
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const LocalizedText('Copy JSON'),
          ),
        ),
      ],
    );
  }
}
/// Error banner: danger card + dynamic text (API values are never i18n
/// keys — X10) + retry action (X4).
class GovernanceErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  const GovernanceErrorBanner({super.key, required this.error, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Card(
      margin: EdgeInsets.zero,
      color: AppColors.danger.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(color: AppColors.danger))),
          if (onRetry != null)
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const LocalizedText('Retry'),
            ),
        ]),
      ),
    ),
  );
}
/// A read-only governance source group: per-spec refresh + JSON evidence
/// cards. Not-enabled state uses the shared EmptyState (X2/X8).
class GovernanceReadSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<GovernanceReadSpec> specs;
  final Map<String, Map<String, dynamic>> data;
  final bool loading;
  final Color accent;
  final void Function(GovernanceReadSpec spec) onRefresh;
  const GovernanceReadSection({super.key, required this.title, required this.icon, required this.specs, required this.data, required this.loading, required this.accent, required this.onRefresh});
  @override
  Widget build(BuildContext context) => GovernanceSection(
    title: title,
    icon: icon,
    accent: accent,
    children: [
      if (specs.isEmpty)
        const EmptyState(variant: EmptyStateVariant.notEnabled, compact: true, title: 'This feature is not enabled on the connected replica.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final spec in specs)
              OutlinedButton.icon(
                onPressed: loading ? null : () => onRefresh(spec),
                icon: Icon(spec.icon, size: 18, color: accent),
                label: LocalizedText('Refresh {spec_title}', args: {'spec_title': spec.title}),
              ),
          ],
        ),
      for (final spec in specs)
        if (data.containsKey(spec.key))
          GovernanceJsonCard(title: spec.title, data: data[spec.key]!),
    ],
  );
}
/// Audit investigation panel: query builder + results + facets. The wire
/// semantics (AuditQuery → toQueryParameters → trio endpoints) live in the
/// tab; this widget only presents the surface.
class GovernanceAuditPanel extends StatelessWidget {
  final TextEditingController queryController;
  final bool enabled;
  final bool loading;
  final Color accent;
  final VoidCallback onQuery;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? facets;
  const GovernanceAuditPanel({super.key, required this.queryController, required this.enabled, required this.loading, required this.accent, required this.onQuery, this.result, this.facets});
  @override
  Widget build(BuildContext context) => GovernanceSection(
    title: 'Audit investigation',
    icon: Icons.manage_search,
    accent: accent,
    children: [
      if (!enabled)
        const EmptyState(variant: EmptyStateVariant.notEnabled, compact: true, title: 'Audit querying is not enabled on the connected replica.')
      else ...[
        TextField(
          controller: queryController,
          maxLines: 3,
          enabled: !loading,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            labelText: 'Audit filter JSON'.localized,
            helperText: 'Example: {"tenant_id":"acme","outcome":"failure","limit":100}'.localized,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: loading ? null : onQuery,
          icon: const Icon(Icons.manage_search),
          label: const LocalizedText('Query audit events'),
        ),
        if (result != null) ...[const SizedBox(height: 8), _auditResults(context, result!)],
        if (facets != null) ...[const SizedBox(height: 4), GovernanceJsonCard(title: 'Matching audit facets', data: facets!)],
      ],
    ],
  );
}
/// Audit event feed: EmptyState for no matches (X8), timeline rows with
/// semantic outcome colors (X9), API values via Text (X1/X10).
Widget _auditResults(BuildContext context, Map<String, dynamic> result) {
  final rawEvents = result['events'];
  final events = rawEvents is List
      ? rawEvents.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const <Map<String, dynamic>>[];
  final count = result['count'] ?? events.length;
  return GovernanceCard(
    children: [
      LocalizedText('Audit results ({count})', args: {'count': count}, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (events.isEmpty)
        const EmptyState(variant: EmptyStateVariant.noMatch, compact: true, title: 'No matching events.')
      else ...[
        TimelineList(items: [for (final event in events.take(20)) _timelineItem(event)]),
        if (events.length > 20)
          LocalizedText('{count} more results present.', args: {'count': events.length - 20}),
      ],
    ],
  );
}
TimelineItem _timelineItem(Map<String, dynamic> event) {
  final (icon, color) = _outcomeStyle(event['outcome']?.toString());
  return TimelineItem(
    icon: icon,
    color: color,
    title: event['type']?.toString() ?? event['id']?.toString() ?? 'Event',
    subtitle: '${event['timestamp'] ?? event['created_at'] ?? ''} ${event['outcome'] ?? ''}'.trim(),
  );
}

(IconData, Color) _outcomeStyle(String? outcome) => switch (outcome?.toLowerCase()) {
  'success' || 'ok' || 'approved' || 'completed' => (Icons.check_circle, AppColors.success),
  'failure' || 'failed' || 'denied' || 'rejected' || 'error' => (Icons.cancel, AppColors.danger),
  'pending' || 'proposed' => (Icons.hourglass_top, AppColors.warning),
  'degraded' || 'warning' => (Icons.warning_amber, AppColors.warning),
  _ => (Icons.help_outline, AppColors.muted),
};
/// Governed write composer: operation picker + JSON body + exact-phrase
/// confirmation. Pre-flight validation (ID, JSON, sensitive fields, typed
/// confirmation, destructive dialog) happens here; the tab owns the wire.
class GovernanceWritePanel extends StatefulWidget {
  final List<GovernanceWriteOperation> operations;
  final bool writing;
  final Color accent;
  final Future<String?> Function(String method, String path, Map<String, dynamic> body, String label) onWrite;
  const GovernanceWritePanel({super.key, required this.operations, required this.writing, required this.accent, required this.onWrite});
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
    if (mounted) setState(() {});
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
        setState(() => _error = 'Enter the affected snapshot, release, or change ID.');
        return;
      }
      path = path.replaceAll(':id', Uri.encodeComponent(id));
    }
    final body = _jsonBody();
    if (body == null) return;
    if (SensitiveData.containsSensitiveField(body)) {
      setState(() => _error = 'Generic governance payloads are retained in reports and approval records. Do not include passwords, tokens, or private keys.');
      return;
    }
    if (!await _confirmed(path)) return;
    final error = await widget.onWrite(_op.method, path, body, _op.label);
    if (!mounted) return;
    if (error != null) setState(() => _error = error);
  }
  Map<String, dynamic>? _jsonBody() {
    try {
      final value = jsonDecode(_writeBody.text.trim().isEmpty ? '{}' : _writeBody.text);
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      // Invalid JSON; handled below
    }
    setState(() => _error = 'Request body must be a JSON object.');
    return null;
  }
  Future<bool> _confirmed(String resolvedPath) async {
    final required = AdminOpsHelpers.writeConfirmation(_op.method, resolvedPath);
    if (_confirm.text.trim() != required) {
      setState(() => _error = 'Type the exact confirmation phrase: $required');
      return false;
    }
    final confirmed = await ConfirmDialog.show(context, title: 'Confirm', message: 'Run ${_op.label}?', confirmLabel: 'Run operation', destructive: true);
    _confirm.clear();
    return confirmed;
  }
  @override
  Widget build(BuildContext context) {
    if (widget.operations.isEmpty) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled, compact: true, title: 'This feature is not enabled on the connected replica.');
    }
    final selected = widget.operations.contains(_op) ? _op : widget.operations.first;
    if (_op != selected) _op = selected;
    return GovernanceSection(
      title: 'Governed write composer',
      icon: Icons.edit,
      accent: widget.accent,
      children: [
        const LocalizedText('Use this for snapshots, deployments, disaster recovery, retention, and two-person change control.'),
        const SizedBox(height: 8),
        if (_error != null) ...[GovernanceErrorBanner(error: _error!), const SizedBox(height: 8)],
        DropdownButtonFormField<GovernanceWriteOperation>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Operation'.localized),
          items: [for (final item in widget.operations) DropdownMenuItem(value: item, child: Text(item.label))],
          onChanged: widget.writing ? null : (value) => setState(() {
                _op = value!;
                _resourceId.clear();
                _writeBody.text = value.example;
                _confirm.clear();
              }),
        ),
        if (selected.path.contains(':id')) ...[
          const SizedBox(height: 12),
          TextField(controller: _resourceId, decoration: InputDecoration(labelText: 'Resource ID'.localized)),
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
        TextField(
          controller: _confirm,
          enabled: !widget.writing,
          decoration: InputDecoration(labelText: 'Exact write confirmation'.localized, helperText: _confirmationHint),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.writing ? null : _run,
          icon: widget.writing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.warning_amber),
          label: LocalizedText('Run {selected_label}', args: {'selected_label': selected.label}),
        ),
      ],
    );
  }
}

