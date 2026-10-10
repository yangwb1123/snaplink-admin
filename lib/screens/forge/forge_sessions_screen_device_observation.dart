part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenDeviceObservation on _ForgeSessionsScreenState {
  Future<void> _loadDeviceObservationIfRequested(
    String conversationID,
    String runID,
  ) async {
    if (!mounted) return;
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final request = widget.deviceObservationRequest;
    final key = '$conversationID/$runID';
    if (request == null ||
        request.conversationID != conversationID ||
        request.runID != runID) {
      if (_fetchedDeviceObservation != null ||
          _deviceObservationError != null ||
          _deviceObservationKey != null ||
          _loadingDeviceObservation) {
        _update(_clearDeviceObservation);
      }
      return;
    }
    if (_deviceObservationKey == key &&
        (_fetchedDeviceObservation != null ||
            _deviceObservationError != null ||
            _loadingDeviceObservation)) {
      return;
    }
    final generation = ++_deviceObservationGeneration;
    _update(() {
      _deviceObservationKey = key;
      _loadingDeviceObservation = true;
      _deviceObservationError = null;
      _fetchedDeviceObservation = null;
    });
    try {
      final wire = await _api.previewSessionDeviceObservation(request: request);
      final observation = ForgeSessionDeviceObservation.fromWire(wire);
      if (!mounted ||
          generation != _deviceObservationGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        return;
      }
      _update(() {
        _fetchedDeviceObservation = observation;
        _deviceObservationError = null;
        _loadingDeviceObservation = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceObservationGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        return;
      }
      _update(() {
        _fetchedDeviceObservation = null;
        _deviceObservationError = _friendlyError(
          error,
          'Could not load device observation.',
        );
        _loadingDeviceObservation = false;
      });
    }
  }

  void _clearDeviceObservation() {
    _deviceObservationGeneration++;
    _fetchedDeviceObservation = null;
    _importedDeviceObservation = null;
    _deviceObservationError = null;
    _deviceObservationKey = null;
    _loadingDeviceObservation = false;
  }

  bool _sameDeviceObservationRequest(
    ForgeSessionPlacementRequest? left,
    ForgeSessionPlacementRequest? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return jsonEncode(left.toJson()) == jsonEncode(right.toJson());
  }

  Future<void> _importOfflineDeviceObservation() async {
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (conversationID == null || runID == null) return;

    final controller = TextEditingController();
    try {
      final observation = await showDialog<ForgeSessionDeviceObservation>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;
          var importing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (importing) return;
                setDialogState(() {
                  importing = true;
                  errorMessage = null;
                });
                try {
                  final raw = controller.text.trim();
                  if (raw.isEmpty || raw.length > 2 * 1024 * 1024) {
                    throw const FormatException('size');
                  }
                  final wire = ForgeSessionDeviceObservationWire.fromJson(
                    jsonDecode(raw),
                  );
                  final parsed = ForgeSessionDeviceObservation.fromWire(wire);
                  if (!parsed.isFor(conversationID, runID)) {
                    throw const ForgeSessionDeviceObservationError(
                      'run_binding',
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(parsed);
                  }
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    importing = false;
                    errorMessage =
                        error is ForgeSessionDeviceObservationError &&
                            error.code == 'run_binding'
                        ? 'The observation must match the selected Run.'
                        : 'Invalid offline device observation.';
                  });
                }
              }

              return AlertDialog(
                title: Text(context.tr('Import offline device observation')),
                content: SizedBox(
                  width: min(MediaQuery.sizeOf(context).width - 48, 720),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            'Paste the canonical offline observation JSON for this selected Run. It is not saved or used for execution.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'forge-offline-device-observation-json',
                          ),
                          controller: controller,
                          autofocus: true,
                          minLines: 8,
                          maxLines: 16,
                          enabled: !importing,
                          decoration: InputDecoration(
                            labelText: context.tr('Canonical observation JSON'),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: importing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey('forge-import-offline-observation'),
                    onPressed: importing ? null : submit,
                    child: Text(context.tr('Import')),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || observation == null) return;
      if (_selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return;
      }
      _update(() {
        _importedDeviceObservation = observation;
        _deviceObservationError = null;
      });
    } finally {
      controller.dispose();
    }
  }
}
