import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';
import '../../i18n/app_strings.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

part 'notifications_tab_view.dart';

/// Account notification inbox: unread counter, cursor pagination, mark-read
/// (single + all), and channel/type preferences.
class NotificationsTab extends StatefulWidget {
  final PortalApi api;
  final VoidCallback? onChanged;
  final ValueChanged<Map<String, dynamic>>? onOpen;

  const NotificationsTab({super.key, required this.api, this.onChanged, this.onOpen});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _preferences = const [];
  bool _preferencesError = false;
  bool _preferencesLoading = false;
  bool _loading = true;
  bool _loadingMore = false, _saving = false;
  bool _loadInFlight = false;
  bool _markingAll = false;
  final Set<String> _markingReadIds = <String>{};
  bool _hasMore = false;
  int _unread = 0;
  String? _error;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String key, {AppSnackBarKind kind = AppSnackBarKind.success, SnackBarAction? action}) {
    showAppSnackBar(context, content: Text(context.tr(key)), kind: kind, action: action);
  }

  Future<void> _load({bool more = false}) async {
    if (_loadInFlight || _markingAll || _markingReadIds.isNotEmpty || _saving || _preferencesLoading) {
      return;
    }
    _loadInFlight = true;
    if (!more) {
      setState(() {
        _loading = true;
        _error = null;
        _loadMoreError = null;
      });
    } else {
      setState(() {
        _loadingMore = true;
        _loadMoreError = null;
      });
    }
    try {
      final before = more && _items.isNotEmpty ? _items.last['id']?.toString() : null;
      final query = <String, String>{'limit': '20', if (before?.isNotEmpty ?? false) 'before_id': before!};
      final inbox = await widget.api.get(Uri(path: PortalPaths.notifications, queryParameters: query).toString());
      if (inbox.statusCode != 200) throw PortalApiError(inbox.statusCode);
      final body = PortalApi.decode(inbox);
      final incoming = _objects(body['notifications']);
      if (!mounted) return;
      setState(() {
        _items = more ? _mergeItems(_items, incoming) : incoming;
        _unread = (body['unread_count'] as num?)?.toInt() ?? 0;
        _hasMore = body['has_more'] == true;
      });
      if (!more) await _loadPreferences();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              more ? _loadMoreError = 'Notifications are not available.' : _error = 'Notifications are not available.',
        );
      }
    } finally {
      _loadInFlight = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    if (!mounted || _preferencesLoading) return;
    _preferencesLoading = true;
    setState(() => _preferencesError = false);
    try {
      final response = await widget.api.get(PortalPaths.notificationPreferences);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() => _preferencesError = true);
        return;
      }
      setState(() => _preferences = _objects(PortalApi.decode(response)['preferences']));
    } catch (_) {
      if (mounted) setState(() => _preferencesError = true);
    } finally {
      _preferencesLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) {
      widget.onOpen?.call(item);
      return;
    }
    if (_markingAll) return;
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || _markingReadIds.contains(id)) return;
    setState(() => _markingReadIds.add(id));
    try {
      final response = await widget.api.post(PortalPaths.notificationRead(id));
      if (response.statusCode != 200) {
        if (mounted) _readError(item);
        return;
      }
      if (!mounted) return;
      setState(() {
        item['read_at'] = DateTime.now().toUtc().toIso8601String();
        if (_unread > 0) _unread--;
      });
      widget.onChanged?.call();
      widget.onOpen?.call(item);
    } catch (_) {
      if (mounted) _readError(item);
    } finally {
      if (mounted) setState(() => _markingReadIds.remove(id));
    }
  }

  void _readError(Map<String, dynamic> item) {
    _snack(
      'Some notifications could not be marked as read.',
      kind: AppSnackBarKind.error,
      action: SnackBarAction(label: context.tr('Retry'), onPressed: () => _markRead(item)),
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _loading || _loadingMore || _saving || _markingReadIds.isNotEmpty || _preferencesLoading) {
      return;
    }
    setState(() => _markingAll = true);
    try {
      List<Map<String, dynamic>> unread;
      try {
        unread = await _allUnread();
      } catch (_) {
        if (mounted) {
          _snack(
            'Some notifications could not be marked as read.',
            kind: AppSnackBarKind.error,
            action: SnackBarAction(label: context.tr('Retry'), onPressed: () => _markAllRead()),
          );
        }
        return;
      }
      if (unread.isEmpty || !mounted) return;
      final confirmed = await ConfirmDialog.show(
        context,
        title: context.tr('Mark all as read?'),
        message: context.tr('This will mark {n} notifications as read.', {'n': '${unread.length}'}),
        confirmLabel: context.tr('Mark all'),
      );
      if (!confirmed || !mounted) return;
      var failed = false;
      // Parallel mark-read: independent per-id posts (N+1 fix).
      final now = DateTime.now().toUtc().toIso8601String();
      final results = await Future.wait(
        unread.map((item) async {
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty) {
            failed = true;
            return false;
          }
          try {
            final response = await widget.api.post(PortalPaths.notificationRead(id));
            if (response.statusCode != 200) {
              failed = true;
              return false;
            }
            item['read_at'] = now;
            return true;
          } catch (_) {
            failed = true;
            return false;
          }
        }),
      );
      final marked = results.where((ok) => ok).length;
      if (!mounted) return;
      setState(() {
        final markedIDs = unread.where((item) => item['read_at'] != null).map((item) => item['id']?.toString()).toSet();
        for (final item in _items) {
          if (markedIDs.contains(item['id']?.toString())) {
            item['read_at'] = now;
          }
        }
        final remaining = _unread - marked;
        _unread = remaining < 0 ? 0 : remaining;
      });
      if (marked > 0) widget.onChanged?.call();
      if (failed) {
        _snack(
          'Some notifications could not be marked as read.',
          kind: AppSnackBarKind.error,
          action: SnackBarAction(label: context.tr('Retry'), onPressed: () => _markAllRead()),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<List<Map<String, dynamic>>> _allUnread() async {
    final unread = <String, Map<String, dynamic>>{};
    final locallyRead = _items
        .where((item) => item['read_at'] != null)
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();
    String? before;
    final cursors = <String>{};
    while (true) {
      final query = <String, String>{'limit': '100', 'unread_only': 'true', 'before_id': ?before};
      final response = await widget.api.get(Uri(path: PortalPaths.notifications, queryParameters: query).toString());
      if (response.statusCode != 200) throw PortalApiError(response.statusCode);
      final body = PortalApi.decode(response);
      final page = _objects(body['notifications']);
      for (final item in page) {
        final id = item['id']?.toString();
        if (id != null && !locallyRead.contains(id)) unread[id] = item;
      }
      if (body['has_more'] != true || page.isEmpty) break;
      before = page.last['id']?.toString();
      if (before == null || !cursors.add(before)) break;
    }
    return unread.values.toList();
  }

  Future<void> _savePreferences() async {
    if (_saving) return;
    setState(() => _saving = true);
    var ok = false;
    try {
      final response = await widget.api.put(PortalPaths.notificationPreferences, {'preferences': _preferences});
      if (response.statusCode != 200) throw PortalApiError(response.statusCode);
      ok = true;
    } catch (_) {
      // Keep the failure snackbar below; the list state stays editable.
    }
    if (mounted) {
      _snack(
        ok ? 'Notification preferences saved.' : 'Could not save notification preferences.',
        kind: ok ? AppSnackBarKind.success : AppSnackBarKind.error,
        action: ok ? null : SnackBarAction(label: context.tr('Retry'), onPressed: () => _savePreferences()),
      );
      setState(() => _saving = false);
    }
  }

  void _setPreferenceEnabled(Map<String, dynamic> preference, bool value) {
    setState(() => preference['enabled'] = value);
  }

  @override
  Widget build(BuildContext context) => _buildNotificationsTab(context);
}

/// Inbox row: severity icon, unread-bold title, meta, trailing severity chip.
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool busy;
  const _NotificationTile({required this.item, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = item['read_at'] == null;
    final severity = item['severity']?.toString() ?? '';
    final (icon, color, label) = _severityStyle(severity);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      isThreeLine: true,
      onTap: busy ? null : onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: unread ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: unread ? color : theme.colorScheme.outline),
      ),
      title: Text(
        item['title']?.toString() ?? context.tr('Security notification'),
        softWrap: true,
        style: TextStyle(fontWeight: unread ? FontWeight.w700 : null),
      ),
      subtitle: Text(_join(item['body'], item['created_at'] == null ? null : formatServerTime(item['created_at']))),
      trailing: busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : StatusChip(label: context.tr(label), color: color, icon: icon),
    );
  }
}

List<Map<String, dynamic>> _mergeItems(List<Map<String, dynamic>> existing, List<Map<String, dynamic>> incoming) {
  final result = [...existing];
  final ids = existing.map((item) => item['id']?.toString()).whereType<String>().toSet();
  for (final item in incoming) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty || ids.add(id)) result.add(item);
  }
  return result;
}

List<Map<String, dynamic>> _objects(Object? value) => value is List
    ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
    : <Map<String, dynamic>>[];
String _join(Object? first, Object? second) =>
    [first, second].where((v) => v?.toString().isNotEmpty == true).join(' · ');

/// Severity → (icon, brand color, label key); unknown severities = Notice.
(IconData, Color, String) _severityStyle(String severity) => switch (severity) {
  'critical' => (Icons.gpp_bad_outlined, AppColors.danger, 'Critical'),
  'warning' => (Icons.warning_amber_outlined, AppColors.warning, 'Warning'),
  _ => (Icons.notifications_outlined, AppColors.accentBlue, 'Notice'),
};
String _channelLabel(String value) => value == 'email' ? 'Email' : 'In-app';
String _typeLabel(String value) => switch (value) {
  'password_expiring' => 'Password expiry',
  'new_device_login' => 'New device login',
  'mfa_removed' => 'MFA removed',
  'consent_granted' => 'Application consent',
  'session_expiring' => 'Session expiry',
  'password_leaked' => 'Compromised password',
  'account_locked' => 'Account lockout',
  _ => 'Security events',
};
