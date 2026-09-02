# Deploying sso-console

This is a single static Flutter web bundle that serves six different areas
of the SSO product (`/admin/`, `/login/`, `/setup/`, `/portal/`,
`/developer/`, `/device/verify`) — `lib/app_router.dart`'s
`resolveInitialScreen()` picks which screen to show based on the URL path the
browser actually loaded. The app itself doesn't care which prefix it was
reached through; **an upstream gateway is expected to route** `/admin/`,
`/login/`, `/portal/`, `/developer/`, `/setup/`, `/device/verify`, and
`/app/` (the static-asset prefix baked in via `--base-href=/app/`) to wherever
this app's root (`/`) ends up listening. The supplied nginx template also
accepts those paths directly and proxies the console's same-origin API paths
to `SNAPLINK_UPSTREAM`. Commercial and metering paths are routed to
`SNAPLINK_BILLING_UPSTREAM`; it may equal `SNAPLINK_UPSTREAM` for a minimal
deployment, or identify the independent API-only Billing service in a full
deployment. Audit reads are always rewritten onto the canonical Audit
Governance API at `AUDIT_GOVERNANCE_UPSTREAM`; there is no local audit-store
fallback in the Console proxy.

Stripe top-up checkout uses the exact same-origin path
`POST /api/v1/checkout/sessions`, routed only to
`SNAPLINK_STRIPE_ADAPTER_UPSTREAM`. The browser reuses its current admin
Bearer; it never receives a Stripe secret or a machine-client secret. That
Snaplink token must carry `admin:write` and an `aud` value (or audience array)
containing the adapter's configured `SNAPLINK_STRIPE_AUDIENCE`; Billing calls
likewise require `SNAPLINK_BILLING_AUDIENCE`. Audit reads require the
`audit-governance` audience. Audit Governance independently validates the
Snaplink token and maps its audience-bound `admin:read` permission to the
tenant-scoped event read surface.

The Admin Console requests all three audiences on direct and hosted login. Set the
comma-separated build value `SNAPLINK_ADMIN_OAUTH_RESOURCES` to those exact
resource identifiers. Its default is
`billing-api,stripe-adapter-api,audit-governance`. The `sso-admin-console`
client's `allowed_resources`, Billing audience, Stripe audience, Audit
Governance audience, and this build value must agree. Because
Flutter is a static bundle, changing a container runtime environment variable
does not change this setting; rebuild the image or `build/web/` artifact.
The adapter must independently bind the requested `tenant_id` and permit the
console's exact HTTPS return origin.

Each proxy target has an independent TLS trust tuple:

- Snaplink: `SNAPLINK_UPSTREAM`, `SNAPLINK_SERVER_NAME`, `SNAPLINK_CA`
- Billing: `SNAPLINK_BILLING_UPSTREAM`, `SNAPLINK_BILLING_SERVER_NAME`,
  `SNAPLINK_BILLING_CA`
- Stripe adapter: `SNAPLINK_STRIPE_ADAPTER_UPSTREAM`,
  `SNAPLINK_STRIPE_ADAPTER_SERVER_NAME`, `SNAPLINK_STRIPE_ADAPTER_CA`
- Audit Governance: `AUDIT_GOVERNANCE_UPSTREAM`,
  `AUDIT_GOVERNANCE_SERVER_NAME`, `AUDIT_GOVERNANCE_CA`

nginx enables SNI and certificate verification for every HTTPS target. The
server name must match its certificate and the CA file must contain only the
trust anchors intended for that target. TLS directives are ignored for a plain
HTTP target; use HTTP only on a trusted loopback or private service network.
Changing one target never changes another target's server name or CA.

For direct static hosting, build the production artifact with:

```bash
SNAPLINK_ADMIN_OAUTH_RESOURCES='https://billing.example.com,https://stripe-adapter.example.com,https://audit-governance.example.com' \
  make build-prod
```

This produces `build/web/` — a plain directory of static files (HTML/JS/CSS/
assets). The Dockerfile performs the equivalent build inside its build stage,
so container workflows do not require a host Flutter installation. The image
pins the Flutter stable archive and its SHA-256 checksum; override
`FLUTTER_VERSION` and `FLUTTER_SHA256` together only when intentionally
updating the build toolchain.

Pick **one** of the following:

## Method 1: Kubernetes

The checked-in manifest is a registry-compatible, multi-replica production
baseline. For a disconnected cluster, build locally and import the same image
into every schedulable node's containerd.

Choose the profile before building because OAuth resource indicators are part
of the static Flutter bundle. A full deployment requests the Billing and
Stripe Adapter audiences, always requests Audit Governance, and keeps their independent TLS trust roots:

```bash
docker build \
  --build-arg SNAPLINK_ADMIN_OAUTH_RESOURCES='https://billing.example.com,https://stripe-adapter.example.com,https://audit-governance.example.com' \
  -t snaplink/sso-console:v1 .
kubectl apply -k k8s/full
```

A minimal deployment requests only the required Audit Governance audience. Its commercial and
Checkout locations intentionally fall through to the required SSO upstream,
which returns 404, so nginx never resolves optional service names. The
minimal profile also removes both optional CA Secret volumes:

```bash
docker build \
  --build-arg SNAPLINK_ADMIN_OAUTH_RESOURCES='audit-governance' \
  -t snaplink/sso-console:v1 .
kubectl apply -k k8s/minimal
```

For an air-gapped cluster, import the selected image into every schedulable
node before applying its profile:

```bash
docker save snaplink/sso-console:v1 | ssh <node> ctr -n k8s.io images import -
```

The shared `k8s/base/deployment.yaml` deploys into the `sv-sso` namespace (same namespace as
`sso-server`) and proxies same-origin API calls to it over in-cluster DNS at
`sso-server.sv-sso.svc.cluster.local:8080`. It runs as non-root (UID 65532)
with a read-only root filesystem. The default `IfNotPresent` pull policy works
with either a registry or images preloaded on every eligible node.
The full profile sets `SNAPLINK_UPSTREAM` to `sso-server` and
`SNAPLINK_BILLING_UPSTREAM` to `snaplink-billing` in the same namespace;
change the corresponding origin, server name, and CA together if those
services have different names. Billing's certificate must be valid for
`SNAPLINK_BILLING_SERVER_NAME`. Create the
external `snaplink-billing-client-ca` Secret with its trust anchor as
`ca.crt`; nginx verifies Billing TLS and will fail closed if the name or chain
does not match.
The Stripe adapter certificate must likewise be valid for
`SNAPLINK_STRIPE_ADAPTER_SERVER_NAME`. Create the separate external
`snaplink-stripe-adapter-client-ca` Secret with its trust anchor as `ca.crt`;
the Console workload does not reuse adapter credentials or private keys.

## Method 2: Docker (standalone)

For any environment that runs plain Docker without Kubernetes:

```bash
docker build \
  --build-arg SNAPLINK_ADMIN_OAUTH_RESOURCES='https://billing.example.com,https://stripe-adapter.example.com,https://audit-governance.example.com' \
  -t sso-console:latest .
docker run -d --name sso-console \
  --add-host=host.docker.internal:host-gateway \
  -e SNAPLINK_UPSTREAM=http://host.docker.internal:8080 \
  -e SNAPLINK_BILLING_UPSTREAM=http://host.docker.internal:8090 \
  -e SNAPLINK_STRIPE_ADAPTER_UPSTREAM=http://host.docker.internal:8091 \
  -e AUDIT_GOVERNANCE_UPSTREAM=http://host.docker.internal:8089 \
  -p 8081:80 sso-console:latest
```

This example assumes Snaplink listens on the Docker host at port 8080,
Billing at port 8090, the Stripe adapter at port 8091, and Audit Governance at port 8089; the
console is reachable on `http://localhost:8081/`. In a Docker network, set
`SNAPLINK_UPSTREAM` to the backend service origin instead. For HTTPS, also set
that target's matching server-name and CA variables described above.
`docker compose up` uses `http://snaplink:8080` automatically. The Billing and
Stripe-adapter upstreams have **no implicit fallback** (P0-2): Compose fails
fast when `SNAPLINK_BILLING_UPSTREAM`/`SNAPLINK_STRIPE_ADAPTER_UPSTREAM` are
unset, so a deployment missing those services can never silently route
Billing/checkout traffic to the sso-server and surface confusing 404s.
Set the independent Billing/Stripe origins when those services are deployed.
The image repeats this contract for all four origins in
`docker-entrypoint.d/10-validate-upstreams.sh`: it rejects an empty value,
credentials, paths, queries, fragments, or non-HTTP(S) values before nginx
renders its configuration. Minimal Kubernetes may intentionally point both
optional variables at the core origin, but it must still set them explicitly.
Place the dedicated
test/backend configuration at `config.local.yaml` first. That local file is
gitignored and must not contain production secrets.

The minimal bundle can omit commerce audiences while retaining the required
Audit Governance resource:

```bash
SNAPLINK_ADMIN_OAUTH_RESOURCES='audit-governance' docker compose up --build
```

## Method 3: Manual / direct static hosting (no container)

This is the baseline, no-Docker option — and it's exactly how sso-console is
deployed in the live environment today: an OpenResty `alias` directive
pointing straight at the built directory, no container involved.

```bash
SNAPLINK_ADMIN_OAUTH_RESOURCES='https://billing.example.com,https://stripe-adapter.example.com,https://audit-governance.example.com' \
  make build-prod
```

Then serve the resulting `build/web/` directory with **any** static file
server capable of an SPA fallback (unknown paths resolve to `index.html`
rather than 404, since `resolveInitialScreen()` picks the screen client-side).
For example:

- **OpenResty / nginx**: an `alias /path/to/build/web;` location block plus
  `try_files $uri $uri/ /index.html;` (see `nginx.conf` in this repo for a
  minimal standalone example of the same fallback).
- **Caddy**: `file_server` with `try_files {path} /index.html`.
- **Repository development proxy** (quick local testing):
  replace `<your-audit-governance-origin>` with the deployed Audit Governance
  HTTP(S) origin, then run:
  `SNAPLINK_API_URL=http://localhost:8080 SNAPLINK_PROXY_PORT=4444
  SNAPLINK_STRIPE_ADAPTER_URL=http://localhost:8091
  AUDIT_GOVERNANCE_UPSTREAM='<your-audit-governance-origin>'
  python3 tools/robust_proxy.py`.
  Audit reads require this explicit upstream; if it is unset, the proxy fails
  closed and never falls back to the core Snaplink backend. The proxy inherits
  this environment variable when started directly, through `make serve` or
  `./dev.sh`, and from integration subprocesses. It supplies both SPA fallback
  and the same-origin API proxy. Python's plain
  `http.server` is not suitable for deep-link testing because it returns 404
  instead of `index.html` for unknown routes.

## Notes

- `make build-prod` is required before direct static hosting. Docker builds
  the Flutter artifact itself.
- The `--base-href=/app/` value must match wherever the gateway serves this
  app's static assets from; it's baked into `build/web/index.html`'s
  generated `<base href>` and asset paths at build time.
- `python3 -m unittest discover -s tests/unit -p 'test_*.py'` includes
  structural deployment checks for the image, nginx template, Compose,
  Kubernetes and CI fixture contract.
- `make k8s-render` renders both Kubernetes profiles locally without contacting
  a cluster and is required by CI.
- The Kubernetes example starts three replicas, rolls with zero unavailable
  pods, spreads across zones/nodes where possible, protects two replicas with
  a disruption budget, and scales from three to ten replicas when a metrics
  server is available. Remove the HPA only when another autoscaler owns the
  Deployment.
