import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'scim_browser_widgets.dart';
import 'scim_models.dart';

class ScimBulkPanel extends StatefulWidget {
  final SnaplinkAdminApi api;

  const ScimBulkPanel({super.key, required this.api});

  @override
  State<ScimBulkPanel> createState() => _ScimBulkPanelState();
}

class _ScimBulkPanelState extends State<ScimBulkPanel> {
  static const _defaultMaxOperations = 1000;
  static const _defaultMaxPayload = 1024 * 1024;

  final _controller = TextEditingController();
  ScimServiceProfile? _profile;
  ScimBulkPreview? _preview;
  Map<String, dynamic>? _result;
  String? _error;
  bool _loadingProfile = false;
  bool _submitting = false;
  bool _unavailable = false;
  bool _outcomeUnknown = false;

  int get _maxOperations =>
      _profile?.bulkMaxOperations ?? _defaultMaxOperations;
  int get _maxPayload => _profile?.bulkMaxPayloadSize ?? _defaultMaxPayload;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
    _validate();
    _loadProfile();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_validate)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _error = null;
      _unavailable = false;
      _profile = null;
    });
    try {
      final data = await widget.api.get(
        '$scimBasePath/ServiceProviderConfig',
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => _profile = ScimServiceProfile.fromJson(data));
      _validate();
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return;
      if (error.status == 404 || error.status == 501) {
        setState(() => _unavailable = true);
      } else {
        setState(
          () => _error = context.tr(
            'Could not load bulk limits ({status}): {error}',
            {'status': '${error.status}', 'error': error.toString()},
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Could not load bulk limits.'));
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _validate() {
    final preview = ScimBulkPreview.parse(
      _controller.text,
      maxOperations: _maxOperations,
      maxPayloadSize: _maxPayload,
    );
    if (mounted) setState(() => _preview = preview);
  }

  void _loadTemplate() {
    const template = {
      'schemas': [scimBulkRequestSchema],
      'failOnErrors': 1,
      'Operations': [],
    };
    _controller.text = const JsonEncoder.withIndent('  ').convert(template);
  }

  /// 执行前置检查：失败时返回已入目录的错误文案 key。
  String? _guardError() {
    if (_outcomeUnknown) {
      return 'Reconcile Users and Groups before authorizing another bulk '
          'request.';
    }
    if (_profile?.bulk != true) {
      return 'Bulk execution is disabled until capability discovery '
          'succeeds.';
    }
    _validate();
    final preview = _preview;
    if (preview == null || !preview.isValid || preview.body == null) {
      return 'Valid bulk JSON is required.';
    }
    return null;
  }

  Future<void> _submit() async {
    final guard = _guardError();
    if (guard != null) {
      setState(() => _error = context.tr(guard));
      return;
    }
    final preview = _preview!;
    final deletes = preview.methodCounts['DELETE'] ?? 0;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Execute ${preview.operationCount} SCIM operations?',
      message:
          'The server processes operations in order. Per-operation failures '
          'do not roll back earlier successes. '
          '${deletes > 0 ? 'This request contains $deletes permanent deletes.' : ''}',
      confirmLabel: 'Execute bulk',
      destructive: deletes > 0,
      confirmText: deletes > 0 ? 'BULK' : null,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.api.post(
        '$scimBasePath/Bulk',
        preview.body,
        scimContentType,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _outcomeUnknown = false;
        });
      }
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return;
      final unknown =
          error.status >= 500 || error.status == 408 || error.status == 429;
      setState(() {
        if (error.status == 404 || error.status == 501) {
          _unavailable = true;
        } else {
          _outcomeUnknown = unknown;
          _error = unknown
              ? context.tr(
                  'Bulk result is unknown (HTTP {status}). Operations '
                  'may have partially applied. Reconcile Users and Groups '
                  'before acknowledging and sending another request.',
                  {'status': '${error.status}'},
                )
              : context.tr('Bulk was rejected ({status}): {error}', {
                  'status': '${error.status}',
                  'error': error.toString(),
                });
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _outcomeUnknown = true;
        _error = context.tr(
          'Bulk result is unknown because the response was not received. '
          'Operations may have partially applied. Reconcile Users and '
          'Groups before acknowledging and sending another request.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _acknowledgeReconciliation() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reconciliation complete?',
      message:
          'Confirm only after comparing the requested operations with the '
          'current Users and Groups state. This unlocks the retained draft; '
          'it does not prove the previous request failed.',
      confirmLabel: 'Unlock draft',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _outcomeUnknown = false;
      _error = context.tr(
        'Reconciliation acknowledged. Review the draft before sending.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return ScimUnavailable(onRetry: _loadProfile);
    final preview = _preview;
    final supported = _profile?.bulk == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            // R33：标题 Expanded（窄屏/字号缩放换行而非溢出），操作区仍贴右。
            Expanded(child: LocalizedText('SCIM Bulk', style: Theme.of(context).textTheme.titleLarge)),
            if (_loadingProfile)
              const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _submitting || _loadingProfile || !supported || _outcomeUnknown
                  ? null
                  : _loadTemplate,
              icon: const Icon(Icons.description_outlined),
              label: const LocalizedText('Load template'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LocalizedText(
          'Bounded expert mode · max {maxOperations} operations · '
          'max {maxPayload}. POST operations require bulkId; targets are '
          'limited to /Users and /Groups.',
          args: {'maxOperations': '$_maxOperations', 'maxPayload': formatScimBytes(_maxPayload)},
        ),
        const SizedBox(height: 12),
        _NoticeCard(
          background: Theme.of(context).colorScheme.secondaryContainer,
          icon: Icons.security_outlined,
          title: 'Validate before execution',
          subtitle: 'Empty, malformed, oversized, recursive, or unsupported '
              'requests cannot be sent. Keep credentials and secrets out of '
              'the editor; the server returns per-operation status.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: !_submitting && supported && !_outcomeUnknown,
          minLines: 14,
          maxLines: 24,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'BulkRequest JSON'.localized,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            errorText: _controller.text.isEmpty ? null : preview?.error,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ScimMetric(
              label: 'Operations',
              value: '${preview?.operationCount ?? 0}',
            ),
            ScimMetric(
              label: 'Payload',
              value: formatScimBytes(preview?.payloadBytes ?? 0),
            ),
            for (final entry in (preview?.methodCounts ?? const {}).entries)
              ScimMetric(label: entry.key, value: '${entry.value}'),
            FilledButton.icon(
              onPressed: preview?.isValid == true && !_submitting && supported && !_outcomeUnknown
                  ? _submit
                  : null,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const LocalizedText('Execute bulk'),
            ),
          ],
        ),
        if (!supported && !_loadingProfile && _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LocalizedText(
              'This service provider does not advertise Bulk.',
            ),
          ),
        if (_outcomeUnknown)
          _NoticeCard(
            icon: Icons.sync_problem_outlined,
            title: 'Previous bulk outcome is unknown',
            subtitle:
                'The retained request is locked until server state has '
                'been reconciled.',
            trailing: TextButton(
              onPressed: _acknowledgeReconciliation,
              child: const LocalizedText('I reconciled server state'),
            ),
          ),
        if (_error != null)
          _NoticeCard(
            icon: Icons.error_outline,
            title: _error!,
            trailing: _profile == null && !_outcomeUnknown
                ? TextButton.icon(
                    onPressed: _loadingProfile ? null : _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const LocalizedText('Retry discovery'),
                  )
                : null,
          ),
        if (_result != null) ...[
          ScimBulkResultSummary(result: _result!),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: true,
            title: const LocalizedText('Bulk response'),
            subtitle: const LocalizedText('Per-operation status; overall HTTP is 200'),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(SensitiveData.redact(_result)),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 批量面板的消息卡（安全提示 / 未知结果 / 错误），统一 ListTile 模板。
/// 默认错误底色；`background` 可覆盖（如安全提示的 secondaryContainer）。
class _NoticeCard extends StatelessWidget {
  final Color? background;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _NoticeCard({
    this.background,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: background ?? Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: Icon(icon),
      title: LocalizedText(title),
      subtitle: subtitle == null ? null : LocalizedText(subtitle!),
      trailing: trailing,
    ),
  );
}
