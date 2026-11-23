#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export MSYS_NO_PATHCONV=1
export KUBECONFIG="$ROOT/.local/kubeconfig"
if command -v cygpath >/dev/null; then KUBECONFIG="$(cygpath -m "$KUBECONFIG")"; export KUBECONFIG; fi
SECONDS_REQUESTED="${1:-600}"
USERS="${2:-10}"
[[ "$SECONDS_REQUESTED" =~ ^[1-9][0-9]*$ && "$USERS" =~ ^[1-9][0-9]*$ ]] || { echo "Duration and users must be positive integers" >&2; exit 1; }
(( SECONDS_REQUESTED <= 600 && USERS <= 10 )) || { echo "Maximum duration 600 seconds; maximum users 10" >&2; exit 1; }
[[ -f .local/kubeconfig ]] || { echo "Install the dedicated lab first" >&2; exit 1; }
APP_CONFIG="$(kubectl --context kind-ecomm-lab -n ecomm-lab get deployment frontend -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}')"
[[ "$APP_CONFIG" == app-env-* ]] || { echo "Cannot identify the installed app configuration" >&2; exit 1; }
JOB="$(sed -e "s/--users=[0-9][0-9]*/--users=$USERS/" -e "s/--run-time=[0-9][0-9]*s/--run-time=${SECONDS_REQUESTED}s/" \
  -e "s/name: app-env/name: $APP_CONFIG/" kubernetes/load-generator/job.yaml \
  | kubectl --context kind-ecomm-lab create -f - -o jsonpath='{.metadata.name}')"
echo "Traffic job: $JOB"
kubectl --context kind-ecomm-lab -n ecomm-lab wait --for=condition=Ready pod -l "job-name=$JOB" --timeout=180s
kubectl --context kind-ecomm-lab -n ecomm-lab logs -f "job/$JOB"
kubectl --context kind-ecomm-lab -n ecomm-lab wait --for=condition=Complete "job/$JOB" --timeout=90s
