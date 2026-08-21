import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/tenant_branding_draft.dart';
import 'package:sso_admin/screens/admin/tenant_branding_preview.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

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
  static const _path = '/api/v1/admin/branding';

  final _brandName = TextEditingController();
  final _primaryColor = TextEditingController();
  final _logoUrl = TextEditingController();
  final _languages = TextEditingController();
  final _advanced = TextEditingController(text: '{}');
  String? _error;
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
        _error = _unavailable ? null : error.toString();
      });
      return false;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
        _error =
            '$operation result is unknown $reason. A safe GET refreshed '
            'the authoritative current branding. The current state is now '
            'reconciled and branding mutations are unlocked.';
      } else {
        _outcomeUnknown = true;
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
      setState(() => _error = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
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
        setState(() => _error = error.toString());
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
        setState(() => _error = error.toString());
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
      _error = refreshed
          ? 'Branding changed on the server. The latest version is loaded; '
                'review it before saving again.'
          : 'Branding changed on the server and the latest version could not '
                'be loaded. Refresh before saving.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonListTile(itemCount: 4);
    if (_unavailable) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Branding is not enabled on this Snaplink deployment.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LocalizedText(
          'Hosted login branding',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'These public values theme the hosted sign-in experience. Unknown '
          'settings are preserved when saving.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
            style: TextStyle(
              color: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
          ),
        ],
        if (_outcomeUnknown) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _saving ? null : _retryReconciliation,
            icon: const Icon(Icons.sync),
            label: const LocalizedText('Retry reconciliation'),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _brandName,
                  enabled: !_saving && !_outcomeUnknown,
                  decoration: InputDecoration(
                    labelText: 'Brand name'.localized,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _primaryColor,
                  enabled: !_saving && !_outcomeUnknown,
                  decoration: InputDecoration(
                    labelText: 'Primary color'.localized,
                    hintText: '#2563EB'.localized,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _logoUrl,
                  enabled: !_saving && !_outcomeUnknown,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Logo URL'.localized,
                    hintText: 'https://cdn.example.com/logo.svg'.localized,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _languages,
                  enabled: !_saving && !_outcomeUnknown,
                  decoration: InputDecoration(
                    labelText: 'Languages'.localized,
                    hintText:
                        'Comma-separated BCP-47 tags (e.g. en,zh,ja)'.localized,
                  ),
                ),
                const SizedBox(height: 12),
                // 预览只依赖这三个控制器：局部监听，不再每次按键整页重建。
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _brandName,
                    _primaryColor,
                    _logoUrl,
                  ]),
                  builder: (context, _) => TenantBrandingPreview(
                    brandName: _brandName.text.trim(),
                    primaryColor: _primaryColor.text.trim(),
                    logoUrl: _logoUrl.text.trim(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const LocalizedText('Advanced settings'),
            subtitle: const LocalizedText(
              'Additional string keys preserved verbatim',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _advanced,
                enabled: !_saving && !_outcomeUnknown,
                minLines: 5,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(labelText: 'JSON object'.localized),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OverflowBar(
          children: [
            OutlinedButton(
              onPressed: _saving || _outcomeUnknown || _version == null
                  ? null
                  : _reset,
              child: const LocalizedText('Restore defaults'),
            ),
            FilledButton(
              onPressed: _saving || _outcomeUnknown || _version == null
                  ? null
                  : _save,
              child: LocalizedText(_saving ? 'Saving…' : 'Save branding'),
            ),
          ],
        ),
      ],
    );
  }
}
