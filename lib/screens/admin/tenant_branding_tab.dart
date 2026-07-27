import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/tenant_branding_preview.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

/// Safe editor for Snaplink's source-only tenant branding contract.
///
/// The backend currently replaces the tenant's entire Settings map. This
/// editor therefore round-trips unknown keys and makes reset semantics
/// explicit instead of silently discarding settings it does not understand.
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
  static const _knownKeys = {'brand_name', 'primary_color', 'logo_url'};

  final _brandName = TextEditingController();
  final _primaryColor = TextEditingController();
  final _logoUrl = TextEditingController();
  final _advanced = TextEditingController(text: '{}');
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _unavailable = false;
  bool _outcomeUnknown = false;
  String? _unknownOperation;
  int? _unknownStatus;
  Map<String, String> _lastLoadedExtras = const {};

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
    _advanced.dispose();
    super.dispose();
  }

  Future<bool> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
    });
    try {
      final response = await widget.api.get(
        _path,
        query: {'tenant_id': widget.tenantId},
        forceRefresh: true,
      );
      final raw = response['branding'];
      final branding = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{};
      final extras = Map<String, String>.from(branding)
        ..removeWhere((key, _) => _knownKeys.contains(key));
      if (!mounted) return false;
      setState(() {
        _lastLoadedExtras = Map<String, String>.unmodifiable(extras);
        _brandName.text = branding['brand_name'] ?? '';
        _primaryColor.text = branding['primary_color'] ?? '';
        _logoUrl.text = branding['logo_url'] ?? '';
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
      // Freeze this exact draft before the read. A failed reconciliation
      // must never leave an ambiguous mutation ready to replay.
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

  Map<String, String> _draft() {
    final decoded = jsonDecode(
      _advanced.text.trim().isEmpty ? '{}' : _advanced.text,
    );
    if (decoded is! Map) {
      throw const FormatException('Advanced branding must be a JSON object.');
    }
    final branding = <String, String>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty || _knownKeys.contains(key)) {
        throw const FormatException(
          'Advanced keys must be non-empty and must not duplicate core fields.',
        );
      }
      if (entry.value is! String) {
        throw const FormatException('Every branding value must be a string.');
      }
      branding[key] = entry.value as String;
    }

    final name = _brandName.text.trim();
    final color = _primaryColor.text.trim();
    final logo = _logoUrl.text.trim();
    if (name.length > 100) {
      throw const FormatException('Brand name must be 100 characters or less.');
    }
    if (color.isNotEmpty &&
        !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(color)) {
      throw const FormatException(
        'Primary color must use #RRGGBB or #RRGGBBAA.',
      );
    }
    if (logo.isNotEmpty) {
      final uri = Uri.tryParse(logo);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Logo URL must be an absolute HTTPS URL.');
      }
    }
    if (name.isNotEmpty) branding['brand_name'] = name;
    if (color.isNotEmpty) branding['primary_color'] = color;
    if (logo.isNotEmpty) branding['logo_url'] = logo;
    return branding;
  }

  Future<void> _save() async {
    if (_saving || _outcomeUnknown) return;
    Map<String, String> branding;
    try {
      branding = _draft();
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.put('$_path?tenant_id=$_encodedTenant', {
        'branding': branding,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tenant branding saved.')));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (_couldHaveApplied(error)) {
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
    if (_saving || _outcomeUnknown) return;
    final preservedSettings = Map<String, String>.from(_lastLoadedExtras);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Restore default branding?',
      message:
          'The backend reset endpoint would clear every tenant setting, so '
          'the console will instead preserve the Advanced settings from the '
          'last refresh and remove only the known branding keys. Refresh '
          'first if another administrator may be editing this tenant.',
      confirmLabel: 'Remove branding keys',
      confirmText: widget.tenantId,
      destructive: true,
    );
    if (!confirmed) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.put('$_path?tenant_id=$_encodedTenant', {
        'branding': preservedSettings,
      });
      if (!mounted) return;
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (_couldHaveApplied(error)) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_unavailable) {
      return const Center(
        child: Text('Branding is not enabled on this Snaplink deployment.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hosted login branding',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'These public values theme the hosted sign-in experience. Unknown '
          'settings are preserved when saving.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        if (_outcomeUnknown) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _saving ? null : _retryReconciliation,
            icon: const Icon(Icons.sync),
            label: const Text('Retry reconciliation'),
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
                  decoration: const InputDecoration(labelText: 'Brand name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _primaryColor,
                  enabled: !_saving && !_outcomeUnknown,
                  decoration: const InputDecoration(
                    labelText: 'Primary color',
                    hintText: '#2563EB',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _logoUrl,
                  enabled: !_saving && !_outcomeUnknown,
                  decoration: const InputDecoration(
                    labelText: 'Logo URL',
                    hintText: 'https://cdn.example.com/logo.svg',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TenantBrandingPreview(
                  brandName: _brandName.text.trim(),
                  primaryColor: _primaryColor.text.trim(),
                  logoUrl: _logoUrl.text.trim(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Advanced settings'),
            subtitle: const Text('Additional string keys preserved verbatim'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _advanced,
                enabled: !_saving && !_outcomeUnknown,
                minLines: 5,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(labelText: 'JSON object'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OverflowBar(
          children: [
            OutlinedButton(
              onPressed: _saving || _outcomeUnknown ? null : _reset,
              child: const Text('Restore defaults'),
            ),
            FilledButton(
              onPressed: _saving || _outcomeUnknown ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save branding'),
            ),
          ],
        ),
      ],
    );
  }
}
