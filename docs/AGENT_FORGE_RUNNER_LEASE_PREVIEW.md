# Forge Runner lease/fencing local preview

Forge Sessions now has a local file entry point for the canonical
`forge.runner-lease-fencing/v1` contract. On Web, App, and Mobile the
**Import Runner lease/fencing JSON** action uses the existing workspace JSON
picker. The same widget accepts an injected reader for host tests and native
shell integrations.

The imported value is decoded by `ForgeRunnerLeaseFencingFixture`, which
rejects duplicate keys, unknown fields, schema or mode drift, invalid lease
values, and any authority bit set to `true`. The card displays only schema,
lease timing metadata, case names, and bounded outcome labels. Fencing tokens,
receipt digests, and terminal reasons are omitted from the UI.

This path is local and read-only. It does not call `/devices`, `/run-intents`,
reservation, scheduler, dispatch, Runner, receipt, or audit routes. It does
not select a target, acquire or renew a lease, persist a grant, or authorize
execution. The Rust CLI/TUI command
`device runner-lease-fencing-preview --input FILE` remains the corresponding
file-driven terminal entry point.

The focused Flutter test runs with
`FORGE_LEASE_FENCING_FIXTURE` pointing at the shared fixture:

```sh
FORGE_LEASE_FENCING_FIXTURE=/path/to/forge-runner-lease-fencing-v1.json \
  flutter test test/forge_runner_lease_fencing_preview_widget_test.dart --no-pub
```
