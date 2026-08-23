import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';

import 'organization_admin_tab.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';

part 'organizations_tab_view.dart';

/// B2B organization membership: list + leave + accept an invitation token.
/// Ports the "Organizations" card / loadOrganizations() in app.js. app.js
/// hides the whole card when GET /me/organizations doesn't return 200 (the
/// TenantUserStore isn't wired); since this tab is a static NavigationRail
/// destination rather than a DOM element we can hide after the fact, we show
/// the tab always and render an explanatory empty state instead.
///
/// Layout: header → three-state body. Loading renders [SkeletonListTile],
/// "not available" (non-200) renders an [EmptyState] notEnabled variant,
/// failures render a retryable [PortalErrorCard], and an empty list renders
/// an [EmptyState] (loading/empty/error triad). Each row shows the tenant id
/// (API value, raw [Text]), the role meta, and Manage/Leave actions; leave is
/// confirmed via the shared [ConfirmDialog] and shows a per-row spinner.
class OrganizationsTab extends StatefulWidget {
  final PortalApi api;
  const OrganizationsTab({super.key, required this.api});

  @override
  State<OrganizationsTab> createState() => _OrganizationsTabState();
}

class _OrganizationsTabState extends State<OrganizationsTab> {
  bool _loading = true;
  bool _available = true;
  String? _error;
  String? _notice;
  bool _ok = false;
  List<Map<String, dynamic>> _orgs = const [];

  final TextEditingController _inviteCtrl = TextEditingController();
  bool _accepting = false;
  String? _leavingTenantId;
  String? _managedTenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveNotice = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!preserveNotice) {
        _notice = null;
        _ok = false;
      }
    });
    try {
      final r = await widget.api.get('/me/organizations');
      if (!mounted) return;
      if (r.statusCode != 200) {
        setState(() {
          _available = false;
          _orgs = const [];
        });
        return;
      }
      final d = PortalApi.decode(r);
      setState(() {
        _available = true;
        _orgs =
            (d['organizations'] as List?)
                ?.whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .toList(growable: false) ??
            const [];
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your organizations.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leave(String tenantId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Leave organization?',
      message: context.tr(
        'You will lose access to {tenantId} and its organization resources '
        'until an administrator invites you again.',
        {'tenantId': tenantId},
      ),
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _leavingTenantId = tenantId;
      _notice = null;
      _ok = false;
    });
    try {
      final response = await widget.api.delete(
        '/me/organizations/${Uri.encodeComponent(tenantId)}',
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _notice = 'You have left the organization.';
          _ok = true;
        });
        await _load(preserveNotice: true);
      } else {
        setState(() {
          _notice = 'Could not leave the organization.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = 'Could not leave the organization.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) setState(() => _leavingTenantId = null);
    }
  }

  Future<void> _acceptInvite() async {
    final token = _inviteCtrl.text.trim();
    if (token.isEmpty) {
      setState(() {
        _notice = 'Paste an invitation token.';
        _ok = false;
      });
      return;
    }
    setState(() {
      _accepting = true;
      _notice = null;
      _ok = false;
    });
    try {
      final r = await widget.api.post('/me/invitations/accept', {
        'token': token,
      });
      if (!mounted) return;
      if (r.statusCode == 404) {
        setState(() {
          _notice = 'Invitations are not enabled.';
          _ok = false;
        });
      } else if (r.statusCode != 200) {
        setState(() {
          _notice = 'That invitation was not accepted.';
          _ok = false;
        });
      } else {
        _inviteCtrl.clear();
        setState(() {
          _notice = 'You have joined the organization.';
          _ok = true;
        });
        await _load(preserveNotice: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = 'Request failed.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _closeOrganizationAdmin() {
    setState(() => _managedTenantId = null);
  }

  @override
  Widget build(BuildContext context) => _buildOrganizationsTab(context);

  /// One organization row: brand-tinted tenant icon, tenant id (API value,
  /// raw [Text]), role meta, and trailing Manage (admin only) / danger
  /// Leave actions with a per-row busy spinner.
  Widget _orgRow(Map<String, dynamic> org) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final tenantId = org['tenant_id']?.toString() ?? '';
    final role = org['role']?.toString() ?? 'member';
    final canManage = role == 'admin' && tenantId.isNotEmpty;
    final leaving = _leavingTenantId == tenantId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              canManage
                  ? Icons.admin_panel_settings_outlined
                  : Icons.business_outlined,
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenantId.isEmpty ? context.tr('Unknown') : tenantId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.tr(role),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canManage)
            TextButton.icon(
              onPressed: () => setState(() => _managedTenantId = tenantId),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: Text(context.tr('Manage')),
            ),
          TextButton.icon(
            onPressed: tenantId.isEmpty || _leavingTenantId != null
                ? null
                : () => _leave(tenantId),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: leaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout, size: 16),
            label: Text(context.tr('Leave')),
          ),
        ],
      ),
    );
  }
}
