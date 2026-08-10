import 'package:flutter/material.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';

/// 托管登录入口 — 独立 deferred chunk。
Widget buildLoginScreen({
  String? defaultClientId,
  OidcLoginApi? api,
  required Uri routeUri,
}) =>
    OidcLoginScreen(
      defaultClientId: defaultClientId,
      api: api,
      routeUri: routeUri,
    );
