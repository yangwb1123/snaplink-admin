import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'dcr_form_controller.dart';
import 'dcr_models.dart';

class DcrMetadataForm extends StatelessWidget {
  static const _fallbackGrants = [
    'authorization_code',
    'refresh_token',
    'client_credentials',
    'urn:ietf:params:oauth:grant-type:token-exchange',
  ];
  static const _registrationAuthMethods = [
    'client_secret_basic',
    'client_secret_post',
    'none',
  ];

  final DcrFormController controller;
  final DcrDiscovery? discovery;
  final bool managementMode;
  final DcrRoundTripSafety? roundTripSafety;
  final VoidCallback onChanged;

  const DcrMetadataForm({
    super.key,
    required this.controller,
    this.discovery,
    this.managementMode = false,
    this.roundTripSafety,
    required this.onChanged,
  });

  void _onGrantSelected(String grant, bool selected) {
    if (selected) {
      controller.grantTypes.add(grant);
      if (grant == 'authorization_code') {
        controller.responseTypes.add('code');
      }
    } else {
      controller.grantTypes.remove(grant);
      if (grant == 'authorization_code') {
        controller.responseTypes.clear();
      }
    }
    onChanged();
  }

  void _onAuthMethodChanged(String? value) {
    if (value == null) return;
    controller.tokenEndpointAuthMethod = value;
    if (value == 'none') controller.requirePkce = true;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final grantOptions = _mergeOptions(
      discovery?.grantTypes.isNotEmpty == true
          ? discovery!.grantTypes
          : _fallbackGrants,
      controller.grantTypes,
    );
    final authOptions = _mergeOptions(
      _registrationAuthMethods.where(
        (method) =>
            discovery == null ||
            discovery!.tokenEndpointAuthMethods.isEmpty ||
            discovery!.tokenEndpointAuthMethods.contains(method),
      ),
      {controller.tokenEndpointAuthMethod},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context, 'Application'),
        TextField(
          controller: controller.clientName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: context.tr('App Name')),
        ),
        const SizedBox(height: 16),
        _lineField(
          controller.redirectUris,
          context.tr('Redirect URIs (one per line)'),
          helper: context.tr(
            'Required for authorization_code. Fragments are not allowed.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.scope,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: context.tr('Scopes (space-separated)'),
            helperText: discovery?.scopes.isNotEmpty == true
                ? context.tr('Advertised: {values}', {
                    'values': discovery!.scopes.join(', '),
                  })
                : null,
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'OAuth protocol'),
        Text(
          context.tr('Grant types'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final grant in grantOptions)
              FilterChip(
                label: LocalizedText(_shortGrant(grant)),
                selected: controller.grantTypes.contains(grant),
                onSelected:
                    managementMode && roundTripSafety?.grantTypesKnown == false
                    ? null
                    : (selected) => _onGrantSelected(grant, selected),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('Response types'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        FilterChip(
          label: const Text('code'),
          selected: controller.responseTypes.contains('code'),
          onSelected: (selected) {
            if (selected) {
              controller.responseTypes.add('code');
              controller.grantTypes.add('authorization_code');
            } else {
              controller.responseTypes.remove('code');
            }
            onChanged();
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'auth-${controller.tokenEndpointAuthMethod}-$managementMode',
          ),
          initialValue: controller.tokenEndpointAuthMethod,
          decoration: InputDecoration(
            labelText: context.tr('Token endpoint authentication'),
          ),
          items: [
            for (final method in authOptions)
              DropdownMenuItem(
                value: method,
                child: Text(context.tr(_authMethodLabel(method))),
              ),
          ],
          onChanged: managementMode
              ? null
              : (value) => _onAuthMethodChanged(value),
        ),
        if (managementMode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr(
                'Client credential type is locked because RFC 7592 PUT does not rotate or remove the stored client secret.',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('strategy-${controller.tokenStrategy}'),
          initialValue: controller.tokenStrategy,
          decoration: InputDecoration(labelText: context.tr('Token strategy')),
          items: const [
            DropdownMenuItem(value: 'jwt', child: Text('jwt')),
            DropdownMenuItem(value: 'session', child: Text('session')),
          ],
          onChanged: (value) {
            if (value == null) return;
            controller.tokenStrategy = value;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Require PKCE')),
          subtitle: Text(
            context.tr(
              controller.tokenEndpointAuthMethod == 'none'
                  ? 'Required for public clients; Snaplink stores S256 only.'
                  : 'When enabled, Snaplink stores S256 as the allowed method.',
            ),
          ),
          value:
              controller.requirePkce ||
              controller.tokenEndpointAuthMethod == 'none',
          onChanged: controller.tokenEndpointAuthMethod == 'none'
              ? null
              : (value) {
                  controller.requirePkce = value;
                  onChanged();
                },
        ),
        const SizedBox(height: 16),
        _sectionTitle(context, 'Application policy'),
        _lineField(
          controller.postLogoutRedirectUris,
          context.tr('Post-logout redirect URIs (one per line)'),
        ),
        const SizedBox(height: 16),
        _lineField(
          controller.allowedAuthenticators,
          context.tr('Allowed authenticators (one per line)'),
          helper: context.tr('Examples: password, webauthn, totp.'),
        ),
        const SizedBox(height: 16),
        _lineField(
          controller.allowedResources,
          context.tr('Allowed resources (one per line)'),
          helper: context.tr(
            'OAuth resource indicators accepted for this client.',
          ),
        ),
        const SizedBox(height: 16),
        _lineField(controller.contacts, context.tr('Contacts (one per line)')),
        const SizedBox(height: 16),
        TextField(
          controller: controller.tenantId,
          enabled: !managementMode,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: context.tr(
              managementMode
                  ? 'Tenant (immutable / not returned)'
                  : 'Tenant ID (operator-gated registration only)',
            ),
            helperText: context.tr(
              managementMode
                  ? 'Snaplink preserves the stored tenant and ignores tenant_id on PUT.'
                  : 'Open registration deliberately ignores this value.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Expert JSON'),
        TextField(
          controller: controller.expertJson,
          minLines: 4,
          maxLines: 12,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: context.tr('Additional metadata (JSON object)'),
            helperText: context.tr(
              'Typed and credential fields are rejected here. Unknown keys may be ignored by Snaplink; the response is authoritative.',
            ),
            hintText: '{"id_token_encrypted_response_alg":"RSA-OAEP-256"}',
          ),
        ),
      ],
    );
  }

  Widget _lineField(
    TextEditingController textController,
    String label, {
    String? helper,
    bool enabled = true,
  }) {
    return TextField(
      controller: textController,
      enabled: enabled,
      minLines: 2,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      context.tr(text),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );

  List<String> _mergeOptions(Iterable<String> values, Set<String> selected) {
    final seen = <String>{};
    return [...values, ...selected]
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList(growable: false);
  }

  String _shortGrant(String value) => value
      .replaceFirst('urn:ietf:params:oauth:grant-type:', '')
      .replaceAll('_', ' ');

  String _authMethodLabel(String value) =>
      const {
        'client_secret_basic': 'Confidential — HTTP Basic',
        'client_secret_post': 'Confidential — secret in POST body',
        'none': 'Public — no secret, PKCE S256 required',
        'tls_client_auth': 'mTLS client authentication',
        'self_signed_tls': 'Self-signed mTLS',
      }[value] ??
      value;
}
