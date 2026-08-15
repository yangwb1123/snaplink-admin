import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Recovery-code lifecycle. Plaintext codes are intentionally rendered only
/// from the one response that creates them and are never retained in state
/// after the user dismisses this card — the "I have saved these codes"
/// action clears the only in-memory copy.
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Replace recovery codes?',
      message: 'Any unused recovery codes will stop working immediately.',
      confirmLabel: 'Replace codes',
      destructive: true,
    );
    if (!confirmed || !mounted) {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remaining;
    return PortalCard(
      title: 'Recovery codes',
      children: [
        if (_loading)
          const SkeletonListTile(itemCount: 1)
        else ...[
          if (remaining == null)
            Text(
              context.tr(
                'Use one-time recovery codes if you lose your second factor.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                label: context.tr('Recovery codes remaining: {count}', {
                  'count': remaining,
                }),
                color: remaining < 3 ? AppColors.warning : AppColors.success,
                icon: Icons.shield_outlined,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _regenerate,
            icon: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assignment_outlined),
            label: Text(context.tr('Generate new recovery codes')),
          ),
          MessageBanner(_message, ok: _newCodes != null),
          if (_newCodes != null) ...[
            const SizedBox(height: 12),
            _CodesBox(codes: _newCodes!),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  _newCodes = null;
                  _message = 'Recovery codes hidden. Keep your saved copy secure.';
                }),
                icon: const Icon(Icons.save_outlined),
                label: Text(context.tr('I have saved these codes')),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// One-time recovery-code display: bordered mono box. SelectableText keeps
/// the codes copyable; the list is dropped from state the moment the user
/// confirms they saved them.
class _CodesBox extends StatelessWidget {
  final List<String> codes;
  const _CodesBox({required this.codes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: SelectableText(
        codes.join('\n'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 1.6,
        ),
      ),
    );
  }
}
