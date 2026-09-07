# R241 backend route regression

## Verdict

Verified and pinned with tests only; no runtime route, authentication, method-probe, or wire changes.

- Backend HEAD: `41978ff51f4d8b17fc2001d872119b7234d394fc`.
- `git merge-base --is-ancestor 0aab82b5 HEAD` exited `0`; HEAD is a successor of `0aab82b5` (`fix(admin-gateway): P3-1 audit — register clients/expiring in the gateway exact-path list`).
- Generated gateway evidence: `gen/proto/admin/v1/clients.pb.gw.go` registers `GET /api/v1/admin/clients/expiring` for `ListExpiring`.
- Composition evidence: `GatewayPaths()` contains the literal path, `adminGatewayExactPaths()` delegates to it, and `TestAdminGatewayExactPaths_PinClientsExpiring` pins that ownership. `TestAdminGatewayE2E_GatewayFamiliesReachRealGateway` exercises the URL through `buildApp` + `buildHTTPHandler` with a real admin bearer and obtains 200; the test seeds the literal `expiring` client so the reachability signal is stable.

The path is an sso-server admin gateway route. Billing/commerce routes, the Stripe checkout adapter route, and Audit Governance routes are separate services and were not counted as sso-server routes.

## Stripe probe contract

`cmd/snaplink-stripe-adapter/http.go` mounts `pathCheckout` from `model.go` at `/api/v1/checkout/sessions`. `handleCheckout` authenticates first, then rejects non-POST methods before billing, store, or Stripe work. `TestCheckoutProbeGETReturns405WithoutProviderInteractions` uses a valid bearer and pins:

- `GET /api/v1/checkout/sessions` => **405 Method Not Allowed**;
- store reserve/inbox calls, billing calls, and Stripe calls remain zero.

This status means “the authenticated adapter route is mounted, but GET is not an allowed checkout operation.” A missing/misrouted route remains 404; an invalid bearer is rejected by the auth middleware before the method probe and is not an enabled signal.

## Verification

From `/home/u1/workspace/demo/snaplink`:

```text
gofmt -w cmd/sso-server/admin_gateway_routing_test.go \
  cmd/sso-server/admin_gateway_routing_e2e_test.go \
  cmd/snaplink-stripe-adapter/http_test.go
go test ./cmd/sso-server                         PASS
go test ./cmd/snaplink-stripe-adapter            PASS
git diff --check                                  PASS
```

## Backend worktree protection

The protected backend paths `go.mod` and `infrastructure/defaultimpl/memorystoreoauth/memory_refresh_token_copy_test.go` were inspected and not edited or overwritten. Final backend changes are limited to the three existing test files named above; no runtime source or generated wire file changed.
