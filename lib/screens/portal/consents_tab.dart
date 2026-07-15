import 'package:flutter/material.dart';
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

  Future<List<dynamic>> _load() async {
    final r = await widget.api.get('/consents/me');
    final d = PortalApi.decode(r);
    return (d['consents'] as List?) ?? const [];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _revoke(String clientId) async {
    await widget.api.delete('/consents/me/${Uri.encodeComponent(clientId)}');
    _reload();
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
              Text('Connected applications', style: Theme.of(context).textTheme.headlineSmall),
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
                return Center(child: Text('Error: ${snap.error}'));
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Center(child: EmptyHint('No connected applications.'));
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
                      onPressed: () => _revoke(clientId),
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
