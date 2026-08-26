import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/sparkline.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'usage_analytics_contract.dart';

part 'usage_analytics_tab_view.dart';

class UsageAnalyticsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const UsageAnalyticsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<UsageAnalyticsTab> createState() => _UsageAnalyticsTabState();
}

class _UsageAnalyticsTabState extends State<UsageAnalyticsTab> {
  static const _topPath = '/api/v1/admin/usage/top-tenants';
  static const _usagePath = '/api/v1/admin/tokens/usage';
  static const _subjectPath = '/api/v1/admin/tokens/subjects/{subject}';
  static const _linkedSessionsPath = '/api/v1/admin/sessions/linked/{subject}';

  /// 模块组色（tenants → amber）：页头与区块图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.usageAnalytics);

  final _startCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  Map<String, dynamic>? _topTenants;
  Map<String, dynamic>? _tokenUsage;
  Map<String, dynamic>? _subjectTokens;
  Map<String, dynamic>? _linkedSessions;
  String _period = 'day';
  String? _error;
  bool _loading = false;
  bool _subjectLoading = false;

  /// 分开保护总览与主体调查，避免旧响应覆盖新的筛选条件或主体。
  int _loadSeq = 0;
  int _subjectSeq = 0;

  bool _has(String path) =>
      widget.capabilities.has('GET', path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == 'GET' && endpoint.path == path,
      );

  @override
  void initState() {
    super.initState();
    _startCtrl.text = DateTime.now().toUtc().toIso8601String().split('T').first;
    _load();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _clientCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
      _topTenants = null;
      _tokenUsage = null;
    });
    final jobs = <Future<(String, Map<String, dynamic>?, Object?)>>[
      if (_has(_topPath))
        _read(
          'tenants',
          _topPath,
          query: {
            'period': _period,
            'start': _startCtrl.text.trim(),
            'limit': '20',
          },
        ),
      if (_has(_usagePath))
        _read(
          'tokens',
          _usagePath,
          query: {
            if (_clientCtrl.text.trim().isNotEmpty)
              'client_id': _clientCtrl.text.trim(),
          },
        ),
    ];
    final results = await Future.wait(jobs);
    if (!mounted || seq != _loadSeq) return;
    final errors = <String>[];
    setState(() {
      for (final r in results) {
        if (r.$3 != null) {
          errors.add('${r.$1}: ${r.$3}');
        } else if (r.$1 == 'tenants') {
          _topTenants = normalizeTopTenantsPayload(r.$2!);
        } else {
          _tokenUsage = r.$2;
        }
      }
      if (jobs.isEmpty) {
        _error = 'Usage analytics is not enabled.';
      } else if (errors.isNotEmpty) {
        _error = 'Some usage data is unavailable — ${errors.join(' · ')}';
      }
      _loading = false;
    });
  }

  Future<void> _inspectSubject() async {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'Enter a subject identifier.');
      return;
    }
    final seq = ++_subjectSeq;
    setState(() {
      _subjectLoading = true;
      _error = null;
      _subjectTokens = null;
      _linkedSessions = null;
    });
    final encoded = Uri.encodeComponent(subject);
    final results = await Future.wait([
      if (_has(_subjectPath))
        _read(
          'tokens',
          '/api/v1/admin/tokens/subjects/$encoded',
          query: {
            if (_clientCtrl.text.trim().isNotEmpty)
              'client_id': _clientCtrl.text.trim(),
          },
        ),
      if (_has(_linkedSessionsPath))
        _read('sessions', '/api/v1/admin/sessions/linked/$encoded'),
    ]);
    if (!mounted || seq != _subjectSeq) return;
    final errors = <String>[];
    setState(() {
      for (final r in results) {
        if (r.$3 != null) {
          errors.add('${r.$1}: ${r.$3}');
        } else if (r.$1 == 'tokens') {
          _subjectTokens = r.$2;
        } else {
          _linkedSessions = r.$2;
        }
      }
      if (errors.isNotEmpty) {
        _error = 'Some subject data is unavailable — ${errors.join(' · ')}';
      }
    });
    if (mounted && seq == _subjectSeq) {
      setState(() {
        if (results.isEmpty) _error = 'Subject investigation is not enabled.';
        _subjectLoading = false;
      });
    }
  }

  Future<(String, Map<String, dynamic>?, Object?)> _read(
    String key,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      return (key, await widget.api.get(path, query: query), null);
    } on SnaplinkAdminApiError catch (error) {
      return (key, null, error);
    } catch (error) {
      return (key, null, error);
    }
  }

  @override
  Widget build(BuildContext context) => _buildUsageAnalyticsTab(context);
}
