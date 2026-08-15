import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/empty_state.dart';

class SensitiveTokenField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;

  const SensitiveTokenField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.enabled = true,
    this.readOnly = false,
    this.onSubmitted,
  });

  @override
  State<SensitiveTokenField> createState() => _SensitiveTokenFieldState();
}

class _SensitiveTokenFieldState extends State<SensitiveTokenField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [],
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: context.tr(widget.label),
        hintText: widget.hintText == null ? null : context.tr(widget.hintText!),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.tr(_visible ? 'Hide' : 'Show'),
              onPressed: widget.enabled
                  ? () => setState(() => _visible = !_visible)
                  : null,
              icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: widget.enabled ? scheme.primary : null),
            ),
            PopupMenuButton<String>(
              tooltip: context.tr('{label} actions', {
                'label': context.tr(widget.label),
              }),
              onSelected: (action) {
                if (action == 'copy') {
                  copyDcrValue(context, widget.label, widget.controller.text);
                } else if (action == 'clear') {
                  widget.controller.clear();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'copy', child: Text(context.tr('Copy'))),
                PopupMenuItem(value: 'clear', enabled: !widget.readOnly && widget.enabled, child: Text(context.tr('Clear'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CopyableDcrValue extends StatelessWidget {
  final String label;
  final String value;
  final bool sensitive;

  const CopyableDcrValue({
    super.key,
    required this.label,
    required this.value,
    this.sensitive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(label).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6),
                ),
              ),
              IconButton(
                tooltip: context.tr('Copy {label}', {
                  'label': context.tr(label),
                }),
                onPressed: () => copyDcrValue(context, label, value),
                icon: Icon(Icons.copy_outlined, size: 19, color: scheme.primary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SelectableText(
              value.isEmpty ? context.tr('Not returned.') : value,
              key: ValueKey('dcr-value-$label'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          if (sensitive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('One-time credential'),
                style: TextStyle(fontSize: 11, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> copyDcrValue(
  BuildContext context,
  String label,
  String value,
) async {
  if (value.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  showAppSnackBar(context, content: Text(
        context.tr('{label} copied.', {'label': context.tr(label)}),
      ));
}

class OneTimeRegistrationCredentials extends StatefulWidget {
  final Map<String, dynamic> result;
  final VoidCallback onManage;
  final VoidCallback onWipe;

  const OneTimeRegistrationCredentials({
    super.key,
    required this.result,
    required this.onManage,
    required this.onWipe,
  });

  @override
  State<OneTimeRegistrationCredentials> createState() =>
      _OneTimeRegistrationCredentialsState();
}

class _OneTimeRegistrationCredentialsState
    extends State<OneTimeRegistrationCredentials> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final clientId = widget.result['client_id']?.toString() ?? '';
    final clientSecret = widget.result['client_secret']?.toString() ?? '';
    final rat = widget.result['registration_access_token']?.toString() ?? '';
    final managementUri =
        widget.result['registration_client_uri']?.toString() ?? '';

    final issuedSomething =
        clientId.isNotEmpty ||
        clientSecret.isNotEmpty ||
        rat.isNotEmpty ||
        managementUri.isNotEmpty;

    if (!issuedSomething) {
      return const EmptyState(
        compact: true,
        icon: Icons.key_off_outlined,
        title: 'No credentials were issued.',
      );
    }
    if (clientId.isEmpty) {
      return const _MalformedCredentialNotice();
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('SAVE THESE CREDENTIALS NOW'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'The client secret and registration access token will not be shown again. Copy each required value before continuing.',
              ),
            ),
            const SizedBox(height: 12),
            CopyableDcrValue(label: 'Client ID', value: clientId),
            if (clientSecret.isNotEmpty)
              CopyableDcrValue(
                label: 'Client Secret',
                value: clientSecret,
                sensitive: true,
              ),
            if (rat.isNotEmpty)
              CopyableDcrValue(
                label: 'Registration Access Token',
                value: rat,
                sensitive: true,
              ),
            if (managementUri.isNotEmpty)
              CopyableDcrValue(
                label: 'Registration Client URI',
                value: managementUri,
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              title: Text(
                context.tr('I have securely saved every credential I need.'),
              ),
              subtitle: Text(
                context.tr(
                  'Continuing erases the one-time credential display.',
                ),
              ),
            ),
            if (rat.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: _confirmed ? widget.onManage : null,
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: Text(context.tr('Manage App')),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _confirmed ? widget.onWipe : null,
              style: AppColors.dangerOutlinedStyle(context),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(context.tr('Done and Erase')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MalformedCredentialNotice extends StatelessWidget {
  const _MalformedCredentialNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(
                  'The registration response was incomplete: the client ID '
                  'is missing, so the issued credentials cannot be managed '
                  'or erased here.',
                ),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// RFC 7592 RAT rotation confirmation: the replacement token is shown
/// once and the dialog cannot be dismissed until it is saved.
class RotatedRegistrationTokenDialog extends StatefulWidget {
  final String token;
  final VoidCallback onConfirmed;

  const RotatedRegistrationTokenDialog({
    super.key,
    required this.token,
    required this.onConfirmed,
  });

  @override
  State<RotatedRegistrationTokenDialog> createState() =>
      _RotatedRegistrationTokenDialogState();
}

class _RotatedRegistrationTokenDialogState
    extends State<RotatedRegistrationTokenDialog> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(Icons.key_outlined, color: scheme.primary),
        title: Text(context.tr('Registration token rotated')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr(
                  'Save this replacement token now. The previous token remains valid only during the server-defined overlap window.',
                ),
              ),
              const SizedBox(height: 12),
              CopyableDcrValue(
                label: 'New Registration Access Token',
                value: widget.token,
                sensitive: true,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _saved,
                onChanged: (value) => setState(() => _saved = value ?? false),
                title: Text(
                  context.tr('I have securely saved the new token.'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _saved
                ? () {
                    widget.onConfirmed();
                    Navigator.of(context).pop();
                  }
                : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(context.tr('Continue and Erase Display')),
          ),
        ],
      ),
    );
  }
}
