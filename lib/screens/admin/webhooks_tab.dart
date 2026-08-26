import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
part 'webhooks_tab_view.dart';
part 'webhooks_tab_sections.dart';

/// Webhook subscriptions and dead letter management tab.
class WebhooksTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const WebhooksTab({super.key, required this.api, required this.capabilities});

  @override
  State<WebhooksTab> createState() => _WebhooksTabState();
}

class _WebhooksTabState extends State<WebhooksTab> {
  static const _subsPath = '/api/v1/admin/webhooks/subscriptions';
  static const _deadPath = '/api/v1/admin/webhooks/deadletters';
  final _urlCtrl = TextEditingController();
  final _eventsCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _active = true;
  List<Map<String, dynamic>> _subscriptions = const [];
  List<Map<String, dynamic>> _deadLetters = const [];
  String? _error;
  bool _loading = false;
  var _statusFilter = 'all';
  bool _mutating = false;

  /// 请求序号：订阅/死信两个端点的聚合结果与 stale 回调必须同批次。
  int _reqSeq = 0;
  late final void Function() _cancelPopState;

  /// 模块组色（developers → emerald）：页头图标统一上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.webhooks);
  bool get _hasSubscriptions => widget.capabilities.hasAnyPathPrefix(_subsPath);
  bool get _hasDeadLetters => widget.capabilities.hasAnyPathPrefix(_deadPath);

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
    if (route.module != 'webhooks') return;
    if (route.isNew) _create();
  }

  @override
  void dispose() {
    _cancelPopState();
    _urlCtrl.dispose();
    _eventsCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        if (_hasSubscriptions)
          widget.api.getStaleWhileRevalidate(
            _subsPath,
            onRefresh: (fresh) => _applySubsRefresh(fresh, seq),
          ),
        if (_hasDeadLetters)
          widget.api.getStaleWhileRevalidate(
            _deadPath,
            onRefresh: (fresh) => _applyDeadRefresh(fresh, seq),
          ),
      ]);
      if (!mounted || seq != _reqSeq) return;
      var idx = 0;
      setState(() {
        if (_hasSubscriptions) {
          _subscriptions = _maps(results[idx++]['subscriptions']);
        }
        if (_hasDeadLetters) {
          _deadLetters = _maps(
            results[idx]['deadletters'] ?? results[idx]['messages'],
          );
        }
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      _fail(e.toString(), seq);
    } catch (_) {
      _fail('Could not load webhooks.', seq);
    }
  }

  void _applySubsRefresh(Map<String, dynamic> fresh, int seq) {
    if (mounted && seq == _reqSeq) {
      setState(() => _subscriptions = _maps(fresh['subscriptions']));
    }
  }

  void _applyDeadRefresh(Map<String, dynamic> fresh, int seq) {
    if (mounted && seq == _reqSeq) {
      setState(
        () => _deadLetters = _maps(fresh['deadletters'] ?? fresh['messages']),
      );
    }
  }

  /// API 列表 → 强类型 Map 列表（空/缺省为 []）。
  List<Map<String, dynamic>> _maps(Object? raw) => [
    for (final e in raw as List? ?? const [])
      Map<String, dynamic>.from(e as Map),
  ];

  void _fail(String message, int seq) {
    if (!mounted || seq != _reqSeq) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  /// 变更操作壳：mutating + snackbar + 错误回写（delete 共用）。
  Future<void> _mutate(String success, Future<void> Function() run) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await run();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(success));
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _create() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'URL is required.');
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final events = _eventsCtrl.text
          .trim()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await widget.api.post(_subsPath, {
        'url': url,
        if (events.isNotEmpty) 'event_types': events,
        if (_secretCtrl.text.trim().isNotEmpty)
          'secret': _secretCtrl.text.trim(),
        'active': _active,
      });
      if (!mounted) return;
      _urlCtrl.clear();
      _eventsCtrl.clear();
      _secretCtrl.clear();
      showAppSnackBar(
        context,
        content: LocalizedText('Webhook subscription created.'),
      );
      if (mounted) AdminRoute.go('webhooks');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _secretCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete subscription?',
      message: context.tr('Delete webhook subscription {id}?', {'id': id}),
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    await _mutate('Subscription deleted.', () async {
      await widget.api.delete('$_subsPath/${Uri.encodeComponent(id)}');
      await _load();
    });
  }

  Future<void> _replay(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Replay dead letter?',
      message: 'Replay this failed delivery?',
      confirmLabel: 'Replay',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.post(
        '$_deadPath/${Uri.encodeComponent(id)}/replay',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final cleanupComplete = response['cleanup_status'] == 'complete';
      showAppSnackBar(
        context,
        content: LocalizedText(
          cleanupComplete
              ? 'Delivery sent and dead-letter cleanup completed.'
              : 'Delivery succeeded; cleanup remains pending. Retrying this entry is cleanup-only and cannot redeliver it.',
        ),
      );
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildWebhooksTab(context);
}
