import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'dcr_credentials.dart';
import 'dcr_delete_dialog.dart';
import 'dcr_form_controller.dart';
import 'dcr_metadata_form.dart';
import 'dcr_models.dart';
import 'dcr_round_trip_notice.dart';
import 'dcr_update_projection.dart';
import 'dcr_validation.dart';
import 'developer_api.dart';

class ManagePanel extends StatefulWidget {
  final DeveloperApi api;
  final DcrDiscovery? discovery;

  const ManagePanel({super.key, required this.api, this.discovery});

  @override
  State<ManagePanel> createState() => ManagePanelState();
}

class ManagePanelState extends State<ManagePanel> {
  final _clientIdController = TextEditingController();
  final _tokenController = TextEditingController();
  final _form = DcrFormController();

  Map<String, dynamic>? _currentApp;
  DcrRoundTripSafety? _roundTripSafety;
  bool _loading = false;
  bool _saving = false;
  bool _deleting = false;
  String? _loadError;
  bool _credentialError = false;

  @override
  void dispose() {
    _clientIdController.dispose();
    _tokenController.dispose();
    _form.dispose();
    _currentApp = null;
    super.dispose();
  }

  void loadWithRegistration(
    String clientId,
    String token,
    Map<String, dynamic> registrationSnapshot,
  ) {
    _clientIdController.text = clientId;
    _tokenController.text = token;
    _applyLoaded({
      ...registrationSnapshot,
      'client_id': clientId,
    }, trustedRegistrationSnapshot: true);
  }

  /// Backward-compatible entry point for callers that only have credentials.
  void loadWith(String clientId, String token) {
    _clientIdController.text = clientId;
    _tokenController.text = token;
    _load();
  }

  void _applyLoaded(
    Map<String, dynamic> app, {
    bool trustedRegistrationSnapshot = false,
    DcrRoundTripSafety? safetyOverride,
  }) {
    final safety =
        safetyOverride ??
        DcrRoundTripSafety.fromWire(
          app,
          trustedRegistrationSnapshot: trustedRegistrationSnapshot,
        );
    final metadata = DcrClientMetadata.fromWire(app);
    setState(() {
      _currentApp = Map<String, dynamic>.from(app)
        ..remove('client_secret')
        ..remove('registration_access_token');
      _roundTripSafety = safety;
      _form.populate(metadata);
      _loadError = null;
      _credentialError = false;
    });
  }

  Future<void> _load() async {
    final clientId = _clientIdController.text.trim();
    final token = _tokenController.text.trim();
    if (clientId.isEmpty || token.isEmpty) {
      setState(() {
        _loadError =
            'Client ID and registration access token are both required.';
        _credentialError = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
      _credentialError = false;
      _currentApp = null;
      _roundTripSafety = null;
    });
    try {
      final app = await widget.api.loadApp(clientId: clientId, token: token);
      if (!mounted) return;
      _applyLoaded(app);
    } on DeveloperApiError catch (error) {
      if (!mounted) return;
      if (error.isInvalidManagementCredential) {
        setState(() {
          _loadError = 'Invalid client ID or registration access token.';
          _credentialError = true;
        });
      } else {
        setState(() {
          _loadError = error.isRetryable
              ? 'Snaplink is temporarily unavailable (HTTP ${error.status}). '
                    'Your credentials were not classified as invalid; retry.'
              : 'Snaplink rejected the management request: $error';
          _credentialError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'Unable to reach Snaplink. Your credentials were not classified '
              'as invalid; check the connection and retry.';
          _credentialError = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_currentApp == null || _roundTripSafety?.canSafelyUpdate != true) {
      return;
    }
    late final DcrClientMetadata metadata;
    try {
      metadata = _form.metadata();
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }
    final validation = validateDcrMetadata(
      metadata,
      discovery: widget.discovery,
      registration: false,
    );
    if (!validation.isValid) {
      _showMessage(validation.message);
      return;
    }

    final clientId = _clientIdController.text.trim();
    final token = _tokenController.text.trim();
    final body = metadata.toManagementWire();
    setState(() => _saving = true);
    try {
      final response = await widget.api.saveApp(
        clientId: clientId,
        token: token,
        body: body,
      );
      if (!mounted) return;

      final rotatedToken =
          response['registration_access_token']?.toString() ?? '';
      final projection = DcrUpdateProjection.fromPutResponse(
        response: response,
        submitted: metadata,
      );
      _applyLoaded(projection.wire, safetyOverride: projection.safety);

      if (rotatedToken.isNotEmpty) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RotatedRegistrationTokenDialog(
            token: rotatedToken,
            onConfirmed: () => _tokenController.text = rotatedToken,
          ),
        );
      }
      if (mounted) _showMessage('Saved.');
    } on DeveloperApiError catch (error) {
      if (!mounted) return;
      if (error.isInvalidManagementCredential) {
        setState(() {
          _currentApp = null;
          _roundTripSafety = null;
          _loadError = 'Invalid client ID or registration access token.';
          _credentialError = true;
        });
      } else {
        _showMessage(
          error.isRetryable
              ? 'Save was not confirmed (HTTP ${error.status}). Retry without '
                    'reloading credentials.'
              : '$error',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Save was not confirmed because Snaplink could not be reached. '
          'Retry; the credentials were not classified as invalid.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_currentApp == null) return;
    final clientId = _clientIdController.text.trim();
    final confirmed = await confirmDcrDeletion(context, clientId: clientId);
    if (!mounted) return;
    if (confirmed) await _delete();
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await widget.api.deleteApp(
        clientId: _clientIdController.text.trim(),
        token: _tokenController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _currentApp = null;
        _roundTripSafety = null;
        _clientIdController.clear();
        _tokenController.clear();
      });
      _showMessage('App deleted.');
    } on DeveloperApiError catch (error) {
      if (!mounted) return;
      if (error.isInvalidManagementCredential) {
        setState(() {
          _currentApp = null;
          _roundTripSafety = null;
          _loadError = 'Invalid client ID or registration access token.';
          _credentialError = true;
        });
      } else {
        _showMessage(
          error.isRetryable
              ? 'Delete was not confirmed (HTTP ${error.status}). Retry; '
                    'the credentials remain loaded.'
              : 'Snaplink rejected the delete request: $error',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Delete was not confirmed because Snaplink could not be reached. '
          'Retry; the credentials were not classified as invalid.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  void _loadIfIdle() {
    if (!_loading && _currentApp == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _clientIdController,
                  enabled: _currentApp == null && !_loading,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.strings.clientId,
                  ),
                ),
                const SizedBox(height: 16),
                SensitiveTokenField(
                  controller: _tokenController,
                  label: 'Registration Access Token',
                  enabled: !_loading && !_saving && !_deleting,
                  readOnly: _currentApp != null,
                  onSubmitted: (_) => _loadIfIdle(),
                ),
                if (_loadError != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.tr(_loadError!),
                      style: TextStyle(
                        color: _credentialError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _load,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.tr(
                            _loadError == null ? 'Load App' : 'Retry Load',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_currentApp != null) ...[
          const SizedBox(height: 16),
          DcrRoundTripNotice(safety: _roundTripSafety!),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DcrMetadataForm(
                    controller: _form,
                    discovery: widget.discovery,
                    managementMode: true,
                    roundTripSafety: _roundTripSafety,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed:
                        _saving ||
                            _deleting ||
                            _roundTripSafety?.canSafelyUpdate != true
                        ? null
                        : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('Save Changes')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving || _deleting ? null : _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: Text(
                      context.tr(_deleting ? 'Deleting…' : 'Delete App'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
