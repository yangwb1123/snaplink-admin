import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/tight_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

part 'access_policies_tab_view.dart';

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
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
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
  static const _pageSize = 25;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _policies = const [];
  Map<String, dynamic>? _convergence;
  String? _error, _convergenceError, _sortColumn;
  String _verdictFilter = 'all', _statusFilter = 'all';
  bool _loading = false, _converging = false, _sortAscending = true;
  int _page = 1;

  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.accessPolicies);

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(accessPoliciesPath) ||
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_available) return;
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getStaleWhileRevalidate(
        accessPoliciesPath,
        onRefresh: (fresh) {
          if (mounted && seq == _reqSeq) {
            setState(() => _applyPolicies(fresh));
          }
        },
      );
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _applyPolicies(data);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted && seq == _reqSeq) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() => _error = 'Could not load access policies.');
      }
    } finally {
      if (mounted && seq == _reqSeq) setState(() => _loading = false);
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后再次渲染（R2）。
  void _applyPolicies(Map<String, dynamic> data) {
    final items = data['policies'] as List? ?? [];
    _policies = items
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    _page = 1;
  }

  List<Map<String, dynamic>> _visiblePolicies() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final rows = _policies.where((policy) {
      final verdict = accessPolicyVerdict(policy).toLowerCase();
      final verdictMatch = switch (_verdictFilter) {
        'allow' => verdict == 'allow',
        'deny' => verdict == 'deny',
        'step_up' => verdict.startsWith('require step-up'),
        _ => true,
      };
      final statusMatch = switch (_statusFilter) {
        'enabled' => policy['enabled'] == true,
        'disabled' => policy['enabled'] != true,
        'dry_run' => policy['dry_run'] == true,
        _ => true,
      };
      final text = policy.values.map((value) => value.toString()).join(' ');
      return verdictMatch &&
          statusMatch &&
          (query.isEmpty || text.toLowerCase().contains(query));
    }).toList();
    final sort = _sortColumn;
    if (sort != null) {
      rows.sort((a, b) {
        final result = _sortValue(a, sort).compareTo(_sortValue(b, sort));
        return _sortAscending ? result : -result;
      });
    }
    return rows;
  }

  String _sortValue(
    Map<String, dynamic> policy,
    String column,
  ) => switch (column) {
    'policy' => (policy['name'] ?? '').toString().toLowerCase(),
    'verdict' => accessPolicyVerdict(policy).toLowerCase(),
    'priority' => (policy['priority'] ?? 0).toString().padLeft(12, '0'),
    'conditions' => accessPolicyConditionLabels(policy).join(' ').toLowerCase(),
    'scope' => accessPolicyScopeCeiling(policy).join(' ').toLowerCase(),
    _ =>
      '${policy['enabled'] == true ? 0 : 1}${policy['dry_run'] == true ? 0 : 1}',
  };

  void _onSearchChanged(String _) => setState(() => _page = 1);

  void _onSort(String column) => setState(() {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    _page = 1;
  });

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _verdictFilter = 'all';
      _statusFilter = 'all';
      _page = 1;
    });
  }

  void _setVerdictFilter(String value) => setState(() {
    _verdictFilter = value;
    _page = 1;
  });

  void _setStatusFilter(String value) => setState(() {
    _statusFilter = value;
    _page = 1;
  });

  void _previousPage() => setState(() => _page--);
  void _nextPage() => setState(() => _page++);

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
      if (mounted) {
        setState(
          () => _convergenceError = 'Could not converge active sessions.',
        );
      }
    } finally {
      if (mounted) setState(() => _converging = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildAccessPoliciesTab(context);
}
