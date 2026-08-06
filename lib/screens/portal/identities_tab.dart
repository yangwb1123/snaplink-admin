import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Linked external identities for the current account.
class IdentitiesTab extends StatefulWidget {
  final PortalApi api;

  const IdentitiesTab({super.key, required this.api});

  @override
  State<IdentitiesTab> createState() => _IdentitiesTabState();
}

class _IdentitiesTabState extends State<IdentitiesTab> {
  bool _loading = true;
  bool _available = true;
  List<Map<String, dynamic>> _identities = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final response = await widget.api.get('/me/identities');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final values =
            PortalApi.decode(response)['identities'] as List? ?? const [];
        setState(() {
          _available = true;
          _identities = values
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList(growable: false);
        });
      } else if (response.statusCode == 404) {
        setState(() => _available = false);
      } else {
        setState(() => _message = 'Could not load linked identities.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not load linked identities.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlink(Map<String, dynamic> identity) async {
    final id = identity['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Unlink identity?')),
        content: Text(
          context.tr(
            'You may be unable to sign in with this provider after unlinking it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Unlink')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final response = await widget.api.delete(
        '/me/identities/${Uri.encodeComponent(id)}',
      );
      if (!mounted) {
        return;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _load();
      } else if (response.statusCode == 409) {
        setState(
          () => _message =
              'Add another sign-in method before unlinking this identity.',
        );
      } else {
        setState(() => _message = 'Could not unlink this identity.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not unlink this identity.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Text(
            context.strings.linkedIdentities,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
          ),          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

        const SizedBox(height: 4),
        const LocalizedText(
          'Third-party identities linked to your account for sign-in.',
          style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
        ),      const SizedBox(height: 12),
      if (_loading)
        const LinearProgressIndicator()
      else if (!_available)
        const EmptyHint('Linked-identity management is not enabled.')
      else if (_identities.isEmpty)
        const EmptyHint('No external identities are linked to this account.')
      else
        PortalCard(
          title: 'External sign-in methods',
          children: [
            for (final identity in _identities)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(identity['provider']?.toString() ?? ''),
                subtitle: Text(
                  '${identity['subject'] ?? ''}${identity['linked_at'] == null ? '' : context.tr(' · linked {time}', {'time': identity['linked_at']})}',
                ),
                trailing: TextButton(
                  onPressed: () => _unlink(identity),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: Text(context.tr('Unlink')),
                ),
              ),
          ],
        ),
      MessageBanner(_message, ok: false),
    ],
  );
}
