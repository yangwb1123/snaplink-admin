import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

const accessPoliciesPath = '/api/v1/admin/access-policies';
const accessPolicyConvergePath = '$accessPoliciesPath/converge';

String accessPolicyVerdict(Map<String, dynamic> policy) {
  final actions = _jsonMap(policy['actions']);
  if (actions['deny'] == true) return 'Deny';
  final stepUp = actions['require_step_up']?.toString() ?? '';
  if (stepUp.isNotEmpty) return 'Require step-up: $stepUp';
  return 'Allow';
}

List<String> accessPolicyConditionLabels(Map<String, dynamic> policy) {
  final conditions = _jsonMap(policy['conditions']);
  return conditions.entries
      .where((e) => e.value != null && e.value.toString().isNotEmpty)
      .map((e) => '${_humanize(e.key)}: ${_displayValue(e.value)}')
      .toList(growable: false);
}

List<String> accessPolicyScopeCeiling(Map<String, dynamic> policy) {
  final scopes = _jsonMap(policy['actions'])['restrict_scopes'];
  return scopes is List
      ? scopes.map((s) => s.toString()).toList(growable: false)
      : const [];
}

Map<String, dynamic> _jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

String _displayValue(Object? value) => value is List
    ? value.map((item) => item.toString()).join(', ')
    : value.toString();

/// 访问策略页：只读策略列表 + 存量会话收敛（POST /converge）。
class AccessPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const AccessPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<AccessPoliciesTab> createState() => _AccessPoliciesTabState();
}

class _AccessPoliciesTabState extends State<AccessPoliciesTab> {
  List<Map<String, dynamic>> _policies = const [];
  Map<String, dynamic>? _convergence;
  String? _error;
  String? _convergenceError;
  bool _loading = false;
  bool _converging = false;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.accessPolicies);

  bool get _available => widget.capabilities.hasAnyPathPrefix(accessPoliciesPath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(accessPoliciesPath);

  bool get _canConverge => widget.capabilities.endpoints.any(
    (e) =>
        e.method == 'POST' &&
        e.path == accessPolicyConvergePath &&
        e.feature != 'documented',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(accessPoliciesPath, forceRefresh: true);
      final items = data['policies'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _policies = items
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load access policies.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _converge() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Apply current policies?'),
        content: const LocalizedText(
          'This immediately re-evaluates active sessions. Sessions may be revoked, marked for step-up, or have their scope ceiling reduced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _converging = true;
      _convergenceError = null;
    });
    try {
      final result = await widget.api.post(accessPolicyConvergePath);
      if (!mounted) return;
      setState(() => _convergence = result);
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _convergenceError = error.toString());
    } catch (_) {
      if (mounted) setState(() => _convergenceError = 'Could not converge active sessions.');
    } finally {
      if (mounted) setState(() => _converging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const EmptyState(variant: EmptyStateVariant.notEnabled);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).accessPolicies,
          subtitle:
              'Priority-ordered session access decisions; converge applies '
              'them to active sessions.',
          onRefresh: _load,
          actions: [
            if (_canConverge) ...[
              FilledButton.icon(
                onPressed: _loading || _converging ? null : _converge,
                icon: _converging
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.policy_outlined),
                label: const LocalizedText('Apply to active sessions'),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (!_canConverge)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LocalizedText(
              'Active-session convergence is not advertised by this server.',
            ),
          ),
        if (_convergenceError != null)
          _statusCard(_convergenceError!, isError: true),
        if (_convergence != null) _convergenceCard(_convergence!),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _error != null)
          _ErrorBanner(error: _error!, onRetry: _load),
        if (!_loading && _error == null && _policies.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(
              compact: true,
              title: 'No access policies',
              subtitle: 'No access policies configured for this server.',
            ),
          ),
        if (!_loading && _error == null && _policies.isNotEmpty)
          _policiesCard(context),
      ],
    );
  }

  /// 策略列表卡：组色图标 + SectionHeader + AdminDataTable(compact)。
  Widget _policiesCard(BuildContext context) {
    final policies = _policies;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.policy_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader('Access Policies', count: policies.length),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              columns: [
                AdminDataColumn(
                  id: 'policy',
                  label: 'Policy'.localized,
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    policies[i]['name']?.toString() ?? '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'verdict',
                  label: 'Verdict'.localized,
                  width: 170,
                  cardDetail: true,
                  builder: (_, i) =>
                      _verdictChip(accessPolicyVerdict(policies[i])),
                ),
                AdminDataColumn(
                  id: 'priority',
                  label: 'Priority'.localized,
                  width: 100,
                  cardDetail: true,
                  builder: (_, i) =>
                      TableCellText('${policies[i]['priority'] ?? 0}', muted: true),
                ),
                AdminDataColumn(
                  id: 'conditions',
                  label: 'Conditions'.localized,
                  width: 260,
                  cardDetail: true,
                  builder: (_, i) {
                    final c = accessPolicyConditionLabels(policies[i]);
                    return TableCellText(
                      c.isEmpty
                          ? context.tr('No conditions (matches every session)')
                          : c.join(' · '),
                      muted: true,
                      maxLines: 2,
                    );
                  },
                ),
                AdminDataColumn(
                  id: 'scope',
                  label: 'Scope ceiling'.localized,
                  width: 220,
                  cardDetail: true,
                  builder: (_, i) {
                    final s = accessPolicyScopeCeiling(policies[i]);
                    return TableCellText(
                      s.isEmpty ? '—' : s.join(', '),
                      muted: true,
                      maxLines: 2,
                    );
                  },
                ),
                AdminDataColumn(
                  id: 'status',
                  label: '',
                  width: 170,
                  builder: (_, i) => _statusFlags(policies[i]),
                ),
              ],
              itemCount: policies.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verdictChip(String verdict) => switch (verdict) {
    'Deny' => StatusChip.failed(label: 'Deny'),
    'Allow' => StatusChip.active(label: 'Allow'),
    _ => StatusChip.info(label: verdict),
  };

  Widget _statusFlags(Map<String, dynamic> policy) {
    final flags = <Widget>[
      if (policy['dry_run'] == true) _flagChip('Dry run'),
      if (policy['enabled'] != true) _flagChip('Disabled'),
    ];
    return flags.isEmpty
        ? const SizedBox.shrink()
        : Wrap(spacing: 4, runSpacing: 4, children: flags);
  }

  Widget _flagChip(String label) => Chip(
    label: LocalizedText(label),
    labelStyle: const TextStyle(fontSize: 11),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _convergenceCard(Map<String, dynamic> result) => _statusCard(
    'Convergence complete: ${result['scanned'] ?? 0} scanned, '
    '${result['revoked'] ?? 0} revoked, ${result['step_up_marked'] ?? 0} '
    'marked for step-up, ${result['scopes_restricted'] ?? 0} scope ceilings '
    'reduced, ${result['failed'] ?? 0} failed.',
    isError: (result['failed'] as num?)?.toInt() != 0,
  );

  Widget _statusCard(String message, {required bool isError}) => Card(
    color: isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message),
    ),
  );
}

/// 错误横幅（X4 模式）：图标 + 消息（API 值走 Text）+ Retry。
class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error, style: const TextStyle(color: AppColors.danger)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const LocalizedText('Retry')),
        ],
      ),
    ),
  );
}
