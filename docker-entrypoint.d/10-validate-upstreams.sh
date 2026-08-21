#!/bin/sh

# Every product service origin must be explicit. An empty optional value used
# to let nginx render a misleading checkout route against the core Snaplink
# service, while an invalid core value could make the container fail later
# during template rendering. Validate only the origin shape; TLS trust and
# certificate names remain the responsibility of the corresponding
# SNAPLINK_*_CA/SERVER_NAME pair.
set -eu

validate_origin() {
  variable="$1"
  value="$(printenv "$variable" 2>/dev/null || true)"

  case "$value" in
    http://*|https://*) ;;
    *)
      echo "[snaplink-console] $variable must be an explicit http:// or https:// origin" >&2
      exit 1
      ;;
  esac

  authority="${value#*://}"
  case "$authority" in
    ""|*/\*|*/*|*\?*|*\#*|*@*|*' '*|*'	'*)
      echo "[snaplink-console] $variable must contain a host-only origin without credentials, path, query, or fragment" >&2
      exit 1
      ;;
  esac
}

validate_origin SNAPLINK_UPSTREAM
validate_origin SNAPLINK_BILLING_UPSTREAM
validate_origin SNAPLINK_STRIPE_ADAPTER_UPSTREAM

echo "[snaplink-console] optional upstream contract validated"
