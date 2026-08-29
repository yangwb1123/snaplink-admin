import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'user_device_security_panel.dart';
import 'user_detail_widgets.dart';

/// User detail screen with sub-resource tabs.
/// URL: /admin/users/{id}[/{subresource}]
class UserDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String userId;
  final SnaplinkAdminCapabilities capabilities;

  const UserDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.userId,
    required this.capabilities,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _sessions;
  Map<String, dynamic>? _consents;
  Map<String, dynamic>? _mfa;
  Map<String, dynamic>? _lifecycle;
  final Map<String, String> _sectionErrors = {};
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  int _tabIndex = 0;
  late final void Function() _cancelPopState;

  static const _tabSpecs = [
    (
      'sessions',
      'Sessions',
      Icons.devices,
      'GET',
      AdminPaths.userSessionsTemplate,
    ),
    (
      'consents',
      'Consents',
      Icons.checklist,
      'GET',
      AdminPaths.userConsentsTemplate,
    ),
    ('mfa', 'MFA', Icons.security, 'GET', AdminPaths.userMfaTemplate),
    (
      'lifecycle',
      'Lifecycle',
      Icons.route,
      'GET',
      AdminPaths.userLifecycleTemplate,
    ),
    (
      'device-security',
      'Device security',
      Icons.phonelink_lock,
      'GET',
      '/api/v1/admin/users/:id/devices',
    ),
  ];

  /// 模块强调色（identity 组 indigo-violet）。
  Color get _accent => adminModuleIconColor('users');

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
    if (route.resourceId != widget.userId) return;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) setState(() => _tabIndex = i);
    }
  }

  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go('users', resourceId: widget.userId, subresource: subresource);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.client.getUser(widget.userId);
      // 各 tab 端点并行加载（Future.wait，_optionalGet 内部容错）。
      final tabFutures = <String, Future<Map<String, dynamic>>>{};
      for (final tab in _tabs) {
        if (tab.$1 == 'device-security') continue; // self-loading panel
        tabFutures[tab.$1] = _optionalGet(tab.$1, _userTabPath(tab.$1));
      }
      final tabResults = await Future.wait(tabFutures.values);
      final sections = <String, Map<String, dynamic>>{
        for (var i = 0; i < tabFutures.keys.length; i++)
          tabFutures.keys.elementAt(i): tabResults[i],
      };
      if (!mounted) return;
      setState(() {
        _user = user;
        _sessions = sections['sessions'] ?? <String, dynamic>{};
        _consents = sections['consents'] ?? <String, dynamic>{};
        _mfa = sections['mfa'] ?? <String, dynamic>{};
        _lifecycle = sections['lifecycle'] ?? <String, dynamic>{};
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

  String _userTabPath(String tab) => switch (tab) {
    'sessions' => AdminPaths.userSessions(widget.userId),
    'consents' => AdminPaths.userConsents(widget.userId),
    'mfa' => AdminPaths.userMfa(widget.userId),
    'lifecycle' => AdminPaths.userLifecycle(widget.userId),
    _ => throw ArgumentError.value(tab, 'tab', 'Unsupported user tab'),
  };

  Future<Map<String, dynamic>> _optionalGet(String section, String path) async {
    try {
      final result = await widget.api.get(path, forceRefresh: true);
      _sectionErrors.remove(section);
      return result;
    } catch (error) {
      _sectionErrors[section] = error.toString();
      return <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          container: true,
          header: true,
          child: LocalizedText(
            'User: {widget_userId}',
            args: {'widget_userId': widget.userId},
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back'.localized,
          onPressed: () => AdminRoute.back('users'),
        ),
      ),
      body: _loading
          ? const SkeletonListTile(itemCount: 6)
          : _error != null
          ? ErrorStateView(
              title: 'Failed to load user',
              message: _error!,
              onRetry: _load,
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
      UserDetailHeader(user: _user),
      UserDetailTabBar(
        labels: [for (var i = 0; i < _tabs.length; i++) _tabLabel(i)],
        selectedIndex: _tabIndex,
        onSelected: (index) => _selectTab(index, _tabs[index].$1),
      ),
      Expanded(child: _tabContent(context)),
    ],
  );

  /// Tab label with count suffix ONLY when the count is > 0 — count ≤ 0
  /// renders the bare label (exact-match pins at
  /// user_detail_optional_resources_test.dart:71-72 stay green).
  String _tabLabel(int index) {
    final label = context.tr(_tabs[index].$2);
    final count = _countForTab(index);
    return count > 0 ? '$label  ($count)' : label;
  }

  int _countForTab(int index) {
    switch (_tabs[index].$1) {
      case 'sessions':
        return (_sessions?['sessions'] as List?)?.length ?? 0;
      case 'consents':
        return (_consents?['consents'] as List?)?.length ?? 0;
      case 'mfa':
        return (_mfa?['factors'] as List?)?.length ?? 0;
      case 'lifecycle':
        return (_lifecycle?.isNotEmpty ?? false) ? 1 : 0;
      default:
        return 0;
    }
  }

  Widget _tabContent(BuildContext context) {
    switch (_tabs[_tabIndex].$1) {
      case 'sessions':
        return _optionalSection(
          'sessions',
          UserSessionsView(
            sessions: _sessions?['sessions'] as List? ?? const [],
          ),
        );
      case 'consents':
        return _optionalSection(
          'consents',
          UserConsentsView(
            consents: _consents?['consents'] as List? ?? const [],
            mutating: _mutating,
            onRevoke: _revokeConsent,
          ),
        );
      case 'mfa':
        return _optionalSection(
          'mfa',
          UserMfaView(
            factors: _mfa?['factors'] as List? ?? const [],
            mutating: _mutating,
            onRemove: _removeMfa,
          ),
        );
      case 'lifecycle':
        return _optionalSection(
          'lifecycle',
          UserLifecycleView(
            lifecycle: _lifecycle ?? const {},
            showBackButton: _user != null,
            onBack: () => AdminRoute.back('users'),
          ),
        );
      case 'device-security':
        return UserDeviceSecurityPanel(api: widget.api, userId: widget.userId);
      default:
        return const Center(child: LocalizedText('Select a tab'));
    }
  }

  Widget _optionalSection(String section, Widget content) {
    final error = _sectionErrors[section];
    if (error == null) return content;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 40, color: _accent),
            const SizedBox(height: 12),
            LocalizedText('This user resource is unavailable.'),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const LocalizedText('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revokeConsent(String clientId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke consent?',
      message: context.tr('Revoke for {clientId}?', {'clientId': clientId}),
      confirmLabel: 'Revoke',
      destructive: true,
      confirmText: clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete(AdminPaths.userConsent(widget.userId, clientId));
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Consent revoked'));
      _load();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          content: LocalizedText('Error: {e}', args: {'e': e}),
          kind: AppSnackBarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _removeMfa(String factorId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove MFA factor?',
      message: 'Remove this factor?',
      confirmLabel: 'Remove',
      destructive: true,
      confirmText: factorId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete(
        AdminPaths.userMfaFactor(widget.userId, factorId),
      );
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('MFA factor removed'));
      _load();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          content: LocalizedText('Error: {error}', args: {'error': error}),
          kind: AppSnackBarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
}
