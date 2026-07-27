part of 'oidc_login_screen.dart';

extension _OidcChallengeFlow on _OidcLoginScreenState {
  void _handleLoginError(LoginOutcome outcome) {
    if (outcome.isMfaRequired) {
      _update(() {
        _mfaChallengeId = outcome.data['mfa_challenge_id']?.toString() ?? '';
        _mfaMethods = (outcome.data['mfa_methods'] as List? ?? [])
            .map((item) => item.toString())
            .toList();
        _mfaMethodData = _methodData(outcome.data['mfa_method_data']);
        _selectedMfaMethod = _mfaMethods.length == 1 ? _mfaMethods.first : null;
        _view = _View.mfa;
        _error = null;
      });
      return;
    }
    if (outcome.isConsentRequired) {
      final challengeId =
          outcome.data['consent_challenge_id']?.toString().trim() ?? '';
      final parsedSummary = ConsentRequestSummary.fromResponse(outcome.data);
      _update(() {
        _consentChallengeId = challengeId;
        _consentClientName =
            outcome.data['client_name']?.toString().trim() ?? '';
        _consentSummary = challengeId.isEmpty
            ? const ConsentRequestSummary.invalid(
                'The server did not provide a consent challenge.',
              )
            : parsedSummary;
        _view = _View.consent;
        _error = null;
      });
      return;
    }
    if (outcome.error == 'password_expired') {
      _update(() {
        _view = _View.forgotPassword;
        _forgotIdCtrl.text = _userCtrl.text.trim();
        _forgotMessage = null;
        _error = null;
      });
      return;
    }
    _update(() => _error = outcome.error ?? 'Authentication failed.');
  }

  Map<String, Map<String, String>> _methodData(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): {
            for (final value in (entry.value as Map).entries)
              value.key.toString(): value.value.toString(),
          },
    };
  }

  Future<void> _submitMfa() async {
    final method = _selectedMfaMethod;
    if (method == null) {
      _update(() => _error = 'Select a verification method.');
      return;
    }
    if (method != 'webauthn' &&
        method != 'push' &&
        _mfaCodeCtrl.text.trim().isEmpty) {
      _update(() => _error = 'Enter the verification code.');
      return;
    }

    _update(() {
      _loading = true;
      _error = null;
    });
    var requestSubmitted = false;
    try {
      String? code;
      Map<String, String>? params;
      if (method == 'webauthn') {
        final data = _mfaMethodData[method];
        if (data?['options'] == null || data?['session'] == null) {
          throw StateError('Passkey verification is unavailable.');
        }
        final assertion = await WebAuthnAssertion.request(data!['options']!);
        params = {'session': data['session']!, 'assertion': assertion};
      } else if (method == 'push') {
        final approvalId = _mfaMethodData[method]?['approval_id'];
        if (approvalId == null || approvalId.isEmpty) {
          throw StateError('Push verification is unavailable.');
        }
        params = {'approval_id': approvalId};
      } else {
        code = _mfaCodeCtrl.text.trim();
      }

      requestSubmitted = true;
      final outcome = await _api.mfaComplete(
        mfaChallengeId: _mfaChallengeId,
        method: method,
        code: code,
        params: params,
        trustDevice: _trustThisDevice,
      );
      if (!mounted) return;
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else if (outcome.isConsentRequired || outcome.isMfaRequired) {
        _handleLoginError(outcome);
      } else if (outcome.error == 'mfa_invalid') {
        // Snaplink consumes the challenge before factor verification. A wrong,
        // expired, replayed, or unknown factor therefore cannot be retried
        // against this challenge and must restart primary authentication.
        _discardMfaChallenge(
          'The verification attempt expired. Sign in again to get a new '
          'challenge.',
        );
      } else {
        _discardMfaChallenge(
          'This verification challenge can no longer be used. Sign in again '
          'to get a new challenge.',
        );
      }
    } on StateError catch (error) {
      if (mounted) _update(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      if (requestSubmitted) {
        _discardMfaChallenge(
          'Verification could not be completed safely. Sign in again to get '
          'a new challenge.',
        );
      } else {
        _update(() => _error = 'Verification failed.');
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  void _discardMfaChallenge(String? message) {
    _update(() {
      _mfaChallengeId = '';
      _mfaMethods = const [];
      _mfaMethodData = const {};
      _selectedMfaMethod = null;
      _mfaCodeCtrl.clear();
      _trustThisDevice = false;
      _pendingLoginPayload = null;
      _passCtrl.clear();
      _view = _View.login;
      _error = message;
    });
  }

  Future<void> _submitConsent(bool allow) async {
    if (!allow) {
      _clearConsentState();
      if (_isRpFlow && !_usesJarm) {
        _redirectAuthorizationResponse({
          'error': 'access_denied',
          if (_params.state.isNotEmpty) 'state': _params.state,
        }, tokenResponse: false);
      } else {
        _update(() {
          _view = _View.login;
          _error = null;
        });
      }
      return;
    }
    if (!_consentSummary.canAuthorize ||
        _pendingLoginPayload == null ||
        _consentChallengeId.isEmpty) {
      _update(
        () => _error =
            'Authorization is disabled because the request summary is invalid.',
      );
      return;
    }

    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await _api.login({
        ..._pendingLoginPayload!,
        'consent_challenge_id': _consentChallengeId,
      });
      if (!mounted) return;
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else {
        _handleLoginError(outcome);
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  void _clearConsentState() {
    _pendingLoginPayload = null;
    _consentChallengeId = '';
    _consentClientName = '';
    _consentSummary = const ConsentRequestSummary.invalid();
    _passCtrl.clear();
  }
}
