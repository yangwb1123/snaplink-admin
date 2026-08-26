import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/pressable_scale.dart';
import 'package:sso_admin/widgets/section_header.dart';

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
    final strings = AppStrings.of(context);
    final appName = clientName.isNotEmpty ? clientName : clientId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            context.tr('{application} wants access', {
              'application': appName.isNotEmpty
                  ? appName
                  : context.tr('This application'),
            }),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(context.tr('Review every permission before you continue.')),
        if (summary.scopes.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(strings.permissions, count: summary.scopes.length),
          const SizedBox(height: 8),
          _ScopeListCard(scopes: summary.scopes),
        ],
        if (summary.authorizationDetails.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader(
            context.tr('Fine-grained authorization'),
            count: summary.authorizationDetails.length,
          ),
          const SizedBox(height: 8),
          for (final indexed in summary.authorizationDetails.indexed)
            _AuthorizationDetailCard(index: indexed.$1, detail: indexed.$2),
        ],
        if (!summary.canAuthorize) ...[
          const SizedBox(height: 16),
          _notice(
            context,
            context.tr('{message} Authorization has been disabled.', {
              'message': context.tr(
                summary.parseError ?? ConsentRequestSummary.consentSummaryError,
              ),
            }),
            Icons.warning_amber_outlined,
            color: theme.colorScheme.onErrorContainer,
            contained: true,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          _notice(
            context,
            context.tr(error!),
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            contained: true,
            live: true,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: PressableScale(
                child: OutlinedButton(
                  onPressed: loading ? null : onDeny,
                  style: AppColors.dangerOutlinedStyle(context).copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                  ),
                  child: Text(strings.deny, softWrap: true),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PressableScale(
                child: FilledButton(
                  onPressed: loading || !summary.canAuthorize ? null : onAllow,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: loading
                      ? Semantics(
                          label: strings.loading,
                          child: const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Text(context.tr('Allow'), softWrap: true),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 内联提示条：品牌/语义色图标 + 文案。`contained` 变体 = errorContainer
  /// 底（警告/错误），替代手写 `Text` + `SizedBox` 模板。
  Widget _notice(
    BuildContext context,
    String text,
    IconData icon, {
    Color? color,
    bool contained = false,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color ?? scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color ?? scheme.primary)),
        ),
      ],
    );
    final wrapped = contained
        ? Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: row,
          )
        : row;
    return live ? Semantics(liveRegion: true, child: wrapped) : wrapped;
  }
}

class _ScopeListCard extends StatelessWidget {
  final List<ConsentScopeDescriptor> scopes;

  const _ScopeListCard({required this.scopes});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < scopes.length; index++) ...[
          _ScopeRow(scope: scopes[index]),
          if (index < scopes.length - 1)
            const Divider(height: 1, indent: 44, endIndent: 12),
        ],
      ],
    ),
  );
}

class _ScopeRow extends StatelessWidget {
  final ConsentScopeDescriptor scope;

  const _ScopeRow({required this.scope});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = scope.description.isNotEmpty
        ? scope.description
        : context.tr(_fallbackScopeLabel(scope.scope));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_outline,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, softWrap: true),
                Text(
                  context.tr('Scope: {scope}', {'scope': scope.scope}),
                  softWrap: true,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
    final summary = _commonFields(context, detail);
    final json = const JsonEncoder.withIndent('  ').convert(detail);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rule_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.isEmpty
                        ? context.tr('Authorization detail {number}', {
                            'number': index + 1,
                          })
                        : type,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final line in summary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              context.tr('Exact request'),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
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

  List<String> _commonFields(BuildContext context, Map<String, dynamic> value) {
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
        lines.add('${context.tr(_title(key))}: $text');
      }
    }
    return lines;
  }

  String _title(String value) =>
      '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}
