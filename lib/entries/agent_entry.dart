import 'package:flutter/material.dart';
import 'package:sso_admin/screens/agent/agent_operations_gate.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// Multi-instance Agent session control surface, separate from SSO sessions.
Widget buildAgentOperationsScreen() =>
    const ErrorBoundary(child: AgentOperationsGate());
