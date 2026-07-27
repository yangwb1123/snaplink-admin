part of 'oidc_login_screen.dart';

extension _OidcAccountFlow on _OidcLoginScreenState {
  Future<void> _submitForgotPassword() async {
    final identifier = _forgotIdCtrl.text.trim();
    if (identifier.isEmpty) {
      _update(() {
        _forgotMessage = null;
        _error = 'Enter your username or email.';
      });
      return;
    }
    _update(() {
      _loading = true;
      _error = null;
      _forgotMessage = null;
    });
    try {
      final status = await _api.forgotPassword(identifier);
      if (!mounted) return;
      if (status >= 200 && status < 300) {
        _update(
          () => _forgotMessage =
              'If an eligible account exists, recovery instructions have '
              'been sent.',
        );
      } else if (status == 404) {
        _update(
          () => _error =
              'Password recovery is not available for this deployment.',
        );
      } else if (status == 429) {
        _update(() => _error = 'Too many requests. Please wait and try again.');
      } else {
        _update(
          () => _error =
              'Recovery instructions could not be requested. Try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  Future<void> _submitResetPassword() async {
    final token = _resetToken;
    final password = _resetPassCtrl.text;
    if (token == null) {
      _update(() => _error = 'This reset link is missing its token.');
      return;
    }
    if (password.isEmpty) {
      _update(() => _error = 'Enter a new password.');
      return;
    }
    if (password != _resetConfirmCtrl.text) {
      _update(() => _error = 'The passwords do not match.');
      return;
    }

    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await _api.resetPassword(token, password);
      if (!mounted) return;
      _resetPassCtrl.clear();
      _resetConfirmCtrl.clear();
      if (outcome.ok) {
        _showAccountResult(
          title: 'Password updated',
          message:
              'Your password has been changed and existing sessions have '
              'been revoked where supported.',
          icon: Icons.password_outlined,
        );
      } else {
        _update(
          () => _error = outcome.error == 'password_policy_violation'
              ? 'The new password does not meet the password policy. Request '
                    'a new reset link before trying again.'
              : 'This reset link is invalid or expired. Request a new link.',
        );
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  Future<void> _submitSignup() async {
    final username = _signupUserCtrl.text.trim();
    final password = _signupPassCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      _update(() => _error = 'Enter a username and password.');
      return;
    }
    if (password != _signupConfirmCtrl.text) {
      _update(() => _error = 'The passwords do not match.');
      return;
    }

    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await _api.register(
        username: username,
        password: password,
        email: _signupEmailCtrl.text.trim(),
      );
      if (!mounted) return;
      _signupPassCtrl.clear();
      _signupConfirmCtrl.clear();
      if (outcome.ok && outcome.data['status'] == 'pending') {
        _update(() {
          _view = _View.pendingVerification;
          _error = null;
        });
      } else if (outcome.ok && outcome.data['status'] == 'created') {
        _update(() {
          _userCtrl.text = username;
          _signupConfirmed = 'Account created. You can now sign in.';
          _view = _View.login;
          _error = null;
        });
      } else {
        _update(() => _error = _signupError(outcome));
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  String _signupError(LoginOutcome outcome) {
    switch (outcome.error) {
      case 'password_policy_violation':
        return 'The password does not meet the password policy.';
      case 'rate_limited':
        return 'Too many registration attempts. Please wait and try again.';
      case 'registration_denied':
        return 'Registration could not be approved.';
      case 'account_exists':
        return 'An account could not be created with those details.';
      case 'invalid_request':
        return 'Check the required account details and try again.';
      default:
        return 'The account could not be created. Try again.';
    }
  }

  Future<void> _submitEmailVerification() async {
    final token = _verificationToken;
    if (token == null) {
      _update(() => _error = 'This verification link is missing its token.');
      return;
    }
    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await _api.verifyEmail(token);
      if (!mounted) return;
      if (outcome.ok) {
        _showAccountResult(
          title: 'Email verified',
          message: 'Your account is ready. You can now sign in.',
          icon: Icons.mark_email_read_outlined,
        );
      } else {
        _update(
          () => _error =
              'This verification link is invalid or expired. Request a new '
              'link.',
        );
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  void _showAccountResult({
    required String title,
    required String message,
    required IconData icon,
  }) {
    _update(() {
      _accountResultTitle = title;
      _accountResultMessage = message;
      _accountResultIcon = icon;
      _view = _View.accountResult;
      _error = null;
    });
  }

  void _showLogin() {
    _update(() {
      _view = _View.login;
      _error = null;
      _forgotMessage = null;
    });
  }
}
