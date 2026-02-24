#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for f in */policy.yml; do
  echo "==> $f"
  ash format --policy "$f"
  ash lint --fix --policy "$f"
done
