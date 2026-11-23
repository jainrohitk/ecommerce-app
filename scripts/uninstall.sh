#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != "--confirm" ]]; then
  echo "This deletes only the ecomm-lab kind cluster and its cluster-local data. Run: bash scripts/uninstall.sh --confirm" >&2
  exit 1
fi
kind delete cluster --name ecomm-lab
echo "Deleted ecomm-lab. Local generated credentials were retained; no other clusters were changed."
