part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayInventoryItems on _ForgeSessionsScreenState {
  List<Widget> _inventoryItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final inventoryResourceConvergence =
        display.inputs.inventoryResourceConvergence;
    final deviceInventoryV2Preview = display.inputs.deviceInventoryV2Preview;
    final deviceResourceSummaryPreview =
        display.inputs.deviceResourceSummaryPreview;
    final deviceInventoryPlacementEvaluationV2Preview =
        display.inputs.deviceInventoryPlacementEvaluationV2Preview;
    final deviceInventoryPlacementEvaluationPreview =
        display.inputs.deviceInventoryPlacementEvaluationPreview;
    final deviceInventoryPlacementBatchEvaluationPreview =
        display.inputs.deviceInventoryPlacementBatchEvaluationPreview;
    return <Widget>[
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryReader != null &&
          _fetchedDeviceInventory != null)
        _authenticatedDeviceInventoryPanel(context, _fetchedDeviceInventory!),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryV2Reader != null &&
          _fetchedDeviceInventoryV2 != null)
        _authenticatedDeviceInventoryV2Panel(
          context,
          _fetchedDeviceInventoryV2!,
        ),
      if (inventoryResourceConvergence != null)
        _authenticatedDeviceInventoryResourceConvergencePanel(
          context,
          inventoryResourceConvergence,
        ),
      if (deviceInventoryV2Preview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceInventoryV2Panel(page: deviceInventoryV2Preview),
        ),
      if (deviceResourceSummaryPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceResourceSummaryPanel(
            fixture: deviceResourceSummaryPreview,
          ),
        ),
      if (deviceInventoryPlacementEvaluationV2Preview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceInventoryPlacementEvaluationV2Panel(
            evaluation: deviceInventoryPlacementEvaluationV2Preview,
          ),
        ),
      if (deviceInventoryPlacementEvaluationPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceInventoryPlacementEvaluationPanel(
            evaluation: deviceInventoryPlacementEvaluationPreview,
          ),
        ),
      if (deviceInventoryPlacementBatchEvaluationPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceInventoryPlacementBatchEvaluationPanel(
            evaluation: deviceInventoryPlacementBatchEvaluationPreview,
          ),
        ),
    ];
  }
}
