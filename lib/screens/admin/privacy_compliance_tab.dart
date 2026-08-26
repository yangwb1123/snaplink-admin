import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'admin_module_groups.dart';
import 'tenant_export_download.dart';

part 'privacy_compliance_tab_view.dart';

/// Operator workflow for GDPR subject requests and retention execution.
///
/// Sensitive exports are sent directly to a browser attachment and are never
/// rendered, copied, or retained in widget state.
class PrivacyComplianceTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const PrivacyComplianceTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<PrivacyComplianceTab> createState() => _PrivacyComplianceTabState();
}

class _PrivacyComplianceTabState extends State<PrivacyComplianceTab> {
  static const _subjectPrefix = '/api/v1/compliance/users';
  static const _retentionPath = '/api/v1/admin/compliance/retention-sweep';

  /// 组色（tenants → amber）：页头与区块图标按组色上色（X7）。
  Color get _accent => adminModuleIconColor('privacy-compliance');

  final _subject = TextEditingController();
  Map<String, dynamic>? _erasurePreview;
  Map<String, dynamic>? _erasureResult;
  Map<String, dynamic>? _retentionReport;
  String? _previewSubject;
  String? _error;
  bool _busy = false;
  Future<void> Function()? _lastOperation;

  bool get _exportable => _has('GET', '$_subjectPrefix/{id}/export');
  bool get _erasable => _has('POST', '$_subjectPrefix/{id}/erase');
  bool get _sweepable => _has('POST', _retentionPath);

  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == method && endpoint.path == path,
      );

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  String? _subjectId() {
    final value = _subject.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter the data subject’s user ID.');
      return null;
    }
    return value;
  }

  Future<void> _export() async {
    final subject = _subjectId();
    if (subject == null) return;
    await _run(() async {
      final attachment = await widget.api.getDownload(
        '$_subjectPrefix/${Uri.encodeComponent(subject)}/export',
      );
      downloadAdminAttachment(
        attachment,
        fallbackFilename: 'snaplink-subject-$subject-export.json',
      );
      if (mounted) {
        showAppSnackBar(
          context,
          content: LocalizedText(
            'Encrypted transport complete; export downloaded.',
          ),
        );
      }
    });
  }

  Future<void> _previewErase() async {
    final subject = _subjectId();
    if (subject == null) return;
    await _run(() async {
      final report = await widget.api.post(
        '$_subjectPrefix/${Uri.encodeComponent(subject)}/erase',
        {'dry_run': true},
      );
      if (!mounted) return;
      setState(() {
        _previewSubject = subject;
        _erasurePreview = report;
        _erasureResult = null;
      });
    });
  }

  Future<void> _commitErase() async {
    final subject = _subjectId();
    if (subject == null) return;
    if (_previewSubject != subject || _erasurePreview == null) {
      setState(
        () => _error =
            'Run a fresh dry-run preview for this subject before erasure.',
      );
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Permanently erase subject data?',
      message:
          'This revokes credentials and sessions before deleting the account. '
          'Snaplink does not expose a legal-hold check here; verify the request '
          'against your external hold register first.',
      confirmLabel: 'Erase subject',
      confirmText: subject,
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() async {
      final report = await widget.api.post(
        '$_subjectPrefix/${Uri.encodeComponent(subject)}/erase',
        {'dry_run': false},
      );
      if (!mounted) return;
      setState(() {
        _erasureResult = report;
        _erasurePreview = null;
        _previewSubject = null;
      });
    });
  }

  Future<void> _retention({required bool dryRun}) async {
    if (!dryRun) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Run retention sweep?',
        message:
            'Expired sessions may be destroyed and dormant accounts may be '
            'erased when the server’s AutoEraseDormant policy is enabled.',
        confirmLabel: 'Run sweep',
        confirmText: 'RUN RETENTION',
        destructive: true,
      );
      if (!confirmed) return;
    }
    await _run(() async {
      final report = await widget.api.post(_retentionPath, {'dry_run': dryRun});
      if (mounted) setState(() => _retentionReport = report);
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
      _lastOperation = operation;
    });
    try {
      await operation();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildPrivacyComplianceTab(context);
}
