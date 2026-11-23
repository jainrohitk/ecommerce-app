#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export MSYS_NO_PATHCONV=1
CLUSTER=ecomm-lab
for tool in docker kind kubectl curl openssl; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
docker info >/dev/null
MEMORY="$(docker info --format '{{.MemTotal}}')"
if (( MEMORY < 4000000000 )); then
  echo "Allocate at least 4 GB to Docker before installing this single-node lab. Existing clusters are untouched." >&2
  exit 1
fi
mkdir -p .local
chmod 700 .local
export KUBECONFIG="$ROOT/.local/kubeconfig"
if command -v cygpath >/dev/null; then KUBECONFIG="$(cygpath -m "$KUBECONFIG")"; export KUBECONFIG; fi
trap 'echo "Installation failed. Inspect the dedicated lab using KUBECONFIG=.local/kubeconfig kubectl get pods -A" >&2' ERR
if [[ ! -f .local/prebuilt.env ]]; then
  umask 077
  POSTGRES_PASSWORD="$(openssl rand -hex 24)"
  CATALOG_PASSWORD="$(openssl rand -hex 24)"
  REDIS_PASSWORD="$(openssl rand -hex 24)"
  GRAFANA_PASSWORD="$(openssl rand -hex 24)"
  cat > .local/prebuilt.env <<EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
CATALOG_PASSWORD=$CATALOG_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
DB_CONNECTION_STRING=postgres://catalog_reader:$CATALOG_PASSWORD@postgres:5432/astronomy_db?sslmode=disable&connect_timeout=5
EOF
fi
chmod 600 .local/prebuilt.env
# Credentials are generated here, never taken from an untrusted shell script.
REDIS_PASSWORD="$(sed -n 's/^REDIS_PASSWORD=//p' .local/prebuilt.env)"
[[ "$REDIS_PASSWORD" =~ ^[a-f0-9]{48}$ ]] || { echo "Invalid saved Redis credential" >&2; exit 1; }
printf 'requirepass %s\n' "$REDIS_PASSWORD" > .local/redis.conf
chmod 600 .local/redis.conf
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --image kindest/node:v1.36.1 --config cluster/kind.yaml --kubeconfig "$KUBECONFIG"
else
  kind export kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG"
fi
if ! kubectl --context "kind-$CLUSTER" -n kube-system get daemonset calico-node >/dev/null 2>&1; then
  curl --fail --location --retry 3 https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml -o .local/calico.yaml
  kubectl --context "kind-$CLUSTER" apply -f .local/calico.yaml
fi
kubectl --context "kind-$CLUSTER" -n kube-system rollout status daemonset/calico-node --timeout=300s
kubectl --context "kind-$CLUSTER" wait --for=condition=Ready nodes --all --timeout=300s
kubectl --context "kind-$CLUSTER" apply -f kubernetes/namespace.yaml
kubectl --context "kind-$CLUSTER" -n ecomm-lab create secret generic lab-secrets \
  --from-env-file=.local/prebuilt.env --dry-run=client -o yaml | kubectl --context "kind-$CLUSTER" apply -f -
kubectl --context "kind-$CLUSTER" -n ecomm-lab create secret generic redis-config \
  --from-file=redis.conf=.local/redis.conf --dry-run=client -o yaml | kubectl --context "kind-$CLUSTER" apply -f -
kubectl --context "kind-$CLUSTER" apply -k kubernetes
for service in postgres redis flagd otel-collector tempo prometheus grafana product-catalog cart currency payment email quote shipping recommendation ad image-provider frontend frontend-proxy; do
  kubectl --context "kind-$CLUSTER" -n ecomm-lab rollout status "deployment/$service" --timeout=900s
done
kubectl --context "kind-$CLUSTER" -n ecomm-lab rollout status deployment/checkout --timeout=900s
curl --fail --retry 5 --retry-connrefused http://127.0.0.1:18080/ -o /dev/null
curl --fail --retry 5 --retry-connrefused http://127.0.0.1:13000/api/health
echo
echo "Storefront: http://127.0.0.1:18080 | Grafana: http://127.0.0.1:13000"
echo "Grafana admin password is in ignored .local/prebuilt.env. No images were built."
