import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import '../admin_module_groups.dart';
import 'scim_browser_widgets.dart';
import 'scim_models.dart';

class ScimDiscoveryPanel extends StatefulWidget {
  final SnaplinkAdminApi api;

  const ScimDiscoveryPanel({super.key, required this.api});

  @override
  State<ScimDiscoveryPanel> createState() => _ScimDiscoveryPanelState();
}

class _ScimDiscoveryPanelState extends State<ScimDiscoveryPanel> {
  ScimServiceProfile? _profile;
  List<Map<String, dynamic>> _schemas = const [];
  String? _error;
  bool _loading = false;
  bool _unavailable = false;

  Color get _accent => adminModuleIconColor('scim-directory');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
    });
    try {
      final results = await Future.wait([
        widget.api.get('$scimBasePath/ServiceProviderConfig'),
        widget.api.get('$scimBasePath/Schemas'),
      ]);
      final schemaValues = results[1]['Resources'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _profile = ScimServiceProfile.fromJson(results[0]);
        _schemas = schemaValues
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.status == 404 || error.status == 501) {
          _unavailable = true;
        } else {
          _error = context.tr(
            'SCIM request failed ({status}): {error}',
            {'status': '${error.status}', 'error': error.toString()},
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Could not load SCIM discovery.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return ScimUnavailable(onRetry: _load);
    if (_loading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonListTile(itemCount: 4),
      );
    }
    if (_error != null && _profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const LocalizedText('Retry discovery'),
            ),
          ],
        ),
      );
    }
    final profile = _profile;
    if (profile == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          'Provider capabilities',
          action: IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.refresh, color: _accent),
            tooltip: 'Refresh discovery'.localized,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 900
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth > 560
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'Patch',
                    supported: profile.patch,
                    detail: 'Ordered, atomic add / replace / remove',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'Filter',
                    supported: profile.filter,
                    detail: 'Up to ${profile.filterMaxResults} results/page',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'Bulk',
                    supported: profile.bulk,
                    detail:
                        '${profile.bulkMaxOperations} ops · '
                        '${_formatBytes(profile.bulkMaxPayloadSize)}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'Sort',
                    supported: profile.sort,
                    detail: 'Ascending or descending before pagination',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'ETag',
                    supported: profile.etag,
                    detail: 'meta.version + conditional requests',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'Change password',
                    supported: profile.changePassword,
                    detail: 'SCIM password mutation',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _FeatureCard(
                    title: 'Authentication',
                    supported: profile.authenticationSchemes.isNotEmpty,
                    detail: profile.authenticationSchemes.isEmpty
                        ? 'None advertised'
                        : profile.authenticationSchemes.join(', '),
                  ),
                ),
              ],
            );
          },
        ),
        if (profile.etag) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: LocalizedText('Conditional-write protection'),
              subtitle: LocalizedText(
                'When a resource exposes meta.version, this console sends it '
                'as If-Match on PUT, PATCH, and DELETE. Older resources that '
                'omit a version cannot receive that concurrency protection.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader('Implemented schemas'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(
              _schemas.any((schema) => schema['name'] == 'Group')
                  ? Icons.check_circle_outline
                  : Icons.extension_off_outlined,
              color: _schemas.any((schema) => schema['name'] == 'Group')
                  ? AppColors.success
                  : AppColors.warning,
            ),
            title: const LocalizedText('Group provisioning'),
            subtitle: LocalizedText(
              _schemas.any((schema) => schema['name'] == 'Group')
                  ? 'Group schema and role-backed provisioning are enabled.'
                  : 'Not advertised. Enable scim.groups and a permissions '
                        'provider before sending Group operations.',
            ),
          ),
        ),
        if (_schemas.isEmpty)
          const EmptyState(
            variant: EmptyStateVariant.empty,
            compact: true,
            title: 'No resource schemas advertised.',
          )
        else
          for (final schema in _schemas) _schemaCard(context, schema),
      ],
    );
  }

  Widget _schemaCard(BuildContext context, Map<String, dynamic> schema) {
    final attributes = (schema['attributes'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    return Card(
      child: ExpansionTile(
        leading: Icon(
          schema['name'] == 'Group'
              ? Icons.groups_outlined
              : Icons.person_outline,
          color: _accent,
        ),
        title: Text(schema['name']?.toString() ?? context.tr('Schema')),
        subtitle: Text(
          '${schema['id'] ?? ''}\n${attributes.length} top-level attributes',
        ),
        children: [
          for (final attribute in attributes)
            ListTile(
              dense: true,
              title: Text(attribute['name']?.toString() ?? ''),
              subtitle: Text(_attributeDetail(attribute)),
              trailing: attribute['required'] == true
                  ? const Chip(label: LocalizedText('Required'))
                  : null,
            ),
        ],
      ),
    );
  }

  String _attributeDetail(Map attribute) {
    final subs = (attribute['subAttributes'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value['name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .join(', ');
    final details = [
      attribute['type']?.toString() ?? 'unknown',
      if (attribute['multiValued'] == true) 'multi-valued',
      attribute['mutability']?.toString() ?? '',
      if (subs.isNotEmpty) 'sub-attributes: $subs',
    ];
    return details.where((value) => value.isNotEmpty).join(' · ');
  }

  String _formatBytes(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
      : '${(bytes / 1024).toStringAsFixed(0)} KiB';
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final bool supported;
  final String detail;

  const _FeatureCard({
    required this.title,
    required this.supported,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: Icon(
        supported ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: supported
            ? AppColors.success
            : Theme.of(context).colorScheme.outline,
      ),
      title: LocalizedText(title),
      subtitle: LocalizedText(supported ? detail : 'Not supported'),
    ),
  );
}
