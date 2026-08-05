part of 'oidc_login_screen.dart';

extension _OidcChallengeFlow on _OidcLoginScreenState {
  void _handleLoginError(LoginOutcome outcome) {
    if (outcome.isMfaRequired) {
      // A grant presented for this client did not skip MFA. Treat it as stale
      // so future sign-ins do not keep replaying a bearer-equivalent value the
      // server has already declined.
      TrustedDeviceToken.clear(_effectiveClientId);
      final challengeId =
          outcome.data['mfa_challenge_id']?.toString().trim() ?? '';
      final rawMethods = outcome.data['mfa_methods'];
      final methods = (rawMethods is List ? rawMethods : const <Object?>[])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
      // The server owns the MFA state machine. Never render a challenge that
      // cannot be addressed with a real one-time id and at least one
      // server-declared factor; otherwise a malformed response would make the
      // page issue a guaranteed-invalid /auth/mfa request.
      if (challengeId.isEmpty || methods.isEmpty) {
        _update(() {
          _mfaChallengeId = '';
          _mfaMethods = const [];
          _mfaMethodData = const {};
          _selectedMfaMethod = null;
          _mfaCodeCtrl.clear();
          _passCtrl.clear();
          _providerCodeCtrl.clear();
          _view = _View.login;
          _error =
              'Snaplink returned an incomplete verification challenge. '
              'Sign in again to request a new challenge.';
        });
        return;
      }
      _update(() {
        _mfaChallengeId = challengeId;
        _mfaMethods = methods;
        _mfaMethodData = _methodData(outcome.data['mfa_method_data']);
        _selectedMfaMethod = methods.length == 1 ? methods.first : null;
        _passCtrl.clear();
        _providerCodeCtrl.clear();
        _view = _View.mfa;
        _error = null;
      });
      return;
    }
    if (outcome.isConsentRequired) {
      final challengeId =
          outcome.data['consent_challenge_id']?.toString().trim() ?? '';
      final transactionId =
          outcome.data['login_transaction_id']?.toString().trim() ?? '';
      final parsedSummary = ConsentRequestSummary.fromResponse(outcome.data);
      _update(() {
        _consentChallengeId = challengeId;
        _loginTransactionId = transactionId;
        _passCtrl.clear();
        _providerCodeCtrl.clear();
        _consentClientName =
            outcome.data['client_name']?.toString().trim() ?? '';
        _consentSummary = challengeId.isEmpty
            ? const ConsentRequestSummary.invalid(
                'The server did not provide a consent challenge.',
              )
            : transactionId.isEmpty
            ? const ConsentRequestSummary.invalid(
                'The server did not provide a secure authorization transaction.',
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
      _passCtrl.clear();
      _view = _View.login;
      _error = message;
    });
  }

  Future<void> _submitConsent(bool allow) async {
    if (!allow && _loginTransactionId.isEmpty) {
      _update(
        () => _error =
            'Snaplink did not provide a secure authorization transaction. '
            'The request was not approved or denied.',
      );
      return;
    }
    if ((allow && !_consentSummary.canAuthorize) ||
        _loginTransactionId.isEmpty ||
        _consentChallengeId.isEmpty) {
      _update(
        () => _error =
            'Authorization is disabled because the request summary is invalid.',
      );
      return;
    }

    final transactionId = _loginTransactionId;
    final challengeId = _consentChallengeId;
    _update(() {
      _loading = true;
      _error = null;
      // The server transaction is one-shot. Move it out of page state before
      // the mutation so an ambiguous timeout or lost response can never make
      // the same consent decision available for replay.
      _loginTransactionId = '';
      _consentChallengeId = '';
      _consentSummary = const ConsentRequestSummary.invalid(
        'The authorization decision was submitted. Restart authorization if '
        'no result is received.',
      );
    });
    try {
      final payload = <String, dynamic>{
        'client_id': _effectiveClientId,
        'login_transaction_id': transactionId,
      };
      final outcome = await _api.login({
        ...payload,
        'consent_challenge_id': challengeId,
        'consent_decision': allow ? 'allow' : 'deny',
      });
      if (!mounted) return;
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else if (!allow && outcome.error == 'access_denied') {
        _clearConsentState();
        _redirectAuthorizationError(outcome);
      } else {
        _handleLoginError(outcome);
      }
    } catch (_) {
      if (mounted) {
        _update(
          () => _error =
              'The authorization result is unknown. Restart authorization; '
              'this decision was not replayed.',
        );
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  void _clearConsentState() {
    _loginTransactionId = '';
    _consentChallengeId = '';
    _consentClientName = '';
    _consentSummary = const ConsentRequestSummary.invalid();
    _passCtrl.clear();
  }
}
