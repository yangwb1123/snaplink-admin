import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/status_chip.dart';

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
      .where(
        (entry) => entry.value != null && entry.value.toString().isNotEmpty,
      )
      .map((entry) => '${_humanize(entry.key)}: ${_displayValue(entry.value)}')
      .toList(growable: false);
}

List<String> accessPolicyScopeCeiling(Map<String, dynamic> policy) {
  final scopes = _jsonMap(policy['actions'])['restrict_scopes'];
  return scopes is List
      ? scopes.map((scope) => scope.toString()).toList(growable: false)
      : const [];
}

Map<String, dynamic> _jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

String _displayValue(Object? value) => value is List
    ? value.map((item) => item.toString()).join(', ')
    : value.toString();

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

  bool get _canConverge => widget.capabilities.endpoints.any(
    (endpoint) =>
        endpoint.method == 'POST' &&
        endpoint.path == accessPolicyConvergePath &&
        endpoint.feature != 'documented',
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
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load access policies.';
          _loading = false;
        });
      }
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
      setState(() {
        _convergence = result;
        _converging = false;
      });
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) {
        setState(() {
          _convergenceError = error.toString();
          _converging = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _convergenceError = 'Could not converge active sessions.';
          _converging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      AdminBreadcrumb(),
      _header(context),
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
      AsyncView<List<Map<String, dynamic>>>(
        loading: _loading,
        error: _error,
        data: _policies,
        onRetry: _load,
        emptyTitle: 'No access policies',
        emptySubtitle: 'No access policies configured for this server.',
        dataBuilder: (policies) =>
            Column(children: policies.map(_policyCard).toList(growable: false)),
      ),
    ],
  );

  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          AppStrings.of(context).accessPolicies,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      if (_canConverge)
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
      IconButton(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh'.localized,
      ),
    ],
  );

  Widget _policyCard(Map<String, dynamic> policy) {
    final enabled = policy['enabled'] == true;
    final conditions = accessPolicyConditionLabels(policy);
    final scopes = accessPolicyScopeCeiling(policy);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(enabled ? Icons.lock_outline : Icons.lock_open_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policy['name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (policy['dry_run'] == true)
                  const Chip(label: LocalizedText('Dry run')),
                if (!enabled) const Chip(label: LocalizedText('Disabled')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${'Priority'.localized}: ${policy['priority'] ?? 0}',
                ),
                const SizedBox(width: 8),
                _verdictChip(accessPolicyVerdict(policy)),
              ],
            ),
            const SizedBox(height: 8),
            if (conditions.isEmpty)
              const LocalizedText('No conditions (matches every session)')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: conditions
                    .map((label) => Chip(label: Text(label)))
                    .toList(growable: false),
              ),
            if (scopes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${'Scope ceiling'.localized}: ${scopes.join(', ')}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verdictChip(String verdict) {
    if (verdict == 'Deny') return StatusChip.failed(label: 'Deny');
    if (verdict == 'Allow') return StatusChip.active(label: 'Allow');
    return StatusChip.info(label: verdict);
  }

  Widget _convergenceCard(Map<String, dynamic> result) => _statusCard(
    'Convergence complete: ${result['scanned'] ?? 0} scanned, ${result['revoked'] ?? 0} revoked, ${result['step_up_marked'] ?? 0} marked for step-up, ${result['scopes_restricted'] ?? 0} scope ceilings reduced, ${result['failed'] ?? 0} failed.',
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
