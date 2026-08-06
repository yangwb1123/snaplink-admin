import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'tenant_form_dialog.dart';
import 'tenant_branding_tab.dart';
import 'tenant_detail_tabs.dart';
import 'tenant_residency_summary.dart';
import 'usage_analytics_contract.dart';

/// Tenant detail screen with sub-resource tabs.
/// URL: /admin/tenants/{id}[/{subresource}]
class TenantDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String tenantId;
  final SnaplinkAdminCapabilities capabilities;

  const TenantDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.tenantId,
    required this.capabilities,
  });

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  Map<String, dynamic>? _tenant;
  List<dynamic> _members = [];
  List<dynamic> _invitations = [];
  Map<String, dynamic>? _usage;
  final Map<String, String> _sectionErrors = {};
  String? _error;
  bool _loading = true;
  int _tabIndex = 0;
  late final void Function() _cancelPopState;

  static const _tabSpecs = [
    ('members', 'Members', Icons.people, 'GET', '/api/v1/admin/tenants/:id/members'),
    ('invitations', 'Invitations', Icons.mail_outline, 'GET', '/api/v1/admin/tenants/:id/invitations'),
    ('usage', 'Usage', Icons.bar_chart, 'GET', '/api/v1/admin/tenants/:id/usage'),
    ('branding', 'Branding', Icons.palette_outlined, 'GET', '/api/v1/admin/branding'),
  ];

  /// Tabs backed by a runtime-inventory endpoint; while the inventory is
  /// still loading (empty) every tab stays visible.
  List<(String, String, IconData)> get _tabs =>
      widget.capabilities.endpoints.isEmpty
      ? [for (final s in _tabSpecs) (s.$1, s.$2, s.$3)]
      : [
          for (final s in _tabSpecs)
            if (widget.capabilities.has(s.$4, s.$5)) (s.$1, s.$2, s.$3),
        ];

  @override
  void initState() {
    super.initState();
    _load();
    _initTabFromRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _initTabFromRoute();
    });
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  void _initTabFromRoute() {
    final route = AdminRoute.current();
    if (route.resourceId != widget.tenantId) return;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        setState(() => _tabIndex = i);
        return;
      }
    }
  }

  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go(
      'tenants',
      resourceId: widget.tenantId,
      subresource: subresource,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tid = Uri.encodeComponent(widget.tenantId);
      final tenant = await widget.client.getTenant(widget.tenantId);
      final sections = <String, Map<String, dynamic>>{};
      for (final tab in _tabs) {
        if (tab.$1 == 'branding') continue; // self-loading tab
        final spec = _tabSpecs.firstWhere((s) => s.$1 == tab.$1);
        sections[tab.$1] = await _optionalGet(
          tab.$1,
          spec.$5.replaceAll(':id', tid),
        );
      }
      if (!mounted) return;
      setState(() {
        _tenant = tenant;
        _members = _firstList(sections['members'] ?? const {});
        _invitations = _firstList(sections['invitations'] ?? const {});
        _usage = normalizeTenantUsageRecord(sections['usage'] ?? const {});
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _optionalGet(String section, String path) async {
    try {
      final result = await widget.api.get(path);
      _sectionErrors.remove(section);
      return result;
    } catch (error) {
      _sectionErrors[section] = error.toString();
      return <String, dynamic>{};
    }
  }

  List<dynamic> _firstList(Map<String, dynamic> response) {
    for (final value in response.values) {
      if (value is List) return value;
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LocalizedText('Tenant: ${widget.tenantId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back'.localized,
          onPressed: () => AdminRoute.go('tenants'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit tenant'.localized,
            onPressed: () => _editTenant(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  LocalizedText(
                    'Failed to load',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const LocalizedText('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                AdminBreadcrumb(),
                Expanded(child: _buildContent(context)),
              ],
            ),
    );
  }

  Widget _buildContent(BuildContext context) => Column(
    children: [
      _tenantHeader(context),
      _tabBar(context),
      Expanded(child: _tabContent(context)),
    ],
  );

  Widget _tenantHeader(BuildContext context) =>
      TenantResidencySummary(tenant: _tenant, fallbackId: widget.tenantId);

  Widget _tabBar(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: LocalizedText('${_tabs[i].$2}  (${_countForTab(i)})'),
              selected: _tabIndex == i,
              onSelected: (_) => _selectTab(i, _tabs[i].$1),
            ),
          ),
      ],
    ),
  );

  String _countForTab(int i) {
    switch (i) {
      case 0:
        return '${_members.length}';
      case 1:
        return '${_invitations.length}';
      default:
        return '';
    }
  }

  Widget _tabContent(BuildContext context) {
    switch (_tabs[_tabIndex].$1) {
      case 'members':
        return TenantMembersTab(
          members: _members,
          error: _sectionErrors['members'],
          onRetry: _load,
          onRemove: _removeMember,
        );
      case 'invitations':
        return TenantInvitationsTab(
          invitations: _invitations,
          error: _sectionErrors['invitations'],
          onRetry: _load,
          onResend: _resendInvitation,
          onRevoke: _revokeInvitation,
        );
      case 'usage':
        return TenantUsageTab(
          usage: _usage ?? const {},
          error: _sectionErrors['usage'],
          onRetry: _load,
        );
      case 'branding':
        return TenantBrandingTab(api: widget.api, tenantId: widget.tenantId);
      default:
        return const Center(child: LocalizedText('Select a tab'));
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove member?',
      message: 'Remove $userId from tenant?',
      destructive: true,
      confirmText: userId,
    );
    if (!confirmed) return;
    try {
      await widget.api.delete(
        '/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/members/${Uri.encodeComponent(userId)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('Removed $userId')));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText('$e')));
      }
    }
  }

  Future<void> _resendInvitation(Map<String, dynamic> invitation) async {
    final email = invitation['email']?.toString() ?? '';
    if (email.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Resend invitation?',
      message:
          'Send a new invitation message to $email. Any previously issued '
          'pending invitation for the address may be replaced.',
      confirmLabel: 'Resend invitation',
    );
    if (!confirmed) return;
    try {
      await widget.api.post(
        '/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/invitations',
        {'email': email, 'role': invitation['role']?.toString() ?? 'member'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Invitation resent')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LocalizedText('Resend failed: $error')),
        );
      }
    }
  }

  Future<void> _revokeInvitation(String email) async {
    if (email.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke invitation?',
      message: 'Revoke this invitation?',
      destructive: true,
      confirmText: email,
    );
    if (!confirmed) return;
    try {
      await widget.api.delete(
        '/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/invitations/${Uri.encodeComponent(email)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Invitation revoked')),
      );
      _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LocalizedText('Revoke failed: $error')),
        );
      }
    }
  }

  Future<void> _editTenant(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          TenantFormDialog(client: widget.client, existing: _tenant),
    );
    if (result == true) _load();
  }
}
