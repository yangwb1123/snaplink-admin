import 'package:flutter/material.dart';

import '../oidc_login/trusted_device_token.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';

/// Active session list + per-session revoke + "sign out of other devices".
/// Ports the "Active sessions" card / loadSessions() in app.js.
class SessionsTab extends StatefulWidget {
  final PortalApi api;
  final VoidCallback onCurrentSessionRevoked;
  const SessionsTab({
    super.key,
    required this.api,
    required this.onCurrentSessionRevoked,
  });

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Future<List<dynamic>> _future = _load();
  bool _revokingAll = false;

  Future<List<dynamic>> _load() async {
    final r = await widget.api.get('/sessions/me');
    if (r.statusCode == 401) {
      throw PortalApiError(r.statusCode, 'Your session has expired.');
    }
    if (r.statusCode != 200) {
      throw PortalApiError(r.statusCode, 'Active sessions are not available.');
    }
    final d = PortalApi.decode(r);
    return (d['sessions'] as List?) ?? const [];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _revoke(String id) async {
    if (id.isEmpty || !await _confirmSessionRevoke(id)) return;
    final r = await widget.api.delete(
      '/sessions/me/${Uri.encodeComponent(id)}',
    );
    if (r.statusCode >= 200 &&
        r.statusCode < 300 &&
        id == widget.api.currentSessionId) {
      widget.api.signOut();
      widget.onCurrentSessionRevoked();
      return;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      _reload();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not revoke this session.')),
      );
    }
  }

  Future<void> _revokeOthers() async {
    final preservesCurrentSession = widget.api.currentSessionId != null;
    if (!await _confirmBulkRevoke(preservesCurrentSession)) {
      return;
    }
    setState(() => _revokingAll = true);
    try {
      final response = await widget.api.deleteWithQuery(
        '/sessions/me',
        query: preservesCurrentSession ? null : const {'all': 'true'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Bulk session revocation also removes every trusted-device grant.
        // Clear the tab-scoped copy so it cannot be sent at the next login.
        final clientId = widget.api.currentClientId;
        if (clientId != null) TrustedDeviceToken.clear(clientId);
        if (!preservesCurrentSession) {
          widget.api.signOut();
          widget.onCurrentSessionRevoked();
          return;
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not revoke sessions.')),
        );
      }
      _reload();
    } finally {
      if (mounted) setState(() => _revokingAll = false);
    }
  }

  Future<bool> _confirmSessionRevoke(String id) async {
    final isCurrentSession = id == widget.api.currentSessionId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCurrentSession ? 'Sign out this browser?' : 'Revoke session?',
        ),
        content: Text(
          isCurrentSession
              ? 'This will sign out the browser you are using now.'
              : 'This device will be signed out immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isCurrentSession ? 'Sign out' : 'Revoke'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<bool> _confirmBulkRevoke(bool preservesCurrentSession) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          preservesCurrentSession
              ? 'Sign out of other devices?'
              : 'Sign out everywhere?',
        ),
        content: Text(
          preservesCurrentSession
              ? 'All other active sessions and trusted-device grants will be revoked. This browser will remain signed in.'
              : 'This opaque token does not identify the current session. Snaplink will revoke every session, including this browser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              preservesCurrentSession
                  ? 'Sign out other devices'
                  : 'Sign out everywhere',
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Active sessions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _revokingAll ? null : _revokeOthers,
                icon: _revokingAll
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout, color: Colors.redAccent),
                label: Text(
                  widget.api.currentSessionId == null
                      ? 'Sign out everywhere'
                      : 'Sign out of other devices',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Center(child: EmptyHint('No active sessions.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = items[i] as Map<String, dynamic>;
                  final id = s['id']?.toString() ?? '';
                  final metaParts = <String>[];
                  if (s['created_at'] != null) {
                    metaParts.add('since ${_shortDate(s['created_at'])}');
                  }
                  if (s['expires_at'] != null) {
                    metaParts.add('expires ${_shortDate(s['expires_at'])}');
                  }
                  final devParts = <String>[];
                  if (s['ip'] != null) {
                    devParts.add(s['ip'].toString());
                  }
                  if (s['user_agent'] != null) {
                    devParts.add(_deviceHint(s['user_agent'].toString()));
                  }
                  return ListTile(
                    title: Text(id),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (metaParts.isNotEmpty) Text(metaParts.join(' · ')),
                        if (devParts.isNotEmpty) Text(devParts.join(' · ')),
                      ],
                    ),
                    isThreeLine: metaParts.isNotEmpty && devParts.isNotEmpty,
                    trailing: TextButton(
                      onPressed: () => _revoke(id),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Revoke'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _shortDate(Object? v) {
  final s = v.toString();
  return s.length < 10 ? s : s.substring(0, 10);
}

/// Reduces a raw User-Agent to a friendly "Browser on OS" label, ported
/// verbatim (same regexes/precedence) from app.js's deviceHint().
String _deviceHint(String ua) {
  String browser = '';
  if (ua.contains('Edg/')) {
    browser = 'Edge';
  } else if (ua.contains('Chrome/')) {
    browser = 'Chrome';
  } else if (ua.contains('Firefox/')) {
    browser = 'Firefox';
  } else if (ua.contains('Safari/')) {
    browser = 'Safari';
  }
  String os = '';
  if (ua.contains('Windows')) {
    os = 'Windows';
  } else if (ua.contains('Mac OS X') || ua.contains('Macintosh')) {
    os = 'macOS';
  } else if (ua.contains('Android')) {
    os = 'Android';
  } else if (ua.contains('iPhone') ||
      ua.contains('iPad') ||
      ua.contains('iOS')) {
    os = 'iOS';
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  }
  if (browser.isNotEmpty && os.isNotEmpty) return '$browser on $os';
  if (browser.isNotEmpty) return browser;
  if (os.isNotEmpty) return os;
  return ua.length > 40 ? '${ua.substring(0, 40)}…' : ua;
}
