#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_root="$(mktemp -d)"
fixture_pid=""
cleanup() {
    if [[ -n "$fixture_pid" ]]; then
        kill "$fixture_pid" 2>/dev/null || true
        wait "$fixture_pid" 2>/dev/null || true
    fi
    rm -rf "$fixture_root"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
fixture_app="$fixture_root/Shelf Fixture.app"
mkdir -p "$fixture_app/Contents/MacOS"
cat > "$fixture_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Fixture</string>
<key>CFBundleIdentifier</key><string>com.vorssaint.shelf-fixture</string>
<key>CFBundleName</key><string>Shelf Fixture</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
swiftc Tests/Fixtures/MenuBarShelfFixture.swift -o "$fixture_app/Contents/MacOS/Fixture"
swiftc Sources/Vorssaint/Services/MenuBarShelf/MenuBarShelfScanner.swift \
    Sources/Vorssaint/Services/MenuBarShelf/MenuBarShelfNativeBridge.swift \
    Tests/Fixtures/MenuBarShelfSmoke.swift -o "$fixture_root/MenuBarShelfSmoke"
"$fixture_app/Contents/MacOS/Fixture" > "$fixture_root/fixture.log" 2>&1 &
fixture_pid=$!
"$fixture_root/MenuBarShelfSmoke" "$fixture_pid"
