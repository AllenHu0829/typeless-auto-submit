#!/bin/bash
# Build and sign dictation-auto-submit
# Usage: bash ~/.claude/hooks/build-dictation.sh

set -e

SRC="$HOME/.claude/hooks/dictation-auto-submit.swift"
APP="$HOME/Applications/DictationAutoSubmit.app"
BIN="$APP/Contents/MacOS/DictationAutoSubmit"
BUNDLE_ID="com.allenhu.dictation-auto-submit"

echo "==> Compiling..."
swiftc -o "$BIN" "$SRC" -framework Cocoa -framework IOKit -framework CoreGraphics

echo "==> Signing with stable identity..."
codesign --force --sign - --identifier "$BUNDLE_ID" "$BIN"

echo "==> Verifying..."
codesign -dvv "$BIN" 2>&1 | grep -E "Identifier|Signature"

echo "==> Restarting daemon..."
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist 2>/dev/null || true
sleep 1
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.claude.dictation-auto-submit.plist

sleep 2
if launchctl list | grep -q dictation-auto-submit; then
    echo "==> Done! Daemon running."
    tail -3 /tmp/dictation-auto-submit.log
else
    echo "==> ERROR: Daemon failed to start"
    tail -5 /tmp/dictation-auto-submit.log
fi
