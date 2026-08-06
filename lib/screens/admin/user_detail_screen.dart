import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
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
      '/api/v1/admin/users/:id/sessions',
    ),
    (
      'consents',
      'Consents',
      Icons.checklist,
      'GET',
      '/api/v1/admin/users/:id/consents',
    ),
    ('mfa', 'MFA', Icons.security, 'GET', '/api/v1/admin/users/:id/mfa'),
    (
      'lifecycle',
      'Lifecycle',
      Icons.route,
      'GET',
      '/api/v1/admin/users/:id/lifecycle',
    ),
    (
      'device-security',
      'Device security',
      Icons.phonelink_lock,
      'GET',
      '/api/v1/admin/users/:id/devices',
    ),
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
    if (route.resourceId != widget.userId) return;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        setState(() => _tabIndex = i);
        return;
      }
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
      final uid = Uri.encodeComponent(widget.userId);
      // 各 tab 数据端点并行加载（Future.wait，_optionalGet 内部容错）。
      final tabFutures = <String, Future<Map<String, dynamic>>>{};
      for (final tab in _tabs) {
        if (tab.$1 == 'device-security') continue; // self-loading panel
        final spec = _tabSpecs.firstWhere((s) => s.$1 == tab.$1);
        tabFutures[tab.$1] = _optionalGet(
          tab.$1,
          spec.$5.replaceAll(':id', uid),
        );
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
        title: LocalizedText('User: {widget_userId}', args: {'widget_userId': widget.userId}),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back'.localized,
          onPressed: () => AdminRoute.go('users'),
        ),
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
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  LocalizedText(
                    'Failed to load user',
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
      UserDetailHeader(user: _user),
      UserDetailTabBar(
        labels: _tabs.map((tab) => tab.$2).toList(growable: false),
        selectedIndex: _tabIndex,
        onSelected: (index) => _selectTab(index, _tabs[index].$1),
      ),
      Expanded(child: _tabContent(context)),
    ],
  );

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
            onBack: () => AdminRoute.go('users'),
          ),
        );
      case 'device-security':
        return UserDeviceSecurityPanel(
          api: widget.api,
          userId: widget.userId,
        );
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
            const Icon(Icons.info_outline, size: 40),
            const SizedBox(height: 12),
            LocalizedText('This user resource is unavailable.'),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
      message: 'Revoke for $clientId?',
      destructive: true,
      confirmText: clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete(
        '/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/consents/${Uri.encodeComponent(clientId)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LocalizedText('Consent revoked')));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText('Error: {e}', args: {'e': e})));
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
      destructive: true,
      confirmText: factorId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete(
        '/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/mfa/${Uri.encodeComponent(factorId)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('MFA factor removed')),
      );
      _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText('Error: {error}', args: {'error': error})));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
}
