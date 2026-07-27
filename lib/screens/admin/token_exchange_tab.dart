import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

/// Token exchange chain audit view tab.
class TokenExchangeTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenExchangeTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<TokenExchangeTab> createState() => _TokenExchangeTabState();
}

class _TokenExchangeTabState extends State<TokenExchangeTab> {
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _chain;
  String? _error;
  bool _loading = false;

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix('/api/v1/admin/tokenexchange');
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final jti = _searchCtrl.text.trim();
    if (jti.isEmpty) {
      setState(() => _error = 'Enter a token ID (jti).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _chain = null;
    });
    try {
      final data = await widget.api.get(
        '/api/v1/admin/tokenexchange/chains/${Uri.encodeComponent(jti)}',
      );
      if (!mounted) return;
      setState(() {
        _chain = data;
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load exchange chain.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(child: Text('Token exchange audit is not enabled.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppStrings.of(context).tokenExchange,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        AdminBreadcrumb(),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Token ID (JTI)',
                  hintText: 'Enter a token JTI to trace its exchange chain',
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.search),
              tooltip: 'Search',
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_loading) const SkeletonListTile(itemCount: 3),
        if (_chain != null) ...[
          const SizedBox(height: 16),
          Text(
            'Exchange chain',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _chainData(context, _chain!),
        ],
      ],
    );
  }

  Widget _chainData(BuildContext context, Map<String, dynamic> data) {
    final chains = data['chains'] as List? ?? data['chain'] as List? ?? [data];
    return Column(
      children: [
        for (final c in chains)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(
                    'Subject',
                    c['subject']?.toString() ?? c['sub']?.toString() ?? '',
                  ),
                  _row(
                    'Actor',
                    c['actor']?.toString() ?? c['actor_id']?.toString() ?? '',
                  ),
                  _row('Source Token', c['source_jti']?.toString() ?? ''),
                  _row(
                    'Target Token',
                    c['target_jti']?.toString() ?? c['jti']?.toString() ?? '',
                  ),
                  _row('Grant Type', c['grant_type']?.toString() ?? ''),
                  _row(
                    'Scope',
                    (c['scopes'] as List?)?.join(', ') ??
                        c['scope']?.toString() ??
                        '',
                  ),
                  _row('Client', c['client_id']?.toString() ?? ''),
                  _row(
                    'Timestamp',
                    c['timestamp']?.toString() ??
                        c['created_at']?.toString() ??
                        '',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
