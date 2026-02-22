#!/bin/bash
# deploy.sh — Build and install Alarm.app on device or simulator.
#
# NOTE: This script does NOT run xcodegen.
# Run `xcodegen generate` manually whenever you change project.yml
# (new frameworks, Info.plist keys, etc.). Source file additions don't need it.
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/Alarm.xcodeproj"
SCHEME="Alarm"
BUNDLE_ID="com.example.Alarm"
DERIVED_DATA="/tmp/AlarmBuild"

# Point to Xcode 26.2 (non-standard path)
export DEVELOPER_DIR=/Applications/Xcode-26.2.0.app/Contents/Developer
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"

# ── 1. Detect target ──────────────────────────────────────────────────────────
USE_SIMULATOR=false

# xcodebuild needs the ECID from xctrace (e.g. 00008120-000C45EE1E69A01E)
# devicectl install needs the UUID from devicectl  (e.g. AC84334B-7FB1-5274-...)
XCODE_DEVICE_ID=""
DEVICECTL_ID=""
DEVICE_NAME=""

for _retry in $(seq 1 15); do
    # xctrace format: "Yuming's iPhone (26.3) (00008120-000C45EE1E69A01E)"
    XCTRACE_LINE=$(xcrun xctrace list devices 2>/dev/null \
        | sed '/== Simulators ==/q' \
        | grep -v "==" \
        | grep "iPhone" \
        | head -1 || true)
    [[ -n "$XCTRACE_LINE" ]] && break
    [[ $_retry -eq 1 ]] && printf "  Waiting for device"
    printf "."
    sleep 1
done
[[ -n "${XCTRACE_LINE:-}" ]] || echo ""

if [[ -n "${XCTRACE_LINE:-}" ]]; then
    # Extract last parenthesised group → ECID for xcodebuild
    XCODE_DEVICE_ID=$(echo "$XCTRACE_LINE" \
        | grep -oE '\([0-9A-Fa-f-]+\)' | tail -1 | tr -d '()')
    DEVICE_NAME=$(echo "$XCTRACE_LINE" | sed 's/ (.*//')

    # Also get the devicectl UUID (for 'devicectl device install')
    DEVICECTL_ID=$(xcrun devicectl list devices 2>/dev/null \
        | grep "connected" \
        | grep -oiE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
        | head -1 || true)

    echo "▶ Target: iPhone — $DEVICE_NAME (xcodebuild: $XCODE_DEVICE_ID)"
else
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

# ── 2. Build ──────────────────────────────────────────────────────────────────
echo "▶ Building..."

if [[ "$USE_SIMULATOR" == "true" ]]; then
    "$XCODEBUILD" build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -derivedDataPath "$DERIVED_DATA" \
        -quiet

    APP_PATH=$(find "$DERIVED_DATA/Build/Products" -name "Alarm.app" \
        -not -path "*/AlarmUITests*" 2>/dev/null | head -1)
    echo "▶ Installing on simulator..."
    xcrun simctl install "$SIM_ID" "$APP_PATH"
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
    echo "✓ Alarm.app launched on $SIM_NAME!"

else
    # ── Real device signing strategy ──────────────────────────────────────────
    # Xcode 26 stores auth tokens in a way xcodebuild CLI can't access directly.
    # Strategy:
    #   1. If a local provisioning profile for com.example.Alarm already exists
    #      (created by a prior Xcode GUI build), use it with Manual signing.
    #   2. Otherwise, fall back to -allowProvisioningUpdates and show guidance.

    PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
    PROFILE_UUID=""

    # Find the Xcode-managed profile for our bundle ID
    for pf in "$PROFILES_DIR"/*.mobileprovision; do
        [[ -f "$pf" ]] || continue
        content=$(security cms -D -i "$pf" 2>/dev/null) || continue
        if echo "$content" | grep -q "com.example.Alarm"; then
            if echo "$content" | grep -q "HKK65P5735"; then
                PROFILE_UUID=$(echo "$content" | plutil -extract UUID raw - 2>/dev/null || true)
                [[ -n "$PROFILE_UUID" ]] && break
            fi
        fi
    done

    BUILD_LOG=$(mktemp /tmp/alarm-build-XXXXXX.log)
    set +e

    if [[ -n "$PROFILE_UUID" ]]; then
        echo "  (Using cached profile: $PROFILE_UUID)"
        "$XCODEBUILD" build \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination "id=$XCODE_DEVICE_ID" \
            -derivedDataPath "$DERIVED_DATA" \
            DEVELOPMENT_TEAM=HKK65P5735 \
            CODE_SIGN_STYLE=Manual \
            PROVISIONING_PROFILE="$PROFILE_UUID" \
            -quiet 2>&1 | tee "$BUILD_LOG"
    else
        "$XCODEBUILD" build \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination "id=$XCODE_DEVICE_ID" \
            -derivedDataPath "$DERIVED_DATA" \
            -allowProvisioningUpdates \
            -allowProvisioningDeviceRegistration \
            DEVELOPMENT_TEAM=HKK65P5735 \
            CODE_SIGN_STYLE=Automatic \
            -quiet 2>&1 | tee "$BUILD_LOG"
    fi

    BUILD_EXIT=${PIPESTATUS[0]}
    set -e

    if [[ $BUILD_EXIT -ne 0 ]]; then
        if grep -q "No Accounts\|No profiles" "$BUILD_LOG" 2>/dev/null; then
            echo ""
            echo "✗ 需要先从 Xcode GUI 构建一次（只需一次，之后全自动）："
            echo ""
            echo "  1. Xcode 已打开，选择顶部设备栏中的 'Yuming's iPhone'"
            echo "  2. 打开 Signing & Capabilities，Team 选 'Personal Team'"
            echo "  3. 按 ⌘R（Run）安装到手机"
            echo "  4. 手机上：设置 → 通用 → VPN与设备管理 → 信任 yumingxie46@gmail.com"
            echo "  5. 之后运行 ./deploy.sh 即可全自动 deploy"
            echo ""
            open -a "/Applications/Xcode-26.2.0.app" /Users/yaxinli/xym/Alarm/Alarm.xcodeproj 2>/dev/null || true
        else
            grep "error:" "$BUILD_LOG" 2>/dev/null | head -10 || true
        fi
        rm -f "$BUILD_LOG"
        exit 1
    fi
    rm -f "$BUILD_LOG"

    APP_PATH=$(find "$DERIVED_DATA/Build/Products/Debug-iphoneos" -maxdepth 1 \
        -name "Alarm.app" 2>/dev/null | head -1)

    if [[ -z "$APP_PATH" ]]; then
        echo "✗ Could not find Alarm.app after build"
        exit 1
    fi

    echo "▶ Installing on $DEVICE_NAME..."
    xcrun devicectl device install app \
        --device "$DEVICECTL_ID" \
        "$APP_PATH"

    echo "▶ Launching..."
    xcrun devicectl device process launch \
        --device "$DEVICECTL_ID" \
        "$BUNDLE_ID" 2>/dev/null || true

    echo "✓ Alarm.app installed and launched on $DEVICE_NAME!"
fi
