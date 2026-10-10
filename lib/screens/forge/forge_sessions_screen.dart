import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';
import 'package:sso_admin/api/forge_prompt_append_receipt.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/services/forge_change_cursor_store.dart';
import 'package:sso_admin/services/forge_run_timeline_cursor_store.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_conversation_metadata_cache.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/forge_oauth_token_refresh.dart';
import 'package:sso_admin/services/product_api_origin.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_local_runner_preview.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/api/forge_run_receipt_observation_convergence.dart';
import 'package:sso_admin/api/forge_run_execution_evidence.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_vectors.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';
import 'package:sso_admin/api/forge_session_runner_reconciliation_projection.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
import 'package:sso_admin/api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import 'package:sso_admin/api/forge_device_credential_candidate.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/api/forge_attempt_request_preview.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';
import 'package:sso_admin/api/forge_runner_lease_fencing.dart';
import 'package:sso_admin/api/forge_execution_lease_checkpoint.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_preflight_fixture.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/api/forge_runner_dispatch_plan_preview.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';
import 'forge_sessions_device_observation.dart';
import 'forge_device_inventory_panel.dart';
import 'forge_device_resource_summary_panel.dart';
import 'forge_device_inventory_v2_panel.dart';
import 'forge_device_inventory_placement_evaluation_v2_panel.dart';
import 'forge_device_inventory_placement_evaluation_panel.dart';
import 'forge_device_inventory_placement_batch_evaluation_panel.dart';
import 'forge_run_intent_observation_card.dart';
import 'forge_runner_execution_intent_card.dart';
import 'forge_run_observed_card.dart';
import 'forge_run_execution_evidence_card.dart';
import 'forge_session_runner_receipt_observation_card.dart';
import 'forge_session_runner_receipt_vectors_panel.dart';
import 'forge_session_runner_receipt_history_panel.dart';
import 'forge_session_runner_reconciliation_projection_panel.dart';
import 'forge_execution_reconciliation_observation_card.dart';
import 'forge_execution_consent_preview_card.dart';
import 'forge_attempt_request_preview_card.dart';
import 'forge_pending_run_intent_card.dart';
import 'forge_pending_run_intent_metadata_panel.dart';
import 'forge_pending_run_intent_submission_card.dart';
import 'forge_runner_lease_fencing_preview_card.dart';
import 'forge_execution_lease_checkpoint_preview_card.dart';
import 'forge_client_instance_session_view_panel.dart';
import 'forge_client_instance_resource_view_panel.dart';
import 'forge_lifecycle_registry_panel.dart';
import 'forge_device_credential_candidate_panel.dart';
import 'forge_device_registry_placement_preview_panel.dart';
import 'forge_scheduler_selection_preview_panel.dart';
import 'forge_scheduler_selection_lease_panel.dart';
import 'forge_scheduler_selection_lease_release_panel.dart';
import 'forge_local_runner_preview_card.dart';
import 'package:sso_admin/screens/agent/forge_runner_dispatch_plan_preview_card.dart';
import 'forge_runner_dispatch_admission_card.dart';
import 'forge_runner_transport_admission_card.dart';
import 'forge_runner_execution_boundary_card.dart';
import 'forge_runner_attempt_boundary_card.dart';
import 'package:sso_admin/screens/agent/forge_preflight_fixture_card.dart';
import '../../services/agent_workspace_file.dart';
part 'forge_sessions_screen_view.dart';
part 'forge_sessions_screen_helpers.dart';
part 'forge_runs_panel.dart';
part 'forge_sessions_screen_contract_1.dart';
part 'forge_sessions_screen_contract_2.dart';
part 'forge_sessions_screen_transport_options.dart';
part 'forge_sessions_screen_widget.dart';
part 'forge_sessions_screen_storage.dart';
part 'forge_sessions_screen_widget_changes.dart';
part 'forge_sessions_screen_apply_device_changes.dart';
part 'forge_sessions_screen_apply_runner_changes.dart';
part 'forge_sessions_screen_apply_receipt_changes.dart';
part 'forge_sessions_screen_apply_import_changes.dart';
part 'forge_sessions_screen_initial_load.dart';
part 'forge_sessions_screen_change_polling.dart';
part 'forge_sessions_screen_change_sync.dart';
part 'forge_sessions_screen_location.dart';
part 'forge_sessions_screen_conversation_reads.dart';
part 'forge_sessions_screen_preview_validation.dart';
part 'forge_sessions_screen_receipt_imports.dart';
part 'forge_sessions_screen_inventory_imports.dart';
part 'forge_sessions_screen_private_selection_reset.dart';
part 'forge_sessions_screen_client_instance_filter.dart';
part 'forge_sessions_screen_resource_guards.dart';
part 'forge_sessions_screen_prompt_reads.dart';
part 'forge_sessions_screen_conversation_create.dart';
part 'forge_sessions_screen_run_reads.dart';
part 'forge_sessions_screen_device_observation.dart';
part 'forge_sessions_screen_run_observation.dart';
part 'forge_sessions_screen_receipt_reads.dart';
part 'forge_sessions_screen_inventory_reads.dart';
part 'forge_sessions_screen_registry_reads.dart';
part 'forge_sessions_screen_scheduler_preview.dart';
part 'forge_sessions_screen_scheduler_leases.dart';
part 'forge_sessions_screen_client_instance_reads.dart';
part 'forge_sessions_screen_dispatch_preview.dart';
part 'forge_sessions_screen_runner_intent.dart';
part 'forge_sessions_screen_runner_admission.dart';
part 'forge_sessions_screen_runner_boundaries.dart';
part 'forge_sessions_screen_execution_reconciliation.dart';
part 'forge_sessions_screen_pending_intent_reads.dart';
part 'forge_sessions_screen_pending_intent_timeline.dart';
part 'forge_sessions_screen_offline_receipt_imports.dart';
part 'forge_sessions_screen_prompt_append.dart';
part 'forge_sessions_screen_pending_intent_submit.dart';
part 'forge_sessions_screen_authentication.dart';
part 'forge_sessions_screen_state.dart';
part 'forge_sessions_display_projection_types.dart';
part 'forge_sessions_display_inputs.dart';
part 'forge_sessions_display_selection.dart';
part 'forge_sessions_display_runner.dart';
part 'forge_sessions_display_receipts.dart';
part 'forge_sessions_display_notices_items.dart';
part 'forge_sessions_display_local_items.dart';
part 'forge_sessions_display_runner_items.dart';
part 'forge_sessions_display_loading_items.dart';
part 'forge_sessions_display_workspace_items.dart';
part 'forge_sessions_display_inventory_items.dart';
part 'forge_sessions_display_receipts_items.dart';
part 'forge_sessions_display_receipt_validation.dart';
part 'forge_sessions_display_runner_validation.dart';
part 'forge_sessions_display_panels.dart';
part 'forge_sessions_display_receipt_import_actions.dart';
part 'forge_sessions_display_inventory_import_actions.dart';
part 'forge_sessions_display_conversation_widgets.dart';
part 'forge_sessions_display_status_widgets.dart';

const _changePollBaseDelay = Duration(seconds: 15);
const _changePollMaxDelay = Duration(minutes: 2);
const _changePollMaxFailureStreak = 3;
const _changeStreamReconnectDelay = Duration(milliseconds: 50);

class _PendingRunIntentRequest {
  final String content;
  final int expectedVersion;
  final String idempotencyKey;

  const _PendingRunIntentRequest({
    required this.content,
    required this.expectedVersion,
    required this.idempotencyKey,
  });
}

enum _ForgeChangeSyncOutcome {
  skipped,
  failed,
  unchanged,
  changed,
  advancedHidden,
}

enum _ForgeChangePollOutcome { skipped, failed, succeeded }
