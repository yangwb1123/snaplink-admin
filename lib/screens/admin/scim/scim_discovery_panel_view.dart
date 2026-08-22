part of 'scim_discovery_panel.dart';

extension _ScimDiscoveryPanelView on _ScimDiscoveryPanelState {
  Widget _buildDiscoveryPanel(BuildContext context) {
    if (_unavailable) return ScimUnavailable(onRetry: _load);
    if (_loading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonListTile(itemCount: 4),
      );
    }
    if (_error != null && _profile == null) {
      return ErrorStateView(
        message: _error!,
        onRetry: _load,
        retryLabel: 'Retry discovery',
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
        _capabilityGrid(profile),
        if (profile.etag) ...[const SizedBox(height: 12), _etagNotice(context)],
        const SizedBox(height: 20),
        SectionHeader('Implemented schemas'),
        const SizedBox(height: 8),
        _groupProvisioningCard(),
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

  Widget _capabilityGrid(ScimServiceProfile profile) => LayoutBuilder(
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
  );

  Widget _etagNotice(BuildContext context) => Card(
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
  );

  Widget _groupProvisioningCard() {
    final enabled = _schemas.any((schema) => schema['name'] == 'Group');
    return Card(
      child: ListTile(
        leading: Icon(
          enabled ? Icons.check_circle_outline : Icons.extension_off_outlined,
          color: enabled ? AppColors.success : AppColors.warning,
        ),
        title: const LocalizedText('Group provisioning'),
        subtitle: LocalizedText(
          enabled
              ? 'Group schema and role-backed provisioning are enabled.'
              : 'Not advertised. Enable scim.groups and a permissions '
                    'provider before sending Group operations.',
        ),
      ),
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
