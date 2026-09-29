#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Show Sound.app"
binary="$app/Contents/MacOS/ShowSound"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/Info.plist" "$app/Contents/Info.plist"
if [[ -f "$root/Resources/AppIcon.icns" ]]; then
  cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
fi

echo "Compiling Show Sound (arm64-apple-macos14.0)..."
swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos14.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework CoreAudio \
  -framework AudioToolbox \
  -framework AVFoundation \
  -framework Accelerate \
  "$root/Sources/"*.swift \
  -o "$binary"

identity="$(security find-identity -p codesigning -v | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)"
if [[ -n "$identity" ]]; then
  codesign --force --sign "$identity" --identifier com.naoryanko.showsound "$app"
else
  codesign --force --sign - "$app"
fi

echo "Successfully built $app"
