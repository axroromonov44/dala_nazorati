#!/usr/bin/env bash
# Increments the build number in pubspec.yaml by one.
#
# The build number is what the stores order releases by, and both Play and
# App Store reject an upload whose number is not higher than the last one.
# Deriving it from a CI counter was tempting, but that counter starts at 1
# while this project is already at +18 — every such build would be rejected.
# Keeping the number in pubspec.yaml means the repository always states the
# truth about what was shipped.
#
# Usage:
#   tool/bump_build.sh            # 1.0.0+18 -> 1.0.0+19
#   tool/bump_build.sh 1.1.0      # 1.0.0+18 -> 1.1.0+19
set -euo pipefail

cd "$(dirname "$0")/.."

current=$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//')
name=${current%%+*}
build=${current##*+}

if [[ "$build" == "$current" ]]; then
  echo "pubspec.yaml version has no build number: $current" >&2
  exit 1
fi

new_name=${1:-$name}
new_build=$((build + 1))
new_version="${new_name}+${new_build}"

# A literal -i '' is macOS sed; GNU sed wants -i with no argument.
if sed --version >/dev/null 2>&1; then
  sed -i "s/^version:.*/version: ${new_version}/" pubspec.yaml
else
  sed -i '' "s/^version:.*/version: ${new_version}/" pubspec.yaml
fi

echo "${current} -> ${new_version}"
echo "${new_version}"  > /dev/null
