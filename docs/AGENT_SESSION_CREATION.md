# Remote session creation in Agent Operations

Agent Operations can create a fresh session on a selected online Gateway, including
when its session directory is empty. Open **New session**, choose a target instance,
enter a name, and select **Create session**. An existing instance filter preselects
that target when it is eligible; the All instances view requires an explicit choice.

Only online instances advertising `session_capacity > 0` appear as targets. Older
Gateways omit the field and are treated as unsupported. A capacity advertisement
is the instance's configured maximum, not a count of available slots; Hub makes
the final atomic admission decision. The Gateway uses its operator-configured
project, working directory and model. This form does not change those settings.
Names must contain no Unicode Cc/Cf control or format characters before trimming;
the trimmed value must be nonempty and at most 256 UTF-8 bytes.

## Request lifecycle and recovery

Creation is asynchronous. The Console submits `POST
/api/v1/agent/instances/{instance_id}/sessions` with `{name}` and an
`Idempotency-Key`, then reads `GET /api/v1/agent/session-requests/{request_id}`.
It requires `agent.sessions:write` for submission and `agent.sessions:read` for
tracking and opening the result. Existing instance restrictions continue to apply.

The Console tracks one creation workflow at a time:

- An accepted queued request is read every two seconds after the preceding read
  finishes. There is no automatic business POST retry or overlapping status read.
- Closing the dialog leaves tracking active. **Session creation status** reopens
  it. A failed status read pauses polling; **Retry status** resumes GET tracking.
- A network failure or invalid submission response leaves the result unknown.
  **Retry same request** reuses the exact target, normalized name and key. Those
  inputs stay locked until the outcome is recovered.
- A definite rejection of the initial submission, such as unsupported/offline/full,
  allows changing the target and name. Recovery retries always preserve the original
  key, even if access has since been denied; a rejected retry cannot prove that the
  initial submission was never accepted. Authorization failures use fixed copy; raw upstream error
  messages and authentication tokens are never displayed by this workflow.
- A created session is opened automatically only if the instance filter and
  session selection still match the context at submission. Otherwise current
  focus remains intact and **Open session** is an explicit action.
- Failed creation and lost generation have fixed outcomes. A lost request does
  not start another session automatically; check the directory before choosing
  **Start another session**.

Tracking and idempotency keys live only in the current Agent Operations screen's
memory. Leaving the screen, reloading the page, signing in again, or restarting
the application ends this recovery state; it is not a durable cross-device request
inbox. Closing the dialog does not cancel creation on Hub. After losing local
tracking, inspect the target's session directory before submitting another request.
The Console does not delete, fork, migrate, or resume a session through this form.

## Validation

The implementation uses the existing bearer-authenticated, bounded HTTP transport.
Creation/status bodies have a 32 KiB limit; redirects are disabled. Response DTOs
validate identity, state/session consistency, numeric timestamps and expected
request inputs before updating the UI. Unknown error text is replaced with fixed
English/Chinese messages.

The new tests in `test/agent_session_creation_test.dart` and
`test/agent_session_creation_widget_test.dart` exercise the production API,
controller and widgets through `http.MockClient`, including request bodies,
idempotency after a lost reply, concurrent submission, permission-denied recovery, late-401 credential protection, status failure recovery,
capacity defaults, malformed/bounded responses, fixed diagnostics, empty-directory
creation, dialog reopening, focus preservation and 320px English/Chinese layouts.
They do not claim a live browser-to-Hub-to-Gateway execution or native-device run.

Validation results and toolchain constraints are recorded in
[the verification report](AGENT_SESSION_CREATION_VERIFICATION.md).
