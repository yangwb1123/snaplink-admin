import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/info_row.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'admin_navigation.dart';
import 'break_glass_widgets.dart';

/// Emergency (break-glass) access session detail.
/// URL: /admin/emergency-access/{id}[/approve|/reject]
class BreakGlassDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final String sessionId;

  const BreakGlassDetailScreen({
    super.key,
    required this.api,
    required this.sessionId,
  });

  @override
  State<BreakGlassDetailScreen> createState() => _BreakGlassDetailScreenState();
}

class _BreakGlassDetailScreenState extends State<BreakGlassDetailScreen> {
  Map<String, dynamic>? _session;
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.emergencyAccess);

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(_onPopState);
    _load();
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetchSession();
      if (!mounted) return;
      setState(() {
        _session = result;
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

  Future<Map<String, dynamic>?> _fetchSession() async {
    // Snaplink publishes only the collection GET for break-glass sessions;
    // there is no detail GET. Filter the collection instead of issuing a
    // guaranteed 404 before every detail view.
    final response = await widget.api.get('/api/v1/admin/break-glass');
    final raw =
        response['sessions'] ??
        response['grants'] ??
        response['items'] ??
        response['break_glass'];
    if (raw is! List) return null;
    for (final value in raw.whereType<Map>()) {
      if (value['id']?.toString() == widget.sessionId) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalizedText(
        'Emergency Access: {widget_sessionId}',
        args: {'widget_sessionId': widget.sessionId},
      ),
      leading: IconButton(
        tooltip: 'Back'.localized,
        icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.go('emergency-access'),
      ),
    ),
    body: _loading
        ? const SkeletonListTile(itemCount: 3)
        : _error != null
        ? _errorView(context)
        : _session == null
        ? const EmptyState(
            variant: EmptyStateVariant.empty,
            title: 'Break-glass session not found.',
          )
        : Column(
            children: [
              AdminBreadcrumb(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoCard(context),
                      const SizedBox(height: 16),
                      ..._pendingActionCards(),
                      const SizedBox(height: 16),
                      _auditCard(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );

  bool get _isPending => _session?['status']?.toString() == 'pending';

  List<Widget> _pendingActionCards() => [
    if (_isPending) _actionsCard(context),
  ];

  /// 加载失败三态之一：统一 ErrorStateView（图标 + 标题 + 明细 + 重试）。
  Widget _errorView(BuildContext context) =>
      ErrorStateView(message: _error!, onRetry: _load);

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_outlined, size: 28, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeader(
                  'Break-Glass Session',
                  action: _statusChip(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LocalizedText(
            'ID: {id}',
            args: {'id': widget.sessionId},
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(),
          InfoRow(
            label: 'Requested by',
            value: _session?['requested_by']?.toString() ?? '—',
          ),
          InfoRow(label: 'Reason', value: _session?['reason']?.toString() ?? '—'),
          InfoRow(
            label: 'Target role',
            value: _session?['target_role']?.toString() ?? '—',
          ),
          InfoRow(
            label: 'Expires',
            value: _session?['expires_at']?.toString() ??
                _session?['expiry']?.toString() ??
                '—',
          ),
        ],
      ),
    ),
  );

  Widget _statusChip() {
    final status = _session?['status']?.toString() ?? 'unknown';
    return switch (status) {
      'active' => StatusChip.active(label: 'Active'),
      'approved' => StatusChip.active(label: 'Approved'),
      'pending' => StatusChip.pending(label: 'Pending'),
      'rejected' => StatusChip.failed(label: 'Rejected'),
      _ => StatusChip.unknown(label: status),
    };
  }

  Widget _actionsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Actions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _mutating ? null : () => _approve(),
                  icon: const Icon(Icons.check),
                  label: const LocalizedText('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _mutating ? null : () => _reject(),
                  icon: const Icon(Icons.close),
                  label: const LocalizedText('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _auditCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Audit Trail'),
          const SizedBox(height: 8),
          if (_session?['audit'] != null)
            ...((_session!['audit'] as List?) ?? []).map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${entry['action'] ?? ''} by ${entry['actor'] ?? ''} at ${entry['timestamp'] ?? ''}',
                ),
              ),
            )
          else
            const LocalizedText('No audit entries'),
        ],
      ),
    ),
  );

  Future<void> _approve() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Approve emergency access?',
      message: 'Grant ${_session?['requested_by'] ?? ''} access?',
      destructive: true,
      confirmText: widget.sessionId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/break-glass/${Uri.encodeComponent(widget.sessionId)}/approve',
        {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LocalizedText('Approved')));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _reject() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke emergency access?',
      message: BreakGlassRevocationCopy.confirmation,
      destructive: true,
      confirmText: widget.sessionId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      final response = await widget.api.delete(
        '/api/v1/admin/break-glass/${Uri.encodeComponent(widget.sessionId)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(BreakGlassRevocationCopy.result(response)),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'emergency-access') return;
  }

  void _onPopState() {
    if (mounted) _handleRoute();
  }
}
