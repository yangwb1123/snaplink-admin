import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/tenant_branding_draft.dart';
import 'package:sso_admin/screens/admin/tenant_branding_preview.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

part 'tenant_branding_tab_view.dart';

/// Safe editor for Snaplink's tenant branding contract; mutations send the
/// last server version as If-Match so concurrent edits fail with 412.
class TenantBrandingTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final String tenantId;

  const TenantBrandingTab({
    super.key,
    required this.api,
    required this.tenantId,
  });

  @override
  State<TenantBrandingTab> createState() => _TenantBrandingTabState();
}

class _TenantBrandingTabState extends State<TenantBrandingTab> {
  static const _path = AdminPaths.branding;

  final _brandName = TextEditingController();
  final _primaryColor = TextEditingController();
  final _logoUrl = TextEditingController();
  final _languages = TextEditingController();
  final _advanced = TextEditingController(text: '{}');
  String? _error;
  String? _loadError;
  String? _notice;
  bool _loading = true;
  bool _saving = false;
  bool _unavailable = false;
  bool _outcomeUnknown = false;
  String? _unknownOperation;
  int? _unknownStatus;
  String? _version;
  String get _encodedTenant => Uri.encodeQueryComponent(widget.tenantId);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _brandName.dispose();
    _primaryColor.dispose();
    _logoUrl.dispose();
    _languages.dispose();
    _advanced.dispose();
    super.dispose();
  }

  Future<bool> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadError = null;
      _notice = null;
      _unavailable = false;
      _version = null;
    });
    try {
      final response = await widget.api.get(
        _path,
        query: {'tenant_id': widget.tenantId},
        forceRefresh: true,
      );
      final raw = response['branding'];
      final version = response['version']?.toString();
      if (version == null || version.isEmpty) {
        throw const FormatException(
          'Branding response did not include a concurrency version.',
        );
      }
      final branding = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{};
      final extras = Map<String, String>.from(branding)
        ..removeWhere((key, _) => tenantBrandingCoreKeys.contains(key));
      if (!mounted) return false;
      setState(() {
        _version = version;
        _brandName.text = branding['brand_name'] ?? '';
        _primaryColor.text = branding['primary_color'] ?? '';
        _logoUrl.text = branding['logo_url'] ?? '';
        _languages.text = branding['languages'] ?? '';
        _advanced.text = const JsonEncoder.withIndent('  ').convert(extras);
      });
      return true;
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return false;
      setState(() {
        _unavailable = error.status == 404 || error.status == 501;
        _loadError = _unavailable ? null : error.toString();
        _error = _unavailable ? null : _loadError;
      });
      return false;
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _error = _loadError;
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _couldHaveApplied(SnaplinkAdminApiError error) =>
      error.status == 408 || error.status == 429 || error.status >= 500;

  Future<void> _reconcileUnknownOutcome(String operation, {int? status}) async {
    if (!mounted) return;
    setState(() {
      // Freeze this draft before the read; a failed reconciliation must
      // never leave an ambiguous mutation ready to replay.
      _outcomeUnknown = true;
      _unknownOperation = operation;
      _unknownStatus = status;
    });
    await _retryReconciliation();
  }

  Future<void> _retryReconciliation() async {
    final operation = _unknownOperation;
    if (operation == null) return;
    final status = _unknownStatus;
    final refreshed = await _load();
    if (!mounted) return;
    final refreshFailure = _error;
    final reason = status == null
        ? 'because the response was not received'
        : '(HTTP $status)';
    setState(() {
      // An unavailable response is also a failed reconciliation. Keep the
      // safety warning visible rather than replacing it with the optional
      // feature placeholder.
      _unavailable = false;
      if (refreshed) {
        _outcomeUnknown = false;
        _unknownOperation = null;
        _unknownStatus = null;
        _error = null;
        _notice =
            '$operation result is unknown $reason. A safe GET refreshed '
            'the authoritative current branding. The current state is now '
            'reconciled and branding mutations are unlocked.';
      } else {
        _outcomeUnknown = true;
        _notice = null;
        _error =
            '$operation result is unknown $reason. The server may have '
            'applied the change, and the safe GET refresh failed'
            '${refreshFailure == null ? '' : ': $refreshFailure'}. '
            'Do not retry the mutation until the authoritative tenant '
            'settings can be checked.';
      }
    });
  }

  Future<void> _save() async {
    final version = _version;
    if (_saving || _outcomeUnknown || version == null) return;
    Map<String, String> branding;
    try {
      branding = tenantBrandingDraft(
        advancedJson: _advanced.text,
        brandName: _brandName.text,
        primaryColor: _primaryColor.text,
        logoUrl: _logoUrl.text,
        languages: _languages.text,
      );
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
        _loadError = null;
        _notice = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _loadError = null;
      _notice = null;
    });
    try {
      await widget.api.mutateIfMatch(
        method: 'PUT',
        path: '$_path?tenant_id=$_encodedTenant',
        etag: '"branding-$version"',
        body: {'branding': branding},
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: LocalizedText('Tenant branding saved.'),
      );
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (error.status == 412) {
        await _handleConcurrentEdit();
      } else if (_couldHaveApplied(error)) {
        await _reconcileUnknownOutcome('Branding save', status: error.status);
      } else if (mounted) {
        setState(() {
          _error = error.toString();
          _loadError = null;
          _notice = null;
        });
      }
    } catch (_) {
      await _reconcileUnknownOutcome('Branding save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final version = _version;
    if (_saving || _outcomeUnknown || version == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Restore default branding?',
      message:
          'This clears only the dedicated branding resource. Tenant locale, '
          'feature flags, and other settings are not part of this resource. '
          'A concurrent branding edit will be rejected.',
      confirmLabel: 'Clear branding',
      confirmText: widget.tenantId,
      destructive: true,
    );
    if (!confirmed) return;
    setState(() {
      _saving = true;
      _error = null;
      _loadError = null;
      _notice = null;
    });
    try {
      await widget.api.mutateIfMatch(
        method: 'DELETE',
        path: '$_path?tenant_id=$_encodedTenant',
        etag: '"branding-$version"',
      );
      if (!mounted) return;
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (error.status == 412) {
        await _handleConcurrentEdit();
      } else if (_couldHaveApplied(error)) {
        await _reconcileUnknownOutcome('Branding reset', status: error.status);
      } else if (mounted) {
        setState(() {
          _error = error.toString();
          _loadError = null;
          _notice = null;
        });
      }
    } catch (_) {
      await _reconcileUnknownOutcome('Branding reset');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleConcurrentEdit() async {
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      if (refreshed) {
        _error = null;
        _notice =
            'Branding changed on the server. The latest version is loaded; '
            'review it before saving again.';
      } else {
        // A failed conflict refresh must remain visible as a retryable
        // conflict, even if the server answered with optional-resource 404.
        _unavailable = false;
        _notice = null;
        _error =
            'Branding changed on the server and the latest version could not '
            'be loaded. Refresh before saving.';
        _loadError = _error;
      }
    });
  }

  @override
  Widget build(BuildContext context) => _buildTenantBrandingTab(context);
}
