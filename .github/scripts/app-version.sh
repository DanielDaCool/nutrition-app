#!/usr/bin/env bash
# Reads the app version from pubspec.yaml and exports it as APP_VERSION
# (e.g. "0.0.0+2") for the build's --dart-define. On a release tag, also
# checks the tag names the same version, so v0.1 can't ship a build that
# still says 0.0.0. Tags may drop trailing zeros: v0.0 matches 0.0.0.
set -euo pipefail

full=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '\r')
name=${full%%+*}
if [ -z "$full" ]; then
  echo "::error::No version: line in pubspec.yaml"
  exit 1
fi
echo "APP_VERSION=$full" >> "$GITHUB_ENV"
echo "App version $full"

if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
  tag=${GITHUB_REF_NAME#v}
  IFS=. read -r major minor patch <<< "$tag"
  wanted="${major}.${minor:-0}.${patch:-0}"
  if [ "$wanted" != "$name" ]; then
    echo "::error::Tag $GITHUB_REF_NAME doesn't match pubspec.yaml version $name. Bump the version (and build number) in pubspec.yaml, merge, then tag that commit."
    exit 1
  fi
fi
