import 'package:flutter/material.dart';

import 'dcr_models.dart';

class DcrFormController {
  final clientName = TextEditingController();
  final redirectUris = TextEditingController();
  final scope = TextEditingController();
  final contacts = TextEditingController();
  final postLogoutRedirectUris = TextEditingController();
  final allowedAuthenticators = TextEditingController();
  final allowedResources = TextEditingController();
  final tenantId = TextEditingController();
  final expertJson = TextEditingController();

  String tokenEndpointAuthMethod = 'client_secret_basic';
  String tokenStrategy = 'jwt';
  Set<String> grantTypes = {'authorization_code'};
  Set<String> responseTypes = {'code'};
  bool requirePkce = false;

  DcrFormController() {
    populate(DcrClientMetadata.defaults());
  }

  void populate(DcrClientMetadata metadata) {
    clientName.text = metadata.clientName;
    redirectUris.text = metadata.redirectUris.join('\n');
    scope.text = metadata.scope;
    contacts.text = metadata.contacts.join('\n');
    postLogoutRedirectUris.text = metadata.postLogoutRedirectUris.join('\n');
    allowedAuthenticators.text = metadata.allowedAuthenticators.join('\n');
    allowedResources.text = metadata.allowedResources.join('\n');
    tenantId.text = metadata.tenantId;
    expertJson.text = metadata.expertMetadata.isEmpty
        ? ''
        : metadata.expertJson();
    tokenEndpointAuthMethod = metadata.tokenEndpointAuthMethod;
    tokenStrategy = metadata.tokenStrategy;
    grantTypes = metadata.grantTypes.toSet();
    responseTypes = metadata.responseTypes.toSet();
    requirePkce =
        metadata.requirePkce || metadata.tokenEndpointAuthMethod == 'none';
  }

  DcrClientMetadata metadata() {
    return DcrClientMetadata(
      clientName: clientName.text.trim(),
      redirectUris: _splitLines(redirectUris.text),
      scope: scope.text.trim(),
      tokenEndpointAuthMethod: tokenEndpointAuthMethod,
      tokenStrategy: tokenStrategy,
      grantTypes: grantTypes.toList(growable: false),
      responseTypes: responseTypes.toList(growable: false),
      contacts: _splitLines(contacts.text),
      postLogoutRedirectUris: _splitLines(postLogoutRedirectUris.text),
      allowedAuthenticators: _splitLines(allowedAuthenticators.text),
      allowedResources: _splitLines(allowedResources.text),
      tenantId: tenantId.text.trim(),
      requirePkce: requirePkce || tokenEndpointAuthMethod == 'none',
      expertMetadata: DcrClientMetadata.parseExpertJson(expertJson.text),
    );
  }

  List<String> _splitLines(String raw) => raw
      .split(RegExp(r'[\r\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  void dispose() {
    clientName.dispose();
    redirectUris.dispose();
    scope.dispose();
    contacts.dispose();
    postLogoutRedirectUris.dispose();
    allowedAuthenticators.dispose();
    allowedResources.dispose();
    tenantId.dispose();
    expertJson.dispose();
  }
}
