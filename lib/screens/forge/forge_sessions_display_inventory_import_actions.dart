part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayInventoryImportActions
    on _ForgeSessionsScreenState {
  Widget _deviceInventoryV2ImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-device-inventory-v2-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge v2 device inventory JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge v2 device inventory preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-inventory-v2'),
          tooltip: context.tr('Import Forge v2 device inventory JSON'),
          onPressed: _loadingDeviceInventoryV2Preview
              ? null
              : _importDeviceInventoryV2Preview,
          icon: _loadingDeviceInventoryV2Preview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _clientInstanceSessionViewImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-session-view-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge client-instance session view JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge client-instance session view preview'),
        child: IconButton(
          key: const ValueKey('forge-import-client-instance-session-view'),
          tooltip: context.tr('Import Forge client-instance session view JSON'),
          onPressed: _loadingClientInstanceSessionViewPreview
              ? null
              : _importClientInstanceSessionViewPreview,
          icon: _loadingClientInstanceSessionViewPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.devices_other_outlined),
        ),
      ),
    ),
  );

  Widget _clientInstanceResourceViewImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-resource-view-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge client-instance resource view JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge client-instance resource view preview'),
        child: IconButton(
          key: const ValueKey('forge-import-client-instance-resource-view'),
          tooltip: context.tr(
            'Import Forge client-instance resource view JSON',
          ),
          onPressed: _loadingClientInstanceResourceViewPreview
              ? null
              : _importClientInstanceResourceViewPreview,
          icon: _loadingClientInstanceResourceViewPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.account_tree_outlined),
        ),
      ),
    ),
  );

  Widget _deviceResourceSummaryImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-device-resource-summary-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge device resource summary JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge device resource summary preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-resource-summary'),
          tooltip: context.tr('Import Forge device resource summary JSON'),
          onPressed: _loadingDeviceResourceSummaryPreview
              ? null
              : _importDeviceResourceSummaryPreview,
          icon: _loadingDeviceResourceSummaryPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _deviceInventoryPlacementEvaluationV2ImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-placement-evaluation-v2-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge v2 placement evaluation JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge v2 placement evaluation preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-placement-evaluation-v2'),
          tooltip: context.tr('Import Forge v2 placement evaluation JSON'),
          onPressed: _loadingDeviceInventoryPlacementEvaluationV2Preview
              ? null
              : _importDeviceInventoryPlacementEvaluationV2Preview,
          icon: _loadingDeviceInventoryPlacementEvaluationV2Preview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _deviceInventoryPlacementEvaluationImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-placement-evaluation-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge placement evaluation JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge placement evaluation preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-placement-evaluation'),
          tooltip: context.tr('Import Forge placement evaluation JSON'),
          onPressed: _loadingDeviceInventoryPlacementEvaluationPreview
              ? null
              : _importDeviceInventoryPlacementEvaluationPreview,
          icon: _loadingDeviceInventoryPlacementEvaluationPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _deviceInventoryPlacementBatchEvaluationImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-placement-batch-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge placement batch JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge placement batch preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-placement-batch'),
          tooltip: context.tr('Import Forge placement batch JSON'),
          onPressed: _loadingDeviceInventoryPlacementBatchEvaluationPreview
              ? null
              : _importDeviceInventoryPlacementBatchEvaluationPreview,
          icon: _loadingDeviceInventoryPlacementBatchEvaluationPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );
}
