import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Connected applications (OAuth consents) list + per-app revoke. Ports the
/// "Connected applications" card / loadConsents() in app.js.
class ConsentsTab extends StatefulWidget {
  final PortalApi api;
  const ConsentsTab({super.key, required this.api});

  @override
  State<ConsentsTab> createState() => _ConsentsTabState();
}

class _ConsentsTabState extends State<ConsentsTab> {
  late Future<List<dynamic>> _future = _load();
  String? _revokingClientId;

  Future<List<dynamic>> _load() async {
    final r = await widget.api.get('/consents/me');
    if (r.statusCode == 401) {
      throw PortalApiError(r.statusCode, 'Your session has expired.');
    }
    if (r.statusCode != 200) {
      throw PortalApiError(
        r.statusCode,
        'Connected applications are not available.',
      );
    }
    final d = PortalApi.decode(r);
    return (d['consents'] as List?) ?? const [];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _revoke(String clientId) async {
    if (clientId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Revoke application access?')),
        content: Text(
          context.tr(
            '{clientId} will no longer be able to use the permissions you granted. You can authorize it again later.',
            {'clientId': clientId},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('Revoke')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _revokingClientId = clientId);
    try {
      final response = await widget.api.delete(
        '/consents/me/${Uri.encodeComponent(clientId)}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PortalApiError(response.statusCode);
      }
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Could not revoke application access.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revokingClientId = null);
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
              Text(
                context.tr('Connected applications'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
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
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('Error: {error}', {
                          'error': context.tr('${snap.error}'),
                        }),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _reload,
                        child: const LocalizedText('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Center(
                  child: EmptyHint('No connected applications.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = items[i] as Map<String, dynamic>;
                  final clientId = c['client_id']?.toString() ?? '';
                  final scopes = ((c['scopes'] as List?) ?? const []).join(' ');
                  return ListTile(
                    title: Text(clientId),
                    subtitle: scopes.isEmpty ? null : Text(scopes),
                    trailing: TextButton(
                      onPressed:
                          _revokingClientId == null && clientId.isNotEmpty
                          ? () => _revoke(clientId)
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: _revokingClientId == clientId
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr('Revoke')),
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
