import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/audit_query.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
import 'governance_models.dart';
import 'governance_widgets.dart';

part 'governance_tab_view.dart';

class GovernanceTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const GovernanceTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<GovernanceTab> createState() => _GovernanceTabState();
}

class _GovernanceTabState extends State<GovernanceTab> {
  // Trio literals live only in AuditReadClient (guard scan: trio-literal
  // ownership pin); the governance demo routes through the read client's
  // constants with AuditQuery-built parameters (guard scan 5).
  static const _auditPath = AuditReadClient.eventsPath;
  static const _facetPath = AuditReadClient.facetsPath;

  /// 模块组色（system → indigo）：页头与区块图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.governance);

  final _auditQuery = TextEditingController(text: '{"limit": 100}');
  final Map<String, Map<String, dynamic>> _data = {};
  String? _error;
  bool _loading = false;
  bool _writing = false;
  String _currentSection = 'all';
  late final void Function() _cancelPopState;
  static final _sections = [
    SectionDef(
      'all',
      'All',
      Icons.dashboard_outlined,
      color: adminModuleIconColor(AdminModuleId.governance),
    ),
    SectionDef(
      'audit',
      'Audit',
      Icons.search,
      color: adminModuleIconColor(AdminModuleId.governance),
    ),
    SectionDef(
      'compliance',
      'Compliance',
      Icons.verified_outlined,
      color: adminModuleIconColor(AdminModuleId.governance),
    ),
    SectionDef(
      'configuration',
      'Config',
      Icons.settings_outlined,
      color: adminModuleIconColor(AdminModuleId.governance),
    ),
    SectionDef(
      'lifecycle',
      'Lifecycle',
      Icons.swap_vert,
      color: adminModuleIconColor(AdminModuleId.governance),
    ),
    SectionDef(
      'write',
      'Write',
      Icons.edit_outlined,
      color: adminModuleIconColor(AdminModuleId.governance),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _initSectionFromRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _initSectionFromRoute();
    });
  }

  void _initSectionFromRoute() {
    final route = AdminRoute.current();
    final section = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_sections.any((s) => s.id == section)) {
      setState(() => _currentSection = section);
    }
  }

  void _selectSection(String section) {
    setState(() => _currentSection = section);
    if (section == 'all') {
      AdminRoute.go('governance');
    } else {
      AdminRoute.go('governance', subresource: section);
    }
  }

  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      widget.capabilities.endpoints.any(
        (endpoint) =>
            endpoint.method == method && _route(endpoint.path) == _route(path),
      ) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) =>
            endpoint.method == method && _route(endpoint.path) == _route(path),
      );
  String _route(String path) => path
      .replaceAllMapped(RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}'), (_) => ':id')
      .replaceAllMapped(RegExp(r':[A-Za-z_][A-Za-z0-9_]*'), (_) => ':id');

  @override
  void dispose() {
    _cancelPopState();
    _auditQuery.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final reads = governanceReadSpecs
        .where((spec) => _has('GET', spec.path))
        .toList(growable: false);
    if (reads.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
        reads.map((spec) async {
          try {
            return (
              key: spec.key,
              data: await widget.api.getStaleWhileRevalidate(
                spec.path,
                onRefresh: (fresh) {
                  if (mounted) {
                    setState(() => _data[spec.key] = _safe(fresh));
                  }
                },
              ),
              error: '',
            );
          } on SnaplinkAdminApiError catch (error) {
            return (
              key: spec.key,
              data: <String, dynamic>{},
              error: error.toString(),
            );
          }
        }),
      );
      if (!mounted) return;
      final failures = results
          .where((result) => result.error.isNotEmpty)
          .toList();
      setState(() {
        _data.addEntries(
          results
              .where((result) => result.error.isEmpty)
              .map((result) => MapEntry(result.key, _safe(result.data))),
        );
        if (failures.isNotEmpty) {
          _error =
              '${failures.length} optional governance source(s) could not be loaded.';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(GovernanceReadSpec spec) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getStaleWhileRevalidate(
        spec.path,
        onRefresh: (fresh) {
          if (mounted) setState(() => _data[spec.key] = _safe(fresh));
        },
      );
      if (mounted) setState(() => _data[spec.key] = _safe(response));
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _queryAudit() async {
    final query = _json(_auditQuery.text, 'Audit query');
    if (query == null) return;
    final AuditQuery auditQuery;
    try {
      auditQuery = AuditQuery.fromJson(query);
    } on AuditQueryParseException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final parameters = auditQuery.toQueryParameters();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = widget.api.get(_auditPath, query: parameters);
      final facets = _has('GET', _facetPath)
          ? widget.api.get(_facetPath, query: parameters)
          : null;
      final results = await Future.wait([events, ?facets]);
      if (mounted) {
        setState(() {
          _data['audit'] = _safe(results.first);
          if (facets != null) _data['facets'] = _safe(results.last);
        });
      }
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Wire half of the governed write: the panel pre-flights (ID/JSON/
  /// sensitive/typed-confirmation/dialog), this runs the mutation and
  /// returns a displayable error or null on success.
  Future<String?> _submitWrite(
    String method,
    String path,
    Map<String, dynamic> body,
    String label,
  ) async {
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      final result = method == 'POST'
          ? await widget.api.post(path, body)
          : await widget.api.delete(path, body);
      if (!mounted) return null;
      setState(() => _data['lastWrite'] = _safe(result));
      showAppSnackBar(
        context,
        content: LocalizedText('{op} completed.', args: {'op': label}),
      );
      await _refresh();
      return null;
    } on SnaplinkAdminApiError catch (error) {
      return error.toString();
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Map<String, dynamic>? _json(String source, String label) {
    try {
      final value = jsonDecode(source.trim().isEmpty ? '{}' : source);
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      // Invalid JSON; handled below
    }
    setState(() => _error = '$label must be a JSON object.');
    return null;
  }

  Map<String, dynamic> _safe(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(SensitiveData.redact(value)! as Map);

  @override
  Widget build(BuildContext context) => _buildGovernanceTab(context);
}
