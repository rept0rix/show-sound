#!/bin/zsh
# Stamp one marketing version through Info.plist, the app fallback, the README, and the site.
# Usage: scripts/set-version.sh 1.1
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
current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
build=$((current_build + 1))
url="https://github.com/rept0rix/show-sound/releases/download/${tag}/Show-Sound-${version}.dmg"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$plist"

printf '%s\n%s\n' "$version" "$build" > "$root/VERSION"

python3 - "$root" "$version" "$url" <<'PY'
import pathlib, sys
root, version, url = sys.argv[1:]
root = pathlib.Path(root)

swift = root / "Sources/ShowSoundSupport.swift"
text = swift.read_text()
needle = '// showsound-version'
if needle not in text:
    sys.exit("ShowSoundSupport.swift is missing // showsound-version")
lines = []
for line in text.splitlines(keepends=True):
    if needle in line:
        line = line.split("??", 1)[0] + f'?? "{version}" {needle}\n'
    lines.append(line)
swift.write_text("".join(lines))

def between(path: pathlib.Path, start: str, end: str, body: str) -> None:
    text = path.read_text()
    if start not in text or end not in text:
        sys.exit(f"{path} is missing version markers: {start}")
    pre, rest = text.split(start, 1)
    _, post = rest.split(end, 1)
    path.write_text(pre + start + "\n" + body.rstrip() + "\n" + end + post)

between(
    root / "README.md",
    "<!-- showsound:download -->",
    "<!-- /showsound:download -->",
    f"Show Sound is built for macOS 14.0 (Sonoma) or later on Apple Silicon (M1/M2/M3/M4).\nThe official install disk is [Show Sound {version} DMG]({url}). Open it and drag Show Sound into Applications.",
)
between(
    root / "site/index.html",
    "<!-- showsound:download -->",
    "<!-- /showsound:download -->",
    f'        <a href="{url}" class="btn btn-lg btn-primary">\n          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>\n          Download for Mac\n        </a>',
)
PY

echo "version=$version"
echo "build=$build"
echo "tag=$tag"
echo "dmg=Show-Sound-${version}.dmg"
echo "url=$url"
