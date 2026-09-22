import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/api/agent_idempotency_key.dart';
import 'package:sso_admin/services/agent_hub_oauth.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/session_cleanup.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'agent_operations_view.dart';
import 'agent_compute_placement.dart';
import 'agent_compute_placement_dialog.dart';
import 'agent_workspace_form.dart';
import 'agent_session_creation.dart';
import 'agent_session_creation_dialog.dart';
import 'agent_session_closure.dart';
import 'agent_session_close_dialog.dart';
import 'agent_session_history_dialog.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/session.dart';
import 'agent_workspace_selection.dart';
import 'agent_workspace_task_details.dart';

part 'agent_operations_screen_state.dart';
part 'agent_operations_screen_actions.dart';
part 'agent_operations_compute.dart';
part 'agent_operations_compute_state.dart';
part 'agent_operations_screen_view.dart';
part 'agent_operations_placement.dart';
part 'agent_operations_session_creation.dart';
part 'agent_operations_session_closure.dart';
part 'agent_operations_session_history.dart';

class AgentOperationsScreen extends StatefulWidget {
  final String accessToken;
  final String apiOrigin;
  final http.Client? httpClient;

  const AgentOperationsScreen({
    super.key,
    required this.accessToken,
    required this.apiOrigin,
    this.httpClient,
  });

  @override
  State<AgentOperationsScreen> createState() => _AgentOperationsScreenState();
}
