import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'scim_browser_widgets.dart';
import 'scim_models.dart';

part 'scim_bulk_panel_view.dart';

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
      title: context.tr('Execute {count} SCIM operations?', {
        'count': preview.operationCount,
      }),
      message: context.tr(
        deletes > 0
            ? 'The server processes operations in order. Per-operation failures do not roll back earlier successes. This request contains {count} permanent deletes.'
            : 'The server processes operations in order. Per-operation failures do not roll back earlier successes.',
        {'count': deletes},
      ),
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
  Widget build(BuildContext context) => _buildBulkPanel(context);
}
