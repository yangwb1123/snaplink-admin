import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import '../../i18n/app_strings.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';

class NotificationsTab extends StatefulWidget {
  final PortalApi api;
  final VoidCallback? onChanged;
  final ValueChanged<Map<String, dynamic>>? onOpen;

  const NotificationsTab({
    super.key,
    required this.api,
    this.onChanged,
    this.onOpen,
  });

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _preferences = const [];
  bool _loading = true;
  bool _saving = false;
  bool _hasMore = false;
  int _unread = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final before = more && _items.isNotEmpty
          ? _items.last['id']?.toString()
          : null;
      final query = <String, String>{
        'limit': '20',
        if (before?.isNotEmpty ?? false) 'before_id': before!,
      };
      final inbox = await widget.api.get(
        Uri(path: '/me/notifications', queryParameters: query).toString(),
      );
      if (inbox.statusCode != 200) throw PortalApiError(inbox.statusCode);
      final body = PortalApi.decode(inbox);
      final incoming = _objects(body['notifications']);
      if (!mounted) return;
      setState(() {
        _items = more ? [..._items, ...incoming] : incoming;
        _unread = (body['unread_count'] as num?)?.toInt() ?? 0;
        _hasMore = body['has_more'] == true;
      });
      if (!more) await _loadPreferences();
    } catch (_) {
      if (mounted) setState(() => _error = 'Notifications are not available.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPreferences() async {
    final response = await widget.api.get('/me/notifications/preferences');
    if (response.statusCode != 200 || !mounted) return;
    setState(
      () => _preferences = _objects(PortalApi.decode(response)['preferences']),
    );
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) {
      widget.onOpen?.call(item);
      return;
    }
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final response = await widget.api.post('/me/notifications/$id/read');
    if (response.statusCode != 200 || !mounted) return;
    setState(() {
      item['read_at'] = DateTime.now().toUtc().toIso8601String();
      if (_unread > 0) _unread--;
    });
    widget.onChanged?.call();
    widget.onOpen?.call(item);
  }

  Future<void> _markAllRead() async {
    List<Map<String, dynamic>> unread;
    try {
      unread = await _allUnread();
    } catch (_) {
      if (!mounted) return;
      return;
    }
    if (unread.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Mark all as read?'),
      message: context.tr(
          'This will mark {n} notifications as read.', {'n': '${unread.length}'}),
      confirmLabel: context.tr('Mark all'),
    );
    if (!confirmed) return;
    var failed = false;
    var marked = 0;
    // Parallel mark-read: independent per-id posts (N+1 fix).
    final now = DateTime.now().toUtc().toIso8601String();
    final results = await Future.wait(unread.map((item) async {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) return false;
      try {
        final response = await widget.api.post('/me/notifications/$id/read');
        if (response.statusCode != 200) return false;
        item['read_at'] = now;
        return true;
      } catch (_) {
        failed = true;
        return false;
      }
    }));
    marked = results.where((ok) => ok).length;
    if (!mounted) return;
    setState(() {
      final markedIDs = unread
          .where((item) => item['read_at'] != null)
          .map((item) => item['id']?.toString())
          .toSet();
      for (final item in _items) {
        if (markedIDs.contains(item['id']?.toString())) {
          item['read_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }
      final remaining = _unread - marked;
      _unread = remaining < 0 ? 0 : remaining;
    });
    widget.onChanged?.call();
    if (failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Some notifications could not be marked as read.'),
          ),
        ),
      );
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
      final query = <String, String>{
        'limit': '100',
        'unread_only': 'true',
        'before_id': ?before,
      };
      final response = await widget.api.get(
        Uri(path: '/me/notifications', queryParameters: query).toString(),
      );
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
    setState(() => _saving = true);
    try {
      final response = await widget.api.put('/me/notifications/preferences', {
        'preferences': _preferences,
      });
      if (response.statusCode != 200) throw PortalApiError(response.statusCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Notification preferences saved.')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Could not save notification preferences.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Notifications'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  context.tr(
                    '{count} unread security and account notifications.',
                    {'count': _unread},
                  ),
                ),
              ],
            ),
          ),
          if (_unread > 0)
            TextButton(
              onPressed: _loading ? null : _markAllRead,
              child: Text(context.tr('Mark all as read')),
            ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.tr('Refresh notifications'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 16),
      PortalCard(
        title: 'Inbox',
        children: [
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null)
            MessageBanner(_error)
          else if (_items.isEmpty)
            const EmptyHint('You have no notifications.')
          else
            ..._items.map(
              (item) =>
                  _NotificationTile(item: item, onTap: () => _markRead(item)),
            ),
          if (_hasMore)
            TextButton(
              onPressed: () => _load(more: true),
              child: Text(context.tr('Load more')),
            ),
        ],
      ),
      if (_preferences.isNotEmpty)
        PortalCard(
          title: 'Notification preferences',
          children: [
            ..._preferences.map(
              (preference) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr(_typeLabel(preference['type']?.toString() ?? '')),
                ),
                subtitle: Text(
                  context.tr(
                    _channelLabel(preference['channel']?.toString() ?? ''),
                  ),
                ),
                value: preference['enabled'] != false,
                onChanged: (value) =>
                    setState(() => preference['enabled'] = value),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _savePreferences,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(context.tr('Save preferences')),
              ),
            ),
          ],
        ),
    ],
  );
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        _severityIcon(item['severity']?.toString()),
        color: unread ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        item['title']?.toString() ?? context.tr('Security notification'),
        style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text(_join(item['body'], item['created_at'])),
      trailing: unread
          ? Semantics(
              label: context.tr('Unread'),
              child: const Icon(Icons.circle, size: 10),
            )
          : null,
    );
  }
}

List<Map<String, dynamic>> _objects(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];
String _join(Object? first, Object? second) => [
  first,
  second,
].where((v) => v != null && v.toString().isNotEmpty).join(' · ');
IconData _severityIcon(String? severity) => switch (severity) {
  'critical' => Icons.gpp_bad_outlined,
  'warning' => Icons.warning_amber_outlined,
  _ => Icons.notifications_outlined,
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
