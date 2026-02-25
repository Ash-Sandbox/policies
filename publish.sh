#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

REGISTRY="https://hub.ashell.dev"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--registry <REGISTRY_URL>]" >&2
      exit 1
      ;;
  esac
done

for dir in */; do
  policy="$dir/policy.yml"
  [ -f "$policy" ] || continue

  # Extract name and version from local policy
  name=$(awk '/^publish:/{found=1} found && /name:/{print $2; exit}' "$policy")
  local_version=$(awk '/^publish:/{found=1} found && /version:/{print $2; exit}' "$policy")

  # Skip directories without a publish section
  [ -z "$name" ] && continue

  echo "==> $name@$local_version"

  # Build --readme flag if README exists
  if [ -f "$dir/README.md" ]; then
    readme_args=(--readme "$dir/README.md")
  else
    readme_args=()
  fi

  # Check if policy exists in registry
  if ! info_output=$(ash info --registry "$REGISTRY" "$name" 2>&1); then
    echo "  Not published yet, publishing..."
    ash publish --registry "$REGISTRY" --policy "$policy" ${readme_args[@]+"${readme_args[@]}"}
    echo ""
    continue
  fi

  # Parse published version (e.g. "ash/base-macos v0.0.2" -> "0.0.2")
  published_version=$(echo "$info_output" | head -1 | awk '{print $2}' | sed 's/^v//')

  if [ "$local_version" = "$published_version" ]; then
    # Same version — compare extracted bundle contents to detect changes
    download_url="$REGISTRY/api/v1/policies/$name/$published_version/download"
    published_bundle=$(mktemp)
    if ! curl -sf "$download_url" -o "$published_bundle"; then
      echo "  WARNING: Failed to download published policy, skipping comparison"
      rm -f "$published_bundle"
      echo ""
      continue
    fi

    # Extract and compare only policy content files (bundles may also
    # contain a SIGNATURE file added by the registry on publish)
    published_dir=$(mktemp -d)
    local_dir=$(mktemp -d)
    tar xzf "$published_bundle" -C "$published_dir"
    rm -f "$published_bundle"

    dry_run_output=$(ash publish --registry "$REGISTRY" --policy "$policy" ${readme_args[@]+"${readme_args[@]}"} --dry-run 2>&1)
    local_bundle=$(echo "$dry_run_output" | awk '/Bundle:/{print $2}')
    tar xzf "$local_bundle" -C "$local_dir"

    # Compare only the files present in the local bundle
    changed=false
    for f in "$local_dir"/*; do
      fname=$(basename "$f")
      if ! diff -q "$f" "$published_dir/$fname" > /dev/null 2>&1; then
        changed=true
        break
      fi
    done
    rm -rf "$published_dir" "$local_dir"

    if [ "$changed" = false ]; then
      echo "  Up to date"
      echo ""
      continue
    fi

    echo "  WARNING: Policy has changed but version is still $local_version — bump the version to publish"
    echo ""
    continue
  fi

  echo "  Publishing $local_version (was $published_version)..."
  ash publish --registry "$REGISTRY" --policy "$policy" ${readme_args[@]+"${readme_args[@]}"}
  echo ""
done
