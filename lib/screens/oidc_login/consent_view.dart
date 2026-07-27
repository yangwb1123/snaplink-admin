import 'dart:convert';

import 'package:flutter/material.dart';

import 'hosted_login_models.dart';

class ConsentView extends StatelessWidget {
  final String clientName;
  final String clientId;
  final ConsentRequestSummary summary;
  final String? error;
  final bool loading;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const ConsentView({
    super.key,
    required this.clientName,
    required this.clientId,
    required this.summary,
    this.error,
    required this.loading,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appName = clientName.isNotEmpty ? clientName : clientId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${appName.isNotEmpty ? appName : 'This application'} wants access',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('Review every permission before you continue.'),
        if (summary.scopes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Permissions', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final scope in summary.scopes) _ScopeRow(scope: scope),
        ],
        if (summary.authorizationDetails.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Fine-grained authorization', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final indexed in summary.authorizationDetails.indexed)
            _AuthorizationDetailCard(index: indexed.$1, detail: indexed.$2),
        ],
        if (!summary.canAuthorize) ...[
          const SizedBox(height: 14),
          _ConsentWarning(
            message:
                summary.parseError ?? ConsentRequestSummary.consentSummaryError,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : onDeny,
                child: const Text('Deny'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: loading || !summary.canAuthorize ? null : onAllow,
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Allow'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScopeRow extends StatelessWidget {
  final ConsentScopeDescriptor scope;

  const _ScopeRow({required this.scope});

  @override
  Widget build(BuildContext context) {
    final description = scope.description.isNotEmpty
        ? scope.description
        : _fallbackScopeLabel(scope.scope);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                Text(
                  'Scope: ${scope.scope}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fallbackScopeLabel(String scope) =>
      const {
        'openid': 'Verify your identity',
        'profile': 'View your profile',
        'email': 'View your email address',
        'offline_access': 'Stay signed in',
      }[scope] ??
      scope;
}

class _AuthorizationDetailCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> detail;

  const _AuthorizationDetailCard({required this.index, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = detail['type']?.toString().trim() ?? '';
    final summary = _commonFields(detail);
    final json = const JsonEncoder.withIndent('  ').convert(detail);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              type.isEmpty ? 'Authorization detail ${index + 1}' : type,
              style: theme.textTheme.titleSmall,
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final line in summary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(line),
                ),
            ],
            const SizedBox(height: 8),
            Text('Exact request', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                json,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _commonFields(Map<String, dynamic> value) {
    final lines = <String>[];
    for (final key in const [
      'actions',
      'locations',
      'datatypes',
      'identifier',
    ]) {
      final field = value[key];
      if (field == null) continue;
      final text = field is List ? field.join(', ') : field.toString();
      if (text.trim().isNotEmpty) {
        lines.add('${_title(key)}: $text');
      }
    }
    return lines;
  }

  String _title(String value) =>
      '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}

class _ConsentWarning extends StatelessWidget {
  final String message;

  const _ConsentWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$message Authorization has been disabled.',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
