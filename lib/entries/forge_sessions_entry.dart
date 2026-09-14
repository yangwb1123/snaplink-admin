import 'package:flutter/material.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

Widget buildForgeSessionsScreen() =>
    const ErrorBoundary(child: ForgeSessionsGate());
