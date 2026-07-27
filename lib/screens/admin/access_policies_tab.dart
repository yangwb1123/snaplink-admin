import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/async_view.dart';

/// Access policy list (view-only).
/// URL: /admin/access-policies
class AccessPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const AccessPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<AccessPoliciesTab> createState() => _AccessPoliciesTabState();
}

class _AccessPoliciesTabState extends State<AccessPoliciesTab> {
  static const _path = '/api/v1/admin/access-policies';
  List<Map<String, dynamic>> _policies = const [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      final items = data['policies'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _policies = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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
          _error = 'Could not load access policies.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminBreadcrumb(),
            Row(
              children: [
                Text(
                  AppStrings.of(context).accessPolicies,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            AsyncView<List<Map<String, dynamic>>>(
              loading: _loading,
              error: _error,
              data: _policies,
              onRetry: _load,
              emptyTitle: 'No access policies',
              emptySubtitle: 'No access policies configured for this server.',
              dataBuilder: (policies) => Column(
                children: policies
                    .map(
                      (p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.lock_outline,
                            color: p['enabled'] == true
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          title: Text(
                            p['name']?.toString() ?? p['id']?.toString() ?? '',
                          ),
                          subtitle: Text(
                            'effect: ${p['effect'] ?? 'allow'}\n${p['description'] ?? ''}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
