import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'admin_route.dart';
import 'admin_navigation.dart';
import 'break_glass_widgets.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Break Glass (emergency access) management tab.
///
/// Allows operators to create, list, approve, revoke, and impersonate
/// break-glass sessions for emergency support access.
class BreakGlassTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const BreakGlassTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<BreakGlassTab> createState() => _BreakGlassTabState();
}

class _BreakGlassTabState extends State<BreakGlassTab> {
  static const _basePath = '/api/v1/admin/break-glass';

  final _targetCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _scope = 'readonly';
  String? _ttl;
  bool _requireApproval = false;
  String? _tenantId;

  List<Map<String, dynamic>> _sessions = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  late final void Function() _cancelPopState;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    // The dashboard mounts this tab under the "emergency-access" module id;
    // the API base path is /api/v1/admin/break-glass.
    if (route.module != AdminModuleId.emergencyAccess) return;
    if (route.isNew) {
      _create();
    }
  }

  @override
  void dispose() {
    _cancelPopState();
    _targetCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_basePath);
      final items =
          data['sessions'] ??
          data['grants'] ??
          data['items'] ??
          data['break_glass'] ??
          [];
      if (!mounted) return;
      setState(() {
        _sessions = (items as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is SnaplinkAdminApiError
            ? e.toString()
            : 'Could not load break-glass sessions.';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final target = _targetCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();
    if (target.isEmpty || reason.isEmpty) {
      setState(() => _error = 'Target user and reason are required.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Create emergency-access grant?',
      message:
          'Create a $_scope break-glass grant for $target'
          '${_requireApproval ? ' pending independent approval' : ' that may become active immediately'}? '
          'Reason: $reason',
      confirmLabel: 'Create grant',
      destructive: true,
      confirmText: target,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(_basePath, {
        'target_user_id': target,
        'reason': reason,
        'scope': _scope,
        if (_ttl != null && _ttl!.isNotEmpty)
          'ttl_seconds': int.tryParse(_ttl!),
        if (_requireApproval) 'require_approval': true,
        if (_tenantId != null && _tenantId!.isNotEmpty) 'tenant_id': _tenantId,
      });
      if (!mounted) return;
      _targetCtrl.clear();
      _reasonCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Break-glass session created.')),
      );
      if (mounted) AdminRoute.go('emergency-access');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to create break-glass session.');
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _approve(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Approve?',
      message: 'Approve this break-glass request?',
      confirmLabel: 'Approve',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post('$_basePath/${Uri.encodeComponent(id)}/approve');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Break-glass approved.')),
      );
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _revoke(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke?',
      message: BreakGlassRevocationCopy.confirmation,
      confirmLabel: 'Revoke',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.delete(
        '$_basePath/${Uri.encodeComponent(id)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(BreakGlassRevocationCopy.result(response)),
        ),
      );
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _impersonate(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Impersonate?',
      message: 'Impersonate the target user? This action is audited.',
      confirmLabel: 'Impersonate',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final data = await widget.api.post(
        '$_basePath/${Uri.encodeComponent(id)}/impersonate',
      );
      if (!mounted) return;
      final token =
          data['access_token']?.toString() ?? data['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const LocalizedText('Impersonation token'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'This bearer is shown once and is not retained by the console.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  token,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const LocalizedText('I have saved it'),
              ),
            ],
          ),
        );
      } else {
        setState(
          () => _error =
              'Snaplink accepted the impersonation request but did not return '
              'a bearer. Do not retry until server state is verified.',
        );
      }
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: LocalizedText(
          'Break-glass access is not enabled on this replica.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Text(
          AppStrings.of(context).emergencyAccess,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Create audited, time-bound emergency access to user accounts.',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        const SizedBox(height: 16),
        BreakGlassRequestCard(
          targetController: _targetCtrl,
          reasonController: _reasonCtrl,
          scope: _scope,
          requireApproval: _requireApproval,
          mutating: _mutating,
          onScopeChanged: (value) => setState(() => _scope = value),
          onTtlChanged: (value) => _ttl = value,
          onRequireApprovalChanged: (value) =>
              setState(() => _requireApproval = value),
          onCreate: () => AdminRoute.go('emergency-access', action: 'new'),
        ),
        const SizedBox(height: 16),
        BreakGlassSessionsList(
          sessions: _sessions,
          loading: _loading,
          mutating: _mutating,
          onRefresh: _load,
          onOpen: (id) => AdminRoute.go('emergency-access', resourceId: id),
          onApprove: _approve,
          onImpersonate: _impersonate,
          onRevoke: _revoke,
        ),
      ],
    );
  }
}
