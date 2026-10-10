part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenInventoryImports on _ForgeSessionsScreenState {
  Future<void> _importDeviceInventoryV2Preview() async {
    if (_loadingDeviceInventoryV2Preview) return;
    _update(() {
      _loadingDeviceInventoryV2Preview = true;
      _deviceInventoryV2PreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryV2FileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final page = ForgeDeviceInventoryPageV2.fromJsonText(source);
      if (_safeDeviceInventoryV2Preview(page) == null) {
        throw const FormatException(
          'Device inventory v2 is not a display-only observation.',
        );
      }
      if (!mounted) return;
      _update(() => _deviceInventoryV2Preview = page);
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _deviceInventoryV2PreviewError =
            'Invalid or unavailable v2 device inventory preview.';
      });
    } finally {
      if (mounted) _update(() => _loadingDeviceInventoryV2Preview = false);
    }
  }

  Future<void> _importDeviceResourceSummaryPreview() async {
    if (_loadingDeviceResourceSummaryPreview) return;
    _update(() {
      _loadingDeviceResourceSummaryPreview = true;
      _deviceResourceSummaryPreviewError = null;
    });
    try {
      final reader = widget.deviceResourceSummaryFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeDeviceResourceSummaryFixture.fromJsonText(source);
      if (_safeDeviceResourceSummaryPreview(fixture) == null) {
        throw const FormatException(
          'Device resource summary is not a display-only aggregate.',
        );
      }
      if (!mounted) return;
      _update(() => _deviceResourceSummaryPreview = fixture);
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _deviceResourceSummaryPreviewError =
            'Invalid or unavailable device resource summary preview.';
      });
    } finally {
      if (mounted) {
        _update(() => _loadingDeviceResourceSummaryPreview = false);
      }
    }
  }

  Future<void> _importClientInstanceResourceViewPreview() async {
    if (_loadingClientInstanceResourceViewPreview) return;
    _update(() {
      _loadingClientInstanceResourceViewPreview = true;
      _clientInstanceResourceViewPreviewError = null;
    });
    try {
      final reader = widget.clientInstanceResourceViewFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final view = ForgeClientInstanceResourceView.fromJsonText(source);
      if (_safeClientInstanceResourceViewPreview(view) == null) {
        throw const FormatException(
          'Client-instance resource view is not display-only.',
        );
      }
      if (!mounted) return;
      _update(() => _clientInstanceResourceViewPreview = view);
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _clientInstanceResourceViewPreviewError =
            'Invalid or unavailable client-instance resource view preview.';
      });
    } finally {
      if (mounted) {
        _update(() => _loadingClientInstanceResourceViewPreview = false);
      }
    }
  }

  Future<void> _importClientInstanceSessionViewPreview() async {
    if (_loadingClientInstanceSessionViewPreview) return;
    _update(() {
      _loadingClientInstanceSessionViewPreview = true;
      _clientInstanceSessionViewPreviewError = null;
    });
    try {
      final reader = widget.clientInstanceSessionViewFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final view = ForgeClientInstanceSessionView.fromJsonText(source);
      if (_safeClientInstanceSessionViewPreview(view) == null) {
        throw const FormatException(
          'Client-instance session view is not display-only.',
        );
      }
      if (!mounted) return;
      _update(() => _clientInstanceSessionViewPreview = view);
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _clientInstanceSessionViewPreviewError =
            'Invalid or unavailable client-instance session view preview.';
      });
    } finally {
      if (mounted) {
        _update(() => _loadingClientInstanceSessionViewPreview = false);
      }
    }
  }

  Future<void> _importDeviceInventoryPlacementEvaluationV2Preview() async {
    if (_loadingDeviceInventoryPlacementEvaluationV2Preview) return;
    _update(() {
      _loadingDeviceInventoryPlacementEvaluationV2Preview = true;
      _deviceInventoryPlacementEvaluationV2PreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryPlacementEvaluationV2FileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final evaluation = ForgeDeviceInventoryPlacementEvaluationV2.fromJsonText(
        source,
      );
      if (_safeDeviceInventoryPlacementEvaluationV2Preview(evaluation) ==
          null) {
        throw const FormatException(
          'Device placement evaluation is not a display-only comparison.',
        );
      }
      if (!mounted) return;
      _update(() => _deviceInventoryPlacementEvaluationV2Preview = evaluation);
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _deviceInventoryPlacementEvaluationV2PreviewError =
            'Invalid or unavailable v2 device placement preview.';
      });
    } finally {
      if (mounted) {
        _update(
          () => _loadingDeviceInventoryPlacementEvaluationV2Preview = false,
        );
      }
    }
  }

  Future<void> _importDeviceInventoryPlacementEvaluationPreview() async {
    if (_loadingDeviceInventoryPlacementEvaluationPreview) return;
    _update(() {
      _loadingDeviceInventoryPlacementEvaluationPreview = true;
      _deviceInventoryPlacementEvaluationPreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryPlacementEvaluationFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final evaluation =
          ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(source);
      if (_safeDeviceInventoryPlacementEvaluationPreview(evaluation) == null) {
        throw const FormatException(
          'Device placement evaluation is not a display-only comparison.',
        );
      }
      if (!mounted) return;
      _update(() => _deviceInventoryPlacementEvaluationPreview = evaluation);
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _deviceInventoryPlacementEvaluationPreviewError =
            'Invalid or unavailable device placement evaluation preview.';
      });
    } finally {
      if (mounted) {
        _update(
          () => _loadingDeviceInventoryPlacementEvaluationPreview = false,
        );
      }
    }
  }

  Future<void> _importDeviceInventoryPlacementBatchEvaluationPreview() async {
    if (_loadingDeviceInventoryPlacementBatchEvaluationPreview) return;
    _update(() {
      _loadingDeviceInventoryPlacementBatchEvaluationPreview = true;
      _deviceInventoryPlacementBatchEvaluationPreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryPlacementBatchEvaluationFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final evaluation =
          ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJsonText(
            source,
          );
      if (_safeDeviceInventoryPlacementBatchEvaluationPreview(evaluation) ==
          null) {
        throw const FormatException(
          'Placement batch evaluation is not a display-only comparison.',
        );
      }
      if (!mounted) return;
      _update(
        () => _deviceInventoryPlacementBatchEvaluationPreview = evaluation,
      );
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _deviceInventoryPlacementBatchEvaluationPreviewError =
            'Invalid or unavailable placement batch preview.';
      });
    } finally {
      if (mounted) {
        _update(
          () => _loadingDeviceInventoryPlacementBatchEvaluationPreview = false,
        );
      }
    }
  }
}
