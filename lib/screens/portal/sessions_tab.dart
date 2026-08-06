import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import '../oidc_login/trusted_device_token.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
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
  late Future<PortalSessionsResult> _future = _load();
  bool _revokingAll = false;

  Future<PortalSessionsResult> _load() => loadPortalSessions(widget.api);

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _revoke(String id) async {
    if (id.isEmpty || !await _confirmSessionRevoke(id)) return;
    final r = await widget.api.delete(PortalSecurityPaths.legacySession(id));
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
        SnackBar(content: Text(context.tr('Could not revoke this session.'))),
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
        PortalSecurityPaths.legacySessions,
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
          SnackBar(content: Text(context.tr('Could not revoke sessions.'))),
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
          context.tr(
            isCurrentSession ? 'Sign out this browser?' : 'Revoke session?',
          ),
        ),
        content: Text(
          context.tr(
            isCurrentSession
                ? 'This will sign out the browser you are using now.'
                : 'This device will be signed out immediately.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.tr(isCurrentSession ? 'Sign out' : 'Revoke')),
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
          context.tr(
            preservesCurrentSession
                ? 'Sign out of other devices?'
                : 'Sign out everywhere?',
          ),
        ),
        content: Text(
          context.tr(
            preservesCurrentSession
                ? 'All other active sessions and trusted-device grants will be revoked. This browser will remain signed in.'
                : 'This opaque token does not identify the current session. Snaplink will revoke every session, including this browser.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(
              context.tr(
                preservesCurrentSession
                    ? 'Sign out other devices'
                    : 'Sign out everywhere',
              ),
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
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                context.tr('Active sessions'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Browser and device sessions currently signed in with your account.',
          style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
        ),
              OverflowBar(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _revokingAll ? null : _revokeOthers,
                    icon: _revokingAll
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout, color: AppColors.danger),
                    label: Text(
                      context.tr(
                        widget.api.currentSessionId == null
                            ? 'Sign out everywhere'
                            : 'Sign out of other devices',
                      ),
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Refresh sessions'),
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<PortalSessionsResult>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    context.tr('Error: {error}', {
                      'error': context.tr('${snap.error}'),
                    }),
                  ),
                );
              }
              final result = snap.data;
              final items = result?.sessions ?? const [];
              if (items.isEmpty) {
                return const Center(child: EmptyHint('No active sessions.'));
              }
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (result?.usedLegacyEndpoint == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        context.tr(
                          'Device enrichment is not enabled; showing legacy session metadata.',
                        ),
                      ),
                    ),
                  for (var i = 0; i < items.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final s = items[i];
                        final id = s['id']?.toString() ?? '';
                        final metaParts = <String>[];
                        if (s['created_at'] != null) {
                          metaParts.add(
                            context.tr('since {date}', {
                              'date': _shortDate(s['created_at']),
                            }),
                          );
                        }
                        if (s['expires_at'] != null) {
                          metaParts.add(
                            context.tr('expires {date}', {
                              'date': _shortDate(s['expires_at']),
                            }),
                          );
                        }
                        final devParts = <String>[];
                        if (s['ip'] != null) {
                          devParts.add(s['ip'].toString());
                        }
                        if (s['user_agent'] != null) {
                          devParts.add(
                            _deviceHint(context, s['user_agent'].toString()),
                          );
                        }
                        if (s['device_name']?.toString().isNotEmpty == true) {
                          devParts.add(s['device_name'].toString());
                        }
                        final posture = <String>[
                          if (s['device_platform']?.toString().isNotEmpty ==
                              true)
                            s['device_platform'].toString(),
                          if (s['device_browser']?.toString().isNotEmpty ==
                              true)
                            s['device_browser'].toString(),
                          if (s['trust_label']?.toString().isNotEmpty == true)
                            context.tr('trust {value}', {
                              'value': s['trust_label'],
                            }),
                        ];
                        return ListTile(
                          title: Text(id),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (metaParts.isNotEmpty)
                                Text(metaParts.join(' · ')),
                              if (devParts.isNotEmpty)
                                Text(devParts.join(' · ')),
                              if (posture.isNotEmpty) Text(posture.join(' · ')),
                            ],
                          ),
                          isThreeLine:
                              metaParts.isNotEmpty && devParts.isNotEmpty,
                          trailing: TextButton(
                            onPressed: () => _revoke(id),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            child: Text(context.tr('Revoke')),
                          ),
                        );
                      },
                    ),
                    if (i < items.length - 1) const Divider(height: 1),
                  ],
                ],
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
String _deviceHint(BuildContext context, String ua) {
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
  if (browser.isNotEmpty && os.isNotEmpty) {
    return context.tr('{browser} on {os}', {'browser': browser, 'os': os});
  }
  if (browser.isNotEmpty) return browser;
  if (os.isNotEmpty) return os;
  return ua.length > 40 ? '${ua.substring(0, 40)}…' : ua;
}
