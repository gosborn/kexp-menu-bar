#!/bin/bash
# Builds KEXP.app into ./build.
#   ./build.sh            local build (this Mac's architecture, ad-hoc signed)
#   ./build.sh --install  local build, copied to /Applications
#   ./build.sh --release  universal build, Developer ID signed, notarized -> build/KEXP.zip
#
# --release needs, one time:
#   - a "Developer ID Application" certificate for team $TEAM_ID (Xcode → Settings → Accounts → Manage Certificates)
#   - notary credentials: xcrun notarytool store-credentials kexp-notary --apple-id <apple id> --team-id $TEAM_ID
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID=JY94R4DLYQ
NOTARY_PROFILE=kexp-notary
APP=build/KEXP.app
MODE="${1:-}"

bundle() {  # $1 = path to built executable
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS"
    cp "$1" "$APP/Contents/MacOS/KEXPMenuBar"
    cp Info.plist "$APP/Contents/"
}

if [[ "$MODE" == "--release" ]]; then
    IDENTITY=$(security find-identity -v -p codesigning | grep -o "\"Developer ID Application: .*($TEAM_ID)\"" | head -1 | tr -d '"' || true)
    if [[ -z "$IDENTITY" ]]; then
        echo "No 'Developer ID Application' certificate for team $TEAM_ID in your keychain." >&2
        echo "Create one in Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application." >&2
        exit 1
    fi

    swift build -c release --arch arm64 --arch x86_64
    bundle .build/apple/Products/Release/KEXPMenuBar

    # Hardened runtime + secure timestamp are required for notarization.
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
    codesign --verify --strict --verbose=2 "$APP"

    ZIP=build/KEXP.zip
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

    # Staple the ticket so the app opens without a warning even offline, then re-zip the stapled app.
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    spctl --assess --type execute --verbose "$APP"
    echo "Release ready: $ZIP"
    exit 0
fi

swift build -c release
bundle .build/release/KEXPMenuBar
codesign --force --sign - "$APP"

if [[ "$MODE" == "--install" ]]; then
    rm -rf /Applications/KEXP.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/KEXP.app"
else
    echo "Built $APP"
fi
