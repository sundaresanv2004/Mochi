#!/usr/bin/env bash
# Builds a double-clickable Mochi.app into ./dist (menu-bar app, no Dock icon).
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/Mochi.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Mochi"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Mochi"
cp Support/Info.plist "$APP/Contents/Info.plist"

# VERSION=1.2.3 ./scripts/build-app.sh overrides the version in Support/Info.plist.
if [[ -n "${VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
fi

# Google Calendar sign-in: GOOGLE_CLIENT_ID=… GOOGLE_CLIENT_SECRET=… ./scripts/build-app.sh puts your OAuth
# client ("Desktop app" type) into the built app only, never into Support/Info.plist, so it stays out of git.
# Without it, the app asks people to paste their own client in Settings › Reminders.
if [[ -n "${GOOGLE_CLIENT_ID:-}" ]]; then
    plutil -replace GoogleClientID -string "$GOOGLE_CLIENT_ID" "$APP/Contents/Info.plist"
    if [[ -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
        plutil -replace GoogleClientSecret -string "$GOOGLE_CLIENT_SECRET" "$APP/Contents/Info.plist"
    else
        echo "warning: GOOGLE_CLIENT_SECRET is not set; Google usually needs it for Desktop app clients"
    fi
    echo "Google Calendar: using the OAuth client from GOOGLE_CLIENT_ID"
else
    [[ -n "${GOOGLE_CLIENT_SECRET:-}" ]] && echo "warning: GOOGLE_CLIENT_SECRET is set but GOOGLE_CLIENT_ID isn't; ignoring it"
    echo "Google Calendar: GOOGLE_CLIENT_ID not set, so people will paste their own OAuth client in Settings"
fi

# Ad-hoc sign so it launches without "damaged app" errors on the machine that built it.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed (app may need to be allowed manually)"

echo "Built $APP"
