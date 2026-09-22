# Agent compute lost-task retry

The Compute task card exposes a retry action only when a task is `lost`. The
action sends `POST /api/v1/agent/tasks/{task_id}/retry` with
`confirm_duplicate: true`; the Hub may reject tasks whose evidence archive is
still pending or already stored. The selected target is sent when the operator
chooses one, and an empty selection lets the Hub preserve an original explicit
target or place an originally automatic task again.

The icon is labeled as a duplicate-risk action and is disabled while the
request is in flight or the identity lacks `agent.tasks:write`. A lost task is
never retried during refresh, reconnect, or normal polling. The API model
exposes `canRetry` so other Console surfaces can use the same terminal-state
rule without inferring it from error text.

Verification:

- `flutter test test/agent_hub_api_test.dart test/agent_compute_reschedule_widget_test.dart`
- `flutter analyze` (the touched Agent files are clean; the current workspace
  retains two unrelated Forge nullable-type errors)
