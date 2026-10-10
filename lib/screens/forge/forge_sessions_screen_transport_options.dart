part of 'forge_sessions_screen.dart';

/// Immutable Forge identity, transport and initial route configuration.
abstract class _ForgeSessionsTransport extends StatefulWidget {
  final String accessToken;
  final String apiOrigin;
  final bool enableConversationChangesStream;
  final int conversationChangesStreamWaitMS;
  final String? initialConversationID;
  final String? initialClientInstanceID;
  final http.Client? httpClient;
  final http.Client? oauthHttpClient;
  final Duration oauthRevocationTimeout;
  final ForgeCredentialStore? credentialStore;

  const _ForgeSessionsTransport({
    super.key,
    required this.accessToken,
    required this.apiOrigin,
    this.enableConversationChangesStream = false,
    this.conversationChangesStreamWaitMS = 15000,
    this.initialConversationID,
    this.initialClientInstanceID,
    this.httpClient,
    this.oauthHttpClient,
    this.oauthRevocationTimeout = const Duration(seconds: 5),
    this.credentialStore,
  });
}
