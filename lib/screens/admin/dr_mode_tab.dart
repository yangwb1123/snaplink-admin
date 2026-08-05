import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

/// Disaster Recovery mode management tab.
/// URL: /admin/dr-mode
class DRModeTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const DRModeTab({super.key, required this.api, required this.capabilities});
  @override
  State<DRModeTab> createState() => _DRModeTabState();
}

class _DRModeTabState extends State<DRModeTab> {
  static const _path = '/api/v1/admin/dr/mode';
  static const _modes = {
    'normal': 'All request classes are available.',
    'read_only':
        'Administrative writes are blocked; the token plane remains available.',
    'auth_only':
        'Only authentication, token, and discovery requests remain available.',
    'local_only': 'Endpoints that depend on remote systems are shed.',
    'maintenance': 'Every non-probe request is rejected.',
  };

  final _reasonCtrl = TextEditingController();
  Map<String, dynamic>? _status;
  String _selectedMode = 'normal';
  String? _error;
  bool _loading = false;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      if (!mounted) return;
      final mode = data['mode']?.toString() ?? 'normal';
      setState(() {
        _status = data;
        _selectedMode = _modes.containsKey(mode) ? mode : 'normal';
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load DR mode status.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyMode() async {
    final current = _status?['mode']?.toString() ?? 'normal';
    if (_selectedMode == current) return;
    final reason = _reasonCtrl.text.trim();
    if (_selectedMode != 'normal' && reason.isEmpty) {
      setState(
        () => _error =
            'Add an incident or change reference before degrading service.',
      );
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: _selectedMode == 'normal'
          ? 'Return to normal service?'
          : 'Apply degraded-service mode?',
      message:
          'Change the server from $current to $_selectedMode. ${_modes[_selectedMode]}',
      confirmLabel: 'Apply mode',
      destructive: _selectedMode != 'normal',
      confirmText: _selectedMode != 'normal' ? _selectedMode : null,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(_path, {
        'mode': _selectedMode,
        if (reason.isNotEmpty) 'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText('Service mode changed to $_selectedMode.'),
        ),
      );
      _reasonCtrl.clear();
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      AdminBreadcrumb(),
      Text(
        AppStrings.of(context).drMode,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      if (_loading) const SkeletonListTile(itemCount: 3),
      if (_error != null)
        LocalizedText(_error!, style: const TextStyle(color: Colors.redAccent)),
      if (_status != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sync_problem,
                      size: 48,
                      color: _status!['mode'] == 'normal'
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'Current mode: ${_status!['mode'] ?? 'normal'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          LocalizedText(
                            _modes[_status!['mode']] ??
                                'Unknown service posture.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMode,
                  decoration: InputDecoration(
                    labelText: 'Target service mode'.localized,
                  ),
                  items: _modes.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.key),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _mutating
                      ? null
                      : (value) => setState(() => _selectedMode = value!),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LocalizedText(_modes[_selectedMode] ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  enabled: !_mutating,
                  decoration: InputDecoration(
                    labelText: 'Reason / incident reference'.localized,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _mutating ? null : _applyMode,
                  icon: const Icon(Icons.policy_outlined),
                  label: const LocalizedText('Apply service mode'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
