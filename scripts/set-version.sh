#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Usage: scripts/set-version.sh 1.1" >&2
  exit 1
fi

if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
  tag="v${version}.0"
else
  tag="v${version}"
fi

plist="$root/Info.plist"
current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || echo 1)"
build=$((current_build + 1))
url="https://github.com/rept0rix/show-sound/releases/download/${tag}/Show-Sound-${version}.dmg"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$plist"

printf '%s\n%s\n' "$version" "$build" > "$root/VERSION"

echo "Updated Show Sound to version $version (build $build)"
