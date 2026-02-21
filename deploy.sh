#!/bin/bash
# deploy.sh — Build and install Alarm.app
#   Prefers connected iPhone; falls back to iOS Simulator automatically.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/Alarm.xcodeproj"

# ── 1. Regenerate Xcode project ──────────────────────────────────────────────
echo "▶ xcodegen..."
xcodegen generate --project "$PROJECT_DIR" --quiet

# ── 2. Detect target: real device or simulator ───────────────────────────────
USE_SIMULATOR=false
DEVICE_ID=""
DEVICE_NAME=""

# Retry up to 15s to handle transient connection flicker
DEVICE_LINE=""
for _retry in $(seq 1 15); do
    DEVICE_LINE=$(xcrun devicectl list devices 2>/dev/null | grep "connected" || true)
    [[ -n "$DEVICE_LINE" ]] && break
    [[ $_retry -eq 1 ]] && printf "  Waiting for device connection"
    printf "."
    sleep 1
done
[[ -n "$DEVICE_LINE" ]] || echo ""  # newline after dots if fell through

if [[ -n "$DEVICE_LINE" ]]; then
    # Extract UUID identifier (robust against spaces in device name)
    DEVICE_ID=$(echo "$DEVICE_LINE" \
        | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
        | head -1)
    DEVICE_NAME=$(echo "$DEVICE_LINE" | awk '{print $1, $2}' | sed 's/[[:space:]]*$//')
    echo "▶ Target: iPhone — $DEVICE_NAME ($DEVICE_ID)"
else
    # Fall back to simulator
    USE_SIMULATOR=true
    SIM_ID=$(xcrun simctl list devices booted --json 2>/dev/null \
        | python3 -c "
import json,sys
d=json.load(sys.stdin)
devs=[dev for devs in d['devices'].values() for dev in devs if dev['state']=='Booted']
print(devs[0]['udid'] if devs else '')
" 2>/dev/null || true)

    if [[ -z "$SIM_ID" ]]; then
        SIM_ID=$(xcrun simctl list devices available --json 2>/dev/null \
            | python3 -c "
import json,sys
d=json.load(sys.stdin)
devs=[dev for devs in d['devices'].values() for dev in devs
      if 'iPhone' in dev.get('name','') and dev['isAvailable']]
devs.sort(key=lambda x: x['name'], reverse=True)
print(devs[0]['udid'] if devs else '')
" 2>/dev/null || true)
        echo "▶ Booting simulator..."
        xcrun simctl boot "$SIM_ID" 2>/dev/null || true
        open -a Simulator 2>/dev/null || true
        sleep 4
    fi

    SIM_NAME=$(xcrun simctl list devices --json 2>/dev/null \
        | python3 -c "
import json,sys
d=json.load(sys.stdin)
for devs in d['devices'].values():
    for dev in devs:
        if dev['udid']=='$SIM_ID':
            print(dev['name']); exit()
" 2>/dev/null || echo "Simulator")
    echo "▶ Target: Simulator — $SIM_NAME ($SIM_ID)"
fi

# ── 3. Build ──────────────────────────────────────────────────────────────────
echo "▶ Building..."

if [[ "$USE_SIMULATOR" == "true" ]]; then
    xcodebuild build \
        -project "$PROJECT" \
        -scheme Alarm \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -derivedDataPath /tmp/AlarmBuild \
        -quiet \
        2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | grep -v "^    " || true

    APP_PATH=$(find /tmp/AlarmBuild/Build/Products -name "Alarm.app" \
        -not -path "*/AlarmUITests*" 2>/dev/null | head -1)
    echo "▶ Installing on simulator..."
    xcrun simctl install "$SIM_ID" "$APP_PATH"
    xcrun simctl launch "$SIM_ID" com.example.Alarm
    echo "✓ Alarm.app launched on $SIM_NAME!"

else
    # Real device — Xcode handles signing
    # Step 1: uninstall old version so we can reliably detect when new one arrives
    echo "▶ Uninstalling old version from device..."
    xcrun devicectl device uninstall app \
        --device "$DEVICE_ID" com.example.Alarm 2>/dev/null || true

    # Step 2: open project in Xcode (brings window to front)
    open -a Xcode "$PROJECT"
    sleep 2

    # Step 3: prompt — Xcode destination can't be set from command line
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Xcode is open. Please:"
    echo "  1. Select '$DEVICE_NAME' in the destination picker"
    echo "  2. Press ▶  (⌘R) to build & install"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "▶ Waiting for install to complete (up to 5 min)..."

    for i in $(seq 1 150); do
        sleep 2
        if xcrun devicectl device info apps \
            --device "$DEVICE_ID" 2>/dev/null \
            | grep -q "com.example.Alarm"; then
            echo "✓ Alarm.app installed on $DEVICE_NAME!"
            xcrun devicectl device process launch \
                --device "$DEVICE_ID" com.example.Alarm 2>/dev/null || true
            echo "✓ App launched!"
            exit 0
        fi
        if (( i % 10 == 0 )); then
            printf "  Waiting... (%ds)\n" $((i * 2))
        fi
    done

    echo "⚠ Timed out after 5 min. Did you press ▶ in Xcode?"
    exit 1
fi
