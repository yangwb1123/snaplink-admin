part of 'tenant_branding_tab.dart';

extension _TenantBrandingTabView on _TenantBrandingTabState {
  Widget _buildTenantBrandingTab(BuildContext context) {
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
        ..._brandingStatusWidgets(context),
        const SizedBox(height: 12),
        _brandingEditorCard(),
        const SizedBox(height: 12),
        _advancedSettingsCard(),
        const SizedBox(height: 12),
        _brandingActions(),
      ],
    );
  }

  List<Widget> _brandingStatusWidgets(BuildContext context) => [
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
  ];

  Widget _brandingEditorCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _brandName,
            enabled: !_saving && !_outcomeUnknown,
            decoration: InputDecoration(labelText: 'Brand name'.localized),
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
              hintText: 'Comma-separated BCP-47 tags (e.g. en,zh,ja)'.localized,
            ),
          ),
          const SizedBox(height: 12),
          // 预览只依赖这三个控制器：局部监听，不再每次按键整页重建。
          ListenableBuilder(
            listenable: Listenable.merge([_brandName, _primaryColor, _logoUrl]),
            builder: (context, _) => TenantBrandingPreview(
              brandName: _brandName.text.trim(),
              primaryColor: _primaryColor.text.trim(),
              logoUrl: _logoUrl.text.trim(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _advancedSettingsCard() => Card(
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
  );

  Widget _brandingActions() => OverflowBar(
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
  );
}
