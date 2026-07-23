import 'package:flutter/material.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Recovery-code lifecycle. Plaintext codes are intentionally rendered only
/// from the one response that creates them and are never retained in state
/// after the user dismisses this card.
class RecoveryCodesCard extends StatefulWidget {
  final PortalApi api;

  const RecoveryCodesCard({super.key, required this.api});

  @override
  State<RecoveryCodesCard> createState() => _RecoveryCodesCardState();
}

class _RecoveryCodesCardState extends State<RecoveryCodesCard> {
  bool _loading = true;
  bool _busy = false;
  int? _remaining;
  String? _message;
  List<String>? _newCodes;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final response = await widget.api.get('/me/mfa/recovery-codes');
      if (!mounted) {
        return;
      }
      if (response.statusCode == 200) {
        setState(() {
          _remaining = int.tryParse(
            PortalApi.decode(response)['remaining']?.toString() ?? '',
          );
          _message = null;
        });
      } else if (response.statusCode == 404 || response.statusCode == 501) {
        setState(() => _message = 'Recovery codes are not enabled.');
      } else {
        setState(() => _message = 'Could not load recovery-code status.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not load recovery-code status.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace recovery codes?'),
        content: const Text(
          'Any unused recovery codes will stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace codes'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _newCodes = null;
    });
    try {
      final response = await widget.api.post('/me/mfa/recovery-codes');
      if (!mounted) {
        return;
      }
      if (response.statusCode == 201) {
        final codes =
            (PortalApi.decode(response)['recovery_codes'] as List?)
                ?.map((code) => code.toString())
                .toList(growable: false) ??
            const <String>[];
        setState(() {
          _newCodes = codes;
          _remaining = codes.length;
          _message = 'Save these codes now. They cannot be shown again.';
        });
      } else if (response.statusCode == 404 || response.statusCode == 501) {
        setState(() => _message = 'Recovery codes are not enabled.');
      } else {
        setState(() => _message = 'Could not generate recovery codes.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not generate recovery codes.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PortalCard(
    title: 'Recovery codes',
    children: [
      if (_loading)
        const LinearProgressIndicator()
      else ...[
        Text(
          _remaining == null
              ? 'Use one-time recovery codes if you lose your second factor.'
              : 'Recovery codes remaining: $_remaining',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _regenerate,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate new recovery codes'),
        ),
        MessageBanner(_message, ok: _newCodes != null),
        if (_newCodes != null) ...[
          const SizedBox(height: 12),
          SelectableText(_newCodes!.join('\n')),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => setState(() {
                _newCodes = null;
                _message =
                    'Recovery codes hidden. Keep your saved copy secure.';
              }),
              child: const Text('I have saved these codes'),
            ),
          ),
        ],
      ],
    ],
  );
}
