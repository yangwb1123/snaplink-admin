import 'package:flutter/material.dart';

import '../oidc_login/trusted_device_token.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';
import 'security_change_email_card.dart';
import 'security_change_password_card.dart';

class SecurityAccountCredentials extends StatefulWidget {
  final PortalApi api;

  const SecurityAccountCredentials({super.key, required this.api});

  @override
  State<SecurityAccountCredentials> createState() =>
      _SecurityAccountCredentialsState();
}

class _SecurityAccountCredentialsState
    extends State<SecurityAccountCredentials> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _newEmail = TextEditingController();
  final _emailToken = TextEditingController();
  String? _passwordMessage;
  bool _passwordOk = false;
  bool _passwordBusy = false;
  bool _emailVerifyVisible = false;
  String? _emailMessage;
  bool _emailOk = false;
  bool _emailBusy = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _newEmail.dispose();
    _emailToken.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentPassword.text;
    final next = _newPassword.text;
    if (current.isEmpty || next.isEmpty) {
      setState(() {
        _passwordMessage = 'Fill in both fields.';
        _passwordOk = false;
      });
      return;
    }
    setState(() {
      _passwordBusy = true;
      _passwordMessage = null;
    });
    try {
      final response = await widget.api.post('/me/password', {
        'current_password': current,
        'new_password': next,
      });
      if (!mounted) return;
      if (response.statusCode == 204) {
        final clientId = widget.api.currentClientId;
        if (clientId != null) TrustedDeviceToken.clear(clientId);
        setState(() {
          _passwordMessage =
              'Password updated. Existing trusted-browser grants were revoked.';
          _passwordOk = true;
        });
        _currentPassword.clear();
        _newPassword.clear();
      } else if (response.statusCode == 404) {
        setState(() {
          _passwordMessage = 'Password change is not enabled.';
          _passwordOk = false;
        });
      } else {
        final code = PortalApi.decode(response)['error']?.toString();
        setState(() {
          _passwordMessage = switch (code) {
            'invalid_password' => 'Current password was not accepted.',
            'password_policy_violation' =>
              'Choose a password that meets policy and was not used recently.',
            'region_not_allowed' =>
              'Password changes are not allowed from this region.',
            _ => 'Password was not changed.',
          };
          _passwordOk = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _passwordMessage = 'Request failed.';
          _passwordOk = false;
        });
      }
    } finally {
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  Future<void> _sendEmailCode() async {
    final value = _newEmail.text.trim();
    if (value.isEmpty) {
      setState(() {
        _emailMessage = 'Enter a new email address.';
        _emailOk = false;
      });
      return;
    }
    setState(() {
      _emailBusy = true;
      _emailMessage = null;
    });
    try {
      final response = await widget.api.post('/me/email/change', {
        'new_email': value,
      });
      if (!mounted) return;
      if (response.statusCode == 404) {
        setState(() {
          _emailMessage = 'Email change is not enabled.';
          _emailOk = false;
        });
      } else if (response.statusCode == 200) {
        setState(() {
          _emailMessage = 'We sent a verification token to $value.';
          _emailOk = true;
          _emailVerifyVisible = true;
        });
      } else {
        setState(() {
          _emailMessage = 'That email could not be used.';
          _emailOk = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _emailMessage = 'Request failed.';
          _emailOk = false;
        });
      }
    } finally {
      _emailToken.clear();
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _verifyEmailCode() async {
    final token = _emailToken.text.trim();
    if (token.isEmpty) {
      setState(() {
        _emailMessage = 'Enter the verification code.';
        _emailOk = false;
      });
      return;
    }
    setState(() {
      _emailBusy = true;
      _emailMessage = null;
    });
    try {
      final response = await widget.api.post('/me/email/verify', {
        'token': token,
      });
      if (!mounted) return;
      if (response.statusCode == 404) {
        setState(() {
          _emailMessage = 'Email change is not enabled.';
          _emailOk = false;
        });
      } else if (response.statusCode == 200) {
        setState(() {
          _emailMessage = 'Your email has been updated.';
          _emailOk = true;
          _emailVerifyVisible = false;
        });
        _newEmail.clear();
        _emailToken.clear();
      } else {
        setState(() {
          _emailMessage = 'That code was not accepted.';
          _emailOk = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _emailMessage = 'Request failed.';
          _emailOk = false;
        });
      }
    } finally {
      _emailToken.clear();
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PortalCard(
        title: 'Change password',
        children: [
          SecurityChangePasswordCard(
            curPwCtrl: _currentPassword,
            newPwCtrl: _newPassword,
            pwBusy: _passwordBusy,
            pwMsg: _passwordMessage,
            pwOk: _passwordOk,
            onChangePassword: _changePassword,
          ),
        ],
      ),
      PortalCard(
        title: 'Change email',
        children: [
          SecurityChangeEmailCard(
            newEmailCtrl: _newEmail,
            emailTokenCtrl: _emailToken,
            emailBusy: _emailBusy,
            emailVerifyVisible: _emailVerifyVisible,
            emailMsg: _emailMessage,
            emailOk: _emailOk,
            onSendCode: _sendEmailCode,
            onVerifyCode: _verifyEmailCode,
          ),
        ],
      ),
    ],
  );
}
