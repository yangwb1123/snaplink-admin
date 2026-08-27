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
import 'portal_security_contract.dart';
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
  String? _leavePendingTenantId;
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
      _available = true;
      _error = null;
      if (!preserveNotice) {
        _notice = null;
        _ok = false;
      }
    });
    try {
      final r = await widget.api.get(PortalPaths.organizations);
      if (!mounted) return;
      if (r.statusCode == 404) {
        setState(() {
          _available = false;
          _orgs = const [];
        });
        return;
      }
      if (r.statusCode != 200) {
        setState(() => _error = 'Could not load your organizations.');
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
    // Mark the row busy before opening confirmation as well. This closes the
    // small double-tap window between the row tap and the dialog result.
    if (tenantId.isEmpty ||
        _leavingTenantId != null ||
        _leavePendingTenantId != null) {
      return;
    }
    // Keep the lock separate from the spinner: a pending confirmation must
    // not leave an indeterminate progress animation behind the dialog.
    setState(() => _leavePendingTenantId = tenantId);
    try {
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
        _leavePendingTenantId = null;
        _leavingTenantId = tenantId;
        _notice = null;
        _ok = false;
      });
      final response = await widget.api.delete(
        PortalPaths.organization(tenantId),
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
      if (mounted &&
          (_leavingTenantId == tenantId || _leavePendingTenantId == tenantId)) {
        setState(() {
          _leavingTenantId = null;
          _leavePendingTenantId = null;
        });
      }
    }
  }

  Future<void> _acceptInvite() async {
    if (_accepting) return;
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
      final r = await widget.api.post(PortalPaths.invitationAccept, {
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

  /// One organization row. Desktop keeps the compact relationship row; below
  /// 640 logical pixels it becomes an outlined card with a separate action
  /// line, so long tenant ids and both buttons never compete for one line.
  Widget _orgRow(Map<String, dynamic> org) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final tenantId = org['tenant_id']?.toString() ?? '';
    final role = org['role']?.toString() ?? 'member';
    final canManage = role == 'admin' && tenantId.isNotEmpty;
    final leaving = _leavingTenantId == tenantId;
    final actions = <Widget>[
      if (canManage)
        TextButton.icon(
          onPressed: _leavingTenantId != null || _leavePendingTenantId != null
              ? null
              : () => setState(() => _managedTenantId = tenantId),
          icon: const Icon(Icons.settings_outlined, size: 16),
          label: Text(context.tr('Manage')),
        ),
      TextButton.icon(
        onPressed:
            tenantId.isEmpty ||
                _leavingTenantId != null ||
                _leavePendingTenantId != null
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
    ];
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tenantId.isEmpty ? context.tr('Unknown') : tenantId,
          softWrap: true,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                context.tr(role),
                softWrap: true,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    final icon = Container(
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
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          if (narrow) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.55,
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: actions,
                  ),
                ],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: actions,
              ),
            ],
          );
        },
      ),
    );
  }
}
