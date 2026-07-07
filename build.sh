#!/bin/sh
# Builds Sleepless.app into dist/.
set -eu
cd "$(dirname "$0")"

swift build -c release

APP=dist/Sleepless.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Sleepless "$APP/Contents/MacOS/Sleepless"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp helper/sleepless-helper helper/install-helper.sh helper/uninstall-helper.sh "$APP/Contents/Resources/"

# Ad-hoc signature so macOS treats the bundle as a stable identity
# (notifications, login items).
codesign --force --sign - "$APP"

echo "Built $APP"
