import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';

part 'threat_policies_tab_view.dart';

/// Threat detection policy management tab.
/// URLs: /admin/threat-policies, /admin/threat-policies/new, /admin/threat-policies/{id}/edit
class ThreatPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const ThreatPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<ThreatPoliciesTab> createState() => _ThreatPoliciesTabState();
}

class _ThreatPoliciesTabState extends State<ThreatPoliciesTab>
    with _ThreatPoliciesTabView {
  static const _path = '/api/v1/admin/threat-policies';
  @override
  final _formKey = GlobalKey<FormState>();
  @override
  List<Map<String, dynamic>> _policies = const [];
  @override
  String? _error;
  @override
  bool _loading = false, _mutating = false;

  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  @override
  Color get _accent => adminModuleIconColor(AdminModuleId.threatPolicies);

  @override
  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);

  @override
  void initState() {
    super.initState();
    _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  @override
  bool _editing = false;
  @override
  bool _creating = false;
  @override
  final _nameCtrl = TextEditingController();
  @override
  final _descCtrl = TextEditingController();
  @override
  final _rulesCtrl = TextEditingController();
  String? _editId;

  void _handleRoute() {
    final route = AdminRoute.current();
    _creating = route.isNew;
    _editing = route.isEdit;
    _editId = route.resourceId;
    if (_creating) {
      _nameCtrl.clear();
      _descCtrl.clear();
      _rulesCtrl.clear();
    }
    if (_editing && _editId != null) {
      final existing = _policies
          .where((p) => p['id']?.toString() == _editId)
          .firstOrNull;
      if (existing != null) {
        _nameCtrl.text = existing['name']?.toString() ?? '';
        _descCtrl.text = existing['description']?.toString() ?? '';
        _rulesCtrl.text =
            existing['rules']?.toString() ??
            existing['config']?.toString() ??
            '';
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cancelPopState();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  @override
  Future<void> _load() async {
    if (!_available) return;
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      final items = data['policies'] as List? ?? [];
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _policies = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        _handleRoute();
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = 'Could not load threat policies.';
          _loading = false;
        });
      }
    }
  }

  @override
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    final body = {
      'name': name,
      'description': _descCtrl.text.trim(),
      'rules': _rulesCtrl.text.trim(),
    };
    setState(() => _mutating = true);
    try {
      final pathName = _editing && _editId != null ? _editId! : name;
      await widget.api.put('$_path/${Uri.encodeComponent(pathName)}', body);
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: LocalizedText(
          _editing ? 'Policy updated.' : 'Policy created.',
        ),
      );
      if (mounted) AdminRoute.go('threat-policies');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Future<void> _delete(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete policy?',
      message: 'Delete this threat policy?',
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Policy deleted.'));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
}
