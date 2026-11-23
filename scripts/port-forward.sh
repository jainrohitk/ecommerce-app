#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export MSYS_NO_PATHCONV=1
usage() {
  echo "Usage: bash scripts/port-forward.sh [storefront|grafana|prometheus|tempo] [local-port]"
  echo "Defaults: storefront 8080, grafana 3000, prometheus 9090, tempo 3200"
}
[[ $# -le 2 ]] || { usage >&2; exit 1; }
case "${1:-storefront}" in
  storefront) SERVICE=frontend-proxy; REMOTE_PORT=8080 ;;
  grafana) SERVICE=grafana; REMOTE_PORT=3000 ;;
  prometheus) SERVICE=prometheus; REMOTE_PORT=9090 ;;
  tempo) SERVICE=tempo; REMOTE_PORT=3200 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unsupported service: $1" >&2; usage >&2; exit 1 ;;
esac
LOCAL_PORT="${2-$REMOTE_PORT}"
[[ "$LOCAL_PORT" =~ ^[1-9][0-9]{0,4}$ ]] && (( LOCAL_PORT <= 65535 )) \
  || { echo "Local port must be an integer from 1 to 65535 (without leading zeros)" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "Missing prerequisite: kubectl" >&2; exit 1; }
[[ -f .local/kubeconfig ]] || { echo "Install the dedicated lab first: bash scripts/install.sh" >&2; exit 1; }
export KUBECONFIG="$ROOT/.local/kubeconfig"
if command -v cygpath >/dev/null; then KUBECONFIG="$(cygpath -m "$KUBECONFIG")"; export KUBECONFIG; fi
echo "Local URL (once forwarding starts): http://127.0.0.1:$LOCAL_PORT"
echo "Keep this terminal open; press Ctrl+C to stop. If a pod restarts, rerun this script."
exec kubectl --context kind-ecomm-lab -n ecomm-lab port-forward \
  --address 127.0.0.1 "service/$SERVICE" "$LOCAL_PORT:$REMOTE_PORT"
