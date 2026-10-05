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

# Locate built app
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/suqi-*/Build/Products/Release -name "suqi.app" -type d 2>/dev/null | head -n 1)

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

echo "==> [4/4] Applying stable code signature..."
# Detect available Apple Development signing identity
SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}')

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "    Found Developer Identity: $SIGNING_IDENTITY"
    codesign -s "$SIGNING_IDENTITY" --force --deep /Applications/suqi.app
else
    echo "    No Apple Development certificate found, applying ad-hoc signature with stable identifier..."
    codesign -s - --force --deep /Applications/suqi.app
fi

echo ""
echo "✅ Verification:"
codesign -vvv /Applications/suqi.app 2>&1
codesign -d -r- /Applications/suqi.app 2>&1

echo ""
echo "🎉 suqi successfully built, signed, and installed to /Applications/suqi.app!"
