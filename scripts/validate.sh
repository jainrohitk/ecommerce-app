#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for file in scripts/install.sh scripts/traffic.sh scripts/uninstall.sh scripts/port-forward.sh kubernetes/postgres/init.sh; do bash -n "$file"; done
kubectl kustomize kubernetes >/dev/null
echo "Bash syntax and Kustomize rendering passed; this does not verify running services."
