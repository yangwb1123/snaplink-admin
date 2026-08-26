import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

/// Clears one brute-force lockout key without conflating it with a user ID.
class AccountLockoutCard extends StatefulWidget {
  final SnaplinkAdminApi api;

  const AccountLockoutCard({super.key, required this.api});

  @override
  State<AccountLockoutCard> createState() => _AccountLockoutCardState();
}

class _AccountLockoutCardState extends State<AccountLockoutCard> {
  static const _path = '/api/v1/admin/account-lockout/clear';
  final _clientController = TextEditingController();
  final _identifierController = TextEditingController();
  String? _error;
  bool _mutating = false;

  @override
  void dispose() {
    _clientController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    if (_mutating) return;
    final clientId = _clientController.text.trim();
    final identifier = _identifierController.text.trim();
    if (clientId.isEmpty || identifier.isEmpty) {
      setState(() {
        _error =
            'Client ID and the exact login identifier are required to clear a lockout.';
      });
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Clear account lockout?',
      message: context.tr('Unlock {identifier} for client {clientId}?', {
        'identifier': identifier,
        'clientId': clientId,
      }),
      confirmLabel: 'Clear lockout',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _error = null;
      _mutating = true;
    });
    try {
      await widget.api.post(_path, {
        'client_id': clientId,
        'identifier': identifier,
      });
      if (!mounted) return;
      _identifierController.clear();
      showAppSnackBar(
        context,
        content: LocalizedText('Account lockout cleared.'),
      );
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      // A transport failure is not a success signal; keep the action visible
      // and tell the operator that the server outcome was not confirmed.
      if (mounted) {
        setState(
          () => _error =
              context.tr('Request failed.'),
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Row(
              children: [
                Icon(
                  Icons.lock_open_outlined,
                  color: AppColors.semanticFor(
                    Theme.of(context).brightness,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LocalizedText(
                    'Account lockout recovery',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LocalizedText(
            'Lockouts are scoped by OAuth client and the exact username, email, '
            'or phone value used at login—not by the internal user ID.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('lockout-client-id'),
            controller: _clientController,
            enabled: !_mutating,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Client ID'.localized),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('lockout-identifier'),
            controller: _identifierController,
            enabled: !_mutating,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _clear(),
            decoration: InputDecoration(
              labelText: 'Login identifier'.localized,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('clear-account-lockout'),
            onPressed: _mutating ? null : _clear,
            icon: _mutating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open),
            label: const LocalizedText('Clear account lockout'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                style: TextStyle(
                  color: AppColors.semanticFor(
                    Theme.of(context).brightness,
                    AppColors.danger,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
