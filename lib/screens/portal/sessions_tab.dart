import 'package:flutter/material.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';

/// Active session list + per-session revoke + "sign out of other devices".
/// Ports the "Active sessions" card / loadSessions() in app.js.
class SessionsTab extends StatefulWidget {
  final PortalApi api;
  const SessionsTab({super.key, required this.api});

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Future<List<dynamic>> _future = _load();
  bool _revokingAll = false;

  Future<List<dynamic>> _load() async {
    final r = await widget.api.get('/sessions/me');
    final d = PortalApi.decode(r);
    return (d['sessions'] as List?) ?? const [];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _revoke(String id) async {
    await widget.api.delete('/sessions/me/${Uri.encodeComponent(id)}');
    _reload();
  }

  Future<void> _revokeOthers() async {
    setState(() => _revokingAll = true);
    try {
      await widget.api.delete('/sessions/me');
      _reload();
    } finally {
      if (mounted) setState(() => _revokingAll = false);
    }
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
              Text('Active sessions', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _revokingAll ? null : _revokeOthers,
                icon: _revokingAll
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Sign out of other devices', style: TextStyle(color: Colors.redAccent)),
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
                  if (s['ip'] != null) devParts.add(s['ip'].toString());
                  if (s['user_agent'] != null) devParts.add(_deviceHint(s['user_agent'].toString()));
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
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
  } else if (ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iOS')) {
    os = 'iOS';
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  }
  if (browser.isNotEmpty && os.isNotEmpty) return '$browser on $os';
  if (browser.isNotEmpty) return browser;
  if (os.isNotEmpty) return os;
  return ua.length > 40 ? '${ua.substring(0, 40)}…' : ua;
}
