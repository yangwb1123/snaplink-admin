import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

import '../../i18n/app_strings.dart';
import 'portal_api.dart';

/// Builds the hosted-login location for an unauthenticated portal visit.
///
/// Only the same-origin portal path and query are retained as the post-login
/// target; fragments and authority components never cross the authentication
/// boundary.
String portalLoginLocation(Uri current) {
  final isPortalPath =
      current.path == '/portal' || current.path.startsWith('/portal/');
  final path = isPortalPath ? current.path : '/portal/';
  final action = PortalActionRoute.fromUri(current);
  const privateParameters = {
    'access_token',
    'assertion',
    'code',
    'code_verifier',
    'consent_challenge_id',
    'consent_decision',
    'credential',
    'device_token',
    'email',
    'error',
    'error_description',
    'id_token',
    'login_transaction_id',
    'mfa_challenge_id',
    'mfa_method',
    'password',
    'refresh_token',
    'state',
    'verification_code',
  };
  final query = <String, dynamic>{};
  if (isPortalPath) {
    if (action.isAvailable) {
      query['flow'] = switch (action.kind) {
        PortalActionKind.changeEmail => 'change_email',
        PortalActionKind.invitation => 'invitation',
        null => '',
      };
      query['token'] = action.token;
    }
    for (final entry in current.queryParametersAll.entries) {
      if (privateParameters.contains(entry.key) ||
          entry.key == 'flow' ||
          entry.key == 'token') {
        continue;
      }
      query[entry.key] = entry.value.length == 1
          ? entry.value.single
          : entry.value;
    }
  }
  final target = Uri(
    path: path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
  return current
      .resolve('/login/')
      .replace(queryParameters: {'redirect': target})
      .toString();
}

/// Removes one-time account-action material after the portal takes ownership
/// of it, while retaining unrelated local navigation query parameters.
String portalLocationWithoutAction(Uri current) {
  final isPortalPath =
      current.path == '/portal' || current.path.startsWith('/portal/');
  if (!isPortalPath) return '/portal/';

  final query = <String, dynamic>{
    for (final entry in current.queryParametersAll.entries)
      if (entry.key != 'flow' && entry.key != 'token')
        entry.key: entry.value.length == 1 ? entry.value.single : entry.value,
  };
  return Uri(
    path: current.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

enum PortalActionKind { changeEmail, invitation }

/// A one-time account action carried through hosted login.
///
/// The action only chooses the backend verifier. The opaque token remains
/// authoritative: presenting an invitation token to the email verifier (or
/// vice versa) is rejected by the server.
class PortalActionRoute {
  final PortalActionKind? kind;
  final String token;

  const PortalActionRoute({required this.kind, required this.token});

  factory PortalActionRoute.fromUri(Uri uri) {
    final flowValues = uri.queryParametersAll['flow'] ?? const <String>[];
    final tokenValues = uri.queryParametersAll['token'] ?? const <String>[];
    if (flowValues.length != 1 || tokenValues.length != 1) {
      return const PortalActionRoute(kind: null, token: '');
    }
    final kind = switch (flowValues.single.trim()) {
      'change_email' || 'email_change' => PortalActionKind.changeEmail,
      'invitation' || 'invite' => PortalActionKind.invitation,
      _ => null,
    };
    return PortalActionRoute(kind: kind, token: tokenValues.single.trim());
  }

  bool get isAvailable => kind != null && token.isNotEmpty;

  String get endpoint => switch (kind) {
    PortalActionKind.changeEmail => '/me/email/verify',
    PortalActionKind.invitation => '/me/invitations/accept',
    null => '',
  };

  int get navigationIndex => switch (kind) {
    PortalActionKind.changeEmail => 1,
    PortalActionKind.invitation => 7,
    null => 0,
  };

  String get successMessage => switch (kind) {
    PortalActionKind.changeEmail =>
      'Your new email address has been confirmed.',
    PortalActionKind.invitation =>
      'The organization invitation has been accepted.',
    null => '',
  };

  String get failureMessage => switch (kind) {
    PortalActionKind.changeEmail =>
      'This email confirmation link is invalid or expired.',
    PortalActionKind.invitation =>
      'This organization invitation is invalid or expired.',
    null => '',
  };

  Future<PortalActionResult> complete(PortalApi api) async {
    try {
      final response = await api.post(endpoint, {'token': token});
      final succeeded = response.statusCode >= 200 && response.statusCode < 300;
      return PortalActionResult(
        succeeded: succeeded,
        message: succeeded ? successMessage : failureMessage,
      );
    } catch (_) {
      return PortalActionResult(succeeded: false, message: failureMessage);
    }
  }
}

class PortalActionResult {
  final bool succeeded;
  final String message;

  const PortalActionResult({required this.succeeded, required this.message});
}

class PortalActionNotice extends StatelessWidget {
  final String message;
  final bool succeeded;

  const PortalActionNotice({
    super.key,
    required this.message,
    required this.succeeded,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: succeeded
        ? AppColors.success.withValues(alpha: 0.12)
        : Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: Icon(
        succeeded ? Icons.check_circle : Icons.error,
        color: succeeded
            ? AppColors.success
            : Theme.of(context).colorScheme.onErrorContainer,
      ),
      title: Text(context.tr(message)),
    ),
  );
}

class PortalEntryProgress extends StatelessWidget {
  final bool redirecting;

  const PortalEntryProgress({super.key, required this.redirecting});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (redirecting) ...[
              const SizedBox(height: 16),
              Text(strings.redirectingToSignIn),
            ],
          ],
        ),
      ),
    );
  }
}

class PortalTokenGate extends StatelessWidget {
  final TextEditingController tokenController;
  final bool loggingIn;
  final String? error;
  final String? notice;
  final VoidCallback onLogin;
  final VoidCallback? onRetry;

  const PortalTokenGate({
    super.key,
    required this.tokenController,
    required this.loggingIn,
    required this.error,
    required this.notice,
    required this.onLogin,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.account_circle,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.accountTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.accountSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: tokenController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: strings.accessToken,
                      ),
                      onSubmitted: (_) => onLogin(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: loggingIn ? null : onLogin,
                      child: loggingIn
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(strings.continueLabel),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: loggingIn ? null : onRetry,
                        child: Text(strings.retry),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    if (notice != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        notice!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.success),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
