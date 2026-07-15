# Deploying sso-console

This is a single static Flutter web bundle that serves five different areas
of the SSO product (`/admin/`, `/login/`, `/setup/`, `/portal/`,
`/developer/`) — `lib/app_router.dart`'s `resolveInitialScreen()` picks which
screen to show based on the URL path the browser actually loaded. The app
itself doesn't care which prefix it was reached through; **an upstream
gateway is expected to route** `/admin/`, `/login/`, `/portal/`,
`/developer/`, `/setup/`, and `/app/` (the static-asset prefix baked in via
`--base-href=/app/`) to wherever this app's root (`/`) ends up listening.
Wiring that gateway routing is out of scope for this document.

Every method below starts with the same build step, since Flutter is not
built inside Docker here (see note in the Kubernetes/Docker sections):

```bash
flutter build web --release --base-href=/app/
```

This produces `build/web/` — a plain directory of static files (HTML/JS/CSS/
assets) that any of the three methods below can serve.

Pick **one** of the following:

## Method 1: Kubernetes

Matches how `sso-server` is already deployed in this environment: images are
built locally, then loaded directly into the single node's containerd (there
is no image registry in this cluster).

```bash
flutter build web --release --base-href=/app/
docker build -t snaplink/sso-console:v1 .

# Transfer the image into the node's containerd (replace <node> with the
# node's SSH host), matching the sso-server deployment process:
docker save snaplink/sso-console:v1 | ssh <node> ctr -n k8s.io images import -

kubectl apply -f k8s/
```

`k8s/deployment.yaml` deploys into the `sv-sso` namespace (same namespace as
`sso-server`, so this console could in principle reach it over in-cluster DNS
at `sso-server.sv-sso.svc.cluster.local:8080` if it's ever wired to call the
API directly), runs as non-root (UID 65532) with a read-only root filesystem,
and pins to node `u1-faex9` — the only node in this cluster.
`imagePullPolicy: Never` is required since there is no registry to pull from.

## Method 2: Docker (standalone)

For any environment that runs plain Docker without Kubernetes:

```bash
flutter build web --release --base-href=/app/
docker build -t sso-console:latest .
docker run -d --name sso-console -p 8080:80 sso-console:latest
```

The console is now reachable on `http://localhost:8080/`. Point any reverse
proxy (nginx, Caddy, Traefik, etc.) at that port, routing the five path
prefixes above to it.

## Method 3: Manual / direct static hosting (no container)

This is the baseline, no-Docker option — and it's exactly how sso-console is
deployed in the live environment today: an OpenResty `alias` directive
pointing straight at the built directory, no container involved.

```bash
flutter build web --release --base-href=/app/
```

Then serve the resulting `build/web/` directory with **any** static file
server capable of an SPA fallback (unknown paths resolve to `index.html`
rather than 404, since `resolveInitialScreen()` picks the screen client-side).
For example:

- **OpenResty / nginx**: an `alias /path/to/build/web;` location block plus
  `try_files $uri $uri/ /index.html;` (see `nginx.conf` in this repo for a
  minimal standalone example of the same fallback).
- **Caddy**: `file_server` with `try_files {path} /index.html`.
- **Python** (quick local testing only, not for production):
  `python3 -m http.server --directory build/web 8080`.

## Notes

- `flutter build web --release --base-href=/app/` MUST be run before any of
  the above — none of these methods build Flutter for you.
- The `--base-href=/app/` value must match wherever the gateway serves this
  app's static assets from; it's baked into `build/web/index.html`'s
  generated `<base href>` and asset paths at build time.
