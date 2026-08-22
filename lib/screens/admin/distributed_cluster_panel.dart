import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

part 'distributed_cluster_panel_view.dart';

/// Distributed-cluster (Tier B) control-plane panel.
///
/// Renders the signing fleet (one key per replica, aggregated through the
/// etcd key registry), the readiness checks for the distributed control
/// plane (etcd registry, invalidation bus, key aggregation), the backend
/// module map, and a self-test that exercises cross-replica token
/// validation through the load balancer.
class DistributedClusterPanel extends StatefulWidget {
  final SnaplinkAdminApi api;
  const DistributedClusterPanel({super.key, required this.api});
  @override
  State<DistributedClusterPanel> createState() => _PanelState();
}

class _ClusterCheck {
  final String label;
  final bool passed;
  final String detail;
  const _ClusterCheck(this.label, this.passed, this.detail);
}

class _PanelState extends State<DistributedClusterPanel> {
  Map<String, dynamic>? _readyz;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _keys;
  List<String> _jwksKids = const [];
  List<_ClusterCheck>? _testResults;
  bool _testing = false;
  Timer? _autoRefresh;

  static const _distributedReadyzChecks = [
    'etcd-signing-key-registry',
    'invalidation-bus',
    'signing-key-aggregation',
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  String _t(String source, [Map<String, Object?> values = const {}]) =>
      AppStrings.forLocale(
        AppSettings.instance.locale,
      ).translate(source, values);

  Future<Map<String, dynamic>> _quiet(String path) =>
      widget.api.get(path).catchError((_) => <String, dynamic>{});

  Future<void> _refresh() async {
    final results = await Future.wait([
      _quiet('/readyz'),
      _quiet('/api/v1/status'),
      _quiet('/api/v1/admin/keys'),
      _quiet('/.well-known/jwks.json'),
    ]);
    if (!mounted) return;
    setState(() {
      _readyz = results[0] as Map<String, dynamic>?;
      _status = results[1] as Map<String, dynamic>?;
      _keys = results[2] as Map<String, dynamic>?;
      _jwksKids =
          ((results[3] as Map<String, dynamic>?)?['keys'] as List?)
              ?.map((k) => (k as Map)['kid']?.toString() ?? '')
              .where((k) => k.isNotEmpty)
              .toList() ??
          const [];
    });
  }

  List<Map<String, dynamic>> get _signingKeys =>
      ((_keys?['keys'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  Future<void> _runSelfTest() async {
    setState(() {
      _testing = true;
      _testResults = null;
    });
    final results = <_ClusterCheck>[];

    // 1. Fleet aggregation: exactly one active key, peers adopted verify-only.
    final keys = _signingKeys;
    final active = keys.where((k) => k['state'] == 'active').length;
    final total = keys.length;
    final fleetOk = total >= 2 && active == 1;
    final fleetDetail = fleetOk
        ? _t('Registry aggregation OK: {n} keys', {'n': total})
        : (total == 0
              ? _t('No signing keys reported')
              : _t('Expected >= 2 keys for a multi-replica fleet'));
    results.add(_ClusterCheck(_t('Fleet aggregation'), fleetOk, fleetDetail));

    // 2. Cross-replica token validation: 5 probes through the LB; every
    // request may land on a different replica, so any 401 means the
    // replicas disagree about this token's key.
    var unauthorized = 0;
    // Bounded retry probe (5 attempts): the await is intentional —
    // replicas may disagree about this token's key (not an N+1 list).
    for (var i = 0; i < 5; i++) {
      try {
        await widget.api.get('/api/v1/admin/endpoints');
      } catch (_) {
        unauthorized++;
      }
    }
    results.add(
      _ClusterCheck(
        _t('Cross-replica token validation'),
        unauthorized == 0,
        unauthorized == 0
            ? _t('5/5 probes authorized')
            : _t('{n} of 5 probes unauthorized', {'n': unauthorized}),
      ),
    );

    // 3. Distributed control plane (etcd registry + bus + aggregation).
    final checks = (_readyz?['checks'] as Map?) ?? const {};
    final failing = _distributedReadyzChecks
        .where((name) => checks[name] != 'ok')
        .toList();
    results.add(
      _ClusterCheck(
        _t('Control plane checks'),
        failing.isEmpty,
        failing.isEmpty
            ? _t('Distributed checks healthy')
            : _t('{n} distributed check(s) failing', {'n': failing.length}),
      ),
    );

    // 4. Backend modules (per-store ping from /api/v1/status).
    final modules = (_status?['modules'] as Map?) ?? const {};
    final badModules = modules.entries
        .where((e) => e.value.toString() != 'ok')
        .map((e) => e.key)
        .toList();
    results.add(
      _ClusterCheck(
        _t('Backend module checks'),
        badModules.isEmpty,
        badModules.isEmpty
            ? _t('All backends reachable')
            : _t('{n} backend module(s) failing', {'n': badModules.length}),
      ),
    );

    if (!mounted) return;
    setState(() {
      _testResults = results;
      _testing = false;
    });
  }

  Widget _verifyOnlyWrap(List<dynamic> verifyOnly) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final k in verifyOnly) _kidChip('', k, false)],
  );

  Widget _readyzWrap(BuildContext context, Map<dynamic, dynamic> checks) =>
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final name in _distributedReadyzChecks)
            _statusChip(context, name, checks[name]?.toString()),
        ],
      );

  Widget _modulesWrap(BuildContext context, Map<dynamic, dynamic> modules) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in modules.entries)
            _statusChip(context, e.key, e.value?.toString()),
        ],
      );

  @override
  Widget build(BuildContext context) => _buildClusterPanel(context);

  Widget _kidChip(String label, Map<String, dynamic> key, bool active) {
    final kid = key['kid']?.toString() ?? '—';
    final alg = key['alg']?.toString() ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          LocalizedText(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
        ],
        Chip(
          avatar: Icon(
            active ? Icons.verified_user : Icons.people_outline,
            size: 16,
            color: active ? AppColors.success : AppColors.muted,
          ),
          label: Text('$kid ${alg.isNotEmpty ? '($alg)' : ''}'),
          visualDensity: VisualDensity.compact,
          backgroundColor: active
              ? AppColors.success.withValues(alpha: 0.05)
              : null,
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context, String name, String? value) {
    final ok = value == 'ok';
    // R29：dark 下 danger 提亮（2.26→5.29:1 ≥AA 非文本），浅色恒等。
    final danger = AppColors.semanticFor(
      Theme.of(context).brightness,
      AppColors.danger,
    );
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle : Icons.error,
        size: 16,
        color: ok ? AppColors.success : danger,
      ),
      label: Text(name),
      visualDensity: VisualDensity.compact,
      backgroundColor: ok
          ? AppColors.success.withValues(alpha: 0.05)
          : AppColors.danger.withValues(alpha: 0.05),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
