#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [1/4] Generating Xcode project with XcodeGen..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> [2/4] Building Release binary with xcodebuild..."
xcodebuild -project suqi.xcodeproj -scheme suqi -configuration Release -destination 'platform=macOS' build > /tmp/suqi_build.log 2>&1 || {
    echo "❌ Build failed! Log output:"
    tail -n 40 /tmp/suqi_build.log
    exit 1
}

# Locate built app (newest wins: stale DerivedData dirs may also hold a build)
BUILT_APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/suqi-*/Build/Products/Release/suqi.app 2>/dev/null | head -n 1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    echo "❌ Error: Could not find built suqi.app in DerivedData!"
    exit 1
fi

echo "==> [3/4] Installing suqi.app to /Applications..."
if pgrep -x "suqi" > /dev/null 2>&1; then
    echo "    Stopping running suqi instance..."
    pkill -x "suqi" || true
    sleep 0.5
fi

rm -rf /Applications/suqi.app
cp -R "$BUILT_APP" /Applications/suqi.app

# xcodebuild registers its DerivedData output with LaunchServices, so Spotlight
# shows a second "suqi" next to the installed one. Drop that registration.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true

# Do NOT re-sign here: xcodebuild already signed with the stable Apple Development
# certificate, and re-signing changes the CDHash, which silently invalidates every
# TCC permission (Accessibility, Screen Capture, Full Disk Access) on each install.
echo "==> [4/4] Verifying signature..."
codesign -vvv /Applications/suqi.app 2>&1
codesign -d -r- /Applications/suqi.app 2>&1

echo ""
echo "🎉 suqi successfully built, signed, and installed to /Applications/suqi.app!"
