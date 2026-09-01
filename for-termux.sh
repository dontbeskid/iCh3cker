#!/data/data/com.termux/files/usr/bin/bash

echo "
 _ _____ _   ___     _
|_|     | |_|_  |___| |_ ___ ___
| |   --|   |_  |  _| '_| -_|  _|
|_|_____|_|_|___|___|_,_|___|_|
"

JB_JSON_URL="${JB_JSON_URL:-https://raw.githubusercontent.com/dontbeskid/iCh3cker/refs/heads/main/devices.json}"

check_dependencies() {
    MISSING=""

    if ! command -v ideviceinfo >/dev/null 2>&1; then
        MISSING="$MISSING ideviceinfo"
    fi
    if ! command -v idevicediagnostics >/dev/null 2>&1; then
        MISSING="$MISSING idevicediagnostics"
    fi

    if [ -n "$MISSING" ]; then
        echo "Error: Required tools are missing:$MISSING"
        echo ""
        echo "Install in Termux:"
        echo "  pkg install libimobiledevice"
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "Note: 'jq' not found - jailbreak lookups will use built-in table."
        echo "  pkg install jq"
        echo ""
    fi
}

get_production_date() {
    SERIAL="$1"
    LEN=${#SERIAL}
    if [ "$LEN" -eq 12 ]; then
        YEAR_CODE="${SERIAL:3:1}"
        WEEK_CODE="${SERIAL:4:1}"
        case "$YEAR_CODE" in
            C) YEAR="2010/2020 (H1)";; D) YEAR="2010/2020 (H2)";;
            F) YEAR="2011/2021 (H1)";; G) YEAR="2011/2021 (H2)";;
            H) YEAR="2012/2022 (H1)";; J) YEAR="2012/2022 (H2)";;
            K) YEAR="2013/2023 (H1)";; L) YEAR="2013/2023 (H2)";;
            M) YEAR="2014/2024 (H1)";; N) YEAR="2014/2024 (H2)";;
            P) YEAR="2015/2025 (H1)";; Q) YEAR="2015/2025 (H2)";;
            R) YEAR="2016 (H1)";;       S) YEAR="2016 (H2)";;
            T) YEAR="2017 (H1)";;       V) YEAR="2017 (H2)";;
            W) YEAR="2018 (H1)";;       X) YEAR="2018 (H2)";;
            Y) YEAR="2019 (H1)";;       Z) YEAR="2019 (H2)";;
            *) YEAR="Unknown";;
        esac
        echo "$YEAR (Week code: $WEEK_CODE)"
    else
        echo "N/A (Randomized Serial)"
    fi
}

check_jailbreak_support() {
    VER="$1"
    MAJOR=$(echo "$VER" | cut -d'.' -f1)
    MINOR=$(echo "$VER" | cut -d'.' -f2)

    if [ -z "$MAJOR" ]; then
        echo "Unknown"
        return
    fi

    if [ "$MAJOR" -le 14 ]; then
        echo "Supported (Unc0ver, Taurine, Checkra1n)"
    elif [ "$MAJOR" -eq 15 ]; then
        echo "Supported (Dopamine, Palera1n)"
    elif [ "$MAJOR" -eq 16 ]; then
        echo "Supported (Dopamine 2.0 / Palera1n on checkm8)"
    elif [ "$MAJOR" -eq 17 ]; then
        if [ "$MINOR" -le 0 ]; then
            echo "Partial / Semi-Jailbreak (Bootstrap/Serotonin)"
        else
            echo "Not Supported (No public jailbreak available)"
        fi
    else
        echo "Not Supported"
    fi
}

version_in_range() {
    V="$1" LO="$2" HI="$3"
    [ "$(printf '%s\n%s\n' "$LO" "$V" | sort -V | head -n1)" = "$LO" ] || return 1
    [ "$(printf '%s\n%s\n' "$V" "$HI" | sort -V | head -n1)" = "$V" ] || return 1
    return 0
}

lookup_jailbreak_from_json() {
    MODEL="$1"
    VER="$2"

    command -v jq >/dev/null 2>&1 || return 1
    command -v curl >/dev/null 2>&1 || return 1

    TMP_JSON="$TMPDIR/ich3cker_jb_$$.json"

    if ! curl -fsSL "$JB_JSON_URL" -o "$TMP_JSON" 2>/dev/null; then
        rm -f "$TMP_JSON"
        return 1
    fi

    DEV=$(jq -c --arg id "$MODEL" '.devices[$id] // empty' "$TMP_JSON" 2>/dev/null)

    if [ -z "$DEV" ]; then
        rm -f "$TMP_JSON"
        return 1
    fi

    JB_NAME=$(echo "$DEV" | jq -r '.name // "device"')
    LATEST=$(echo "$DEV" | jq -r '.latest_jailbreakable // empty')
    COUNT=$(echo "$DEV" | jq '.versions | length')

    i=0
    while [ "$i" -lt "$COUNT" ]; do
        FRM=$(echo "$DEV" | jq -r ".versions[$i].from")
        TO=$(echo "$DEV"  | jq -r ".versions[$i].to")
        JB=$(echo "$DEV"  | jq -r ".versions[$i].jailbreak")
        URL=$(echo "$DEV" | jq -r ".versions[$i].url")

        if version_in_range "$VER" "$FRM" "$TO" 2>/dev/null; then
            rm -f "$TMP_JSON"
            if [ "$JB" = "null" ] || [ -z "$JB" ]; then
                echo "Not Supported ($JB_NAME on $VER has no known jailbreak)"
            else
                echo "$JB ($URL)"
            fi
            return 0
        fi
        i=$((i + 1))
    done

    rm -f "$TMP_JSON"
    echo "Unknown for this version ($JB_NAME, latest jailbreakable: ${LATEST:-N/A})"
    return 0
}

get_device_info() {
    echo "iCh3cker | <3 | github.com/dontbeskid"
    echo "Searching for connected iOS device..."
    echo ""

    UDID=$(ideviceinfo -k UniqueDeviceID 2>/dev/null)

    if [ -z "$UDID" ]; then
        echo "Status: No device detected."
        echo "Make sure your iPhone is connected via USB-OTG and you tapped 'Trust' on it."
        exit 1
    fi

    DEV_NAME=$(ideviceinfo -k DeviceName 2>/dev/null)
    DEV_CLASS=$(ideviceinfo -k DeviceClass 2>/dev/null)
    MODEL=$(ideviceinfo -k ProductType 2>/dev/null)
    OS_VER=$(ideviceinfo -k ProductVersion 2>/dev/null)
    BUILD_VER=$(ideviceinfo -k BuildVersion 2>/dev/null)
    MODEL_NUM=$(ideviceinfo -k ModelNumber 2>/dev/null)
    REGION=$(ideviceinfo -k RegionInfo 2>/dev/null)
    SERIAL=$(ideviceinfo -k SerialNumber 2>/dev/null)
    IMEI=$(ideviceinfo -k InternationalMobileEquipmentIdentity 2>/dev/null)
    MEID=$(ideviceinfo -k MobileEquipmentIdentifier 2>/dev/null)
    WIFI_MAC=$(ideviceinfo -k WiFiAddress 2>/dev/null)

    ACTIVATED=$(ideviceinfo -k ActivationState 2>/dev/null)
    FMI=$(ideviceinfo -q com.apple.fmip -k FindMyiPhoneEnabled 2>/dev/null)
    PASS=$(ideviceinfo -k PasswordProtected 2>/dev/null)

    BATT_RAW=$(idevicediagnostics ioregentry AppleSmartBattery 2>/dev/null)
    if [ -z "$BATT_RAW" ]; then
        BATT_RAW=$(idevicediagnostics ioregentry AppleARMPMUCharger 2>/dev/null)
    fi

    CYCLE_COUNT=$(echo "$BATT_RAW" | grep -A 1 "CycleCount"          | grep -oE '[0-9]+' | head -n 1)
    MAX_CAP=$(echo "$BATT_RAW"     | grep -A 1 "AppleRawMaxCapacity"  | grep -oE '[0-9]+' | head -n 1)
    DESIGN_CAP=$(echo "$BATT_RAW" | grep -A 1 "DesignCapacity"       | grep -oE '[0-9]+' | head -n 1)
    BATT_LEVEL=$(ideviceinfo -q com.apple.mobile.battery -k BatteryCurrentCapacity 2>/dev/null)

    BATT_HEALTH="N/A"
    if [ -n "$MAX_CAP" ] && [ -n "$DESIGN_CAP" ] && [ "$DESIGN_CAP" -gt 0 ]; then
        HEALTH_CALC=$(( (MAX_CAP * 100) / DESIGN_CAP ))
        [ "$HEALTH_CALC" -gt 100 ] && HEALTH_CALC=100
        BATT_HEALTH="${HEALTH_CALC}%"
    fi

    PROD_DATE=$(get_production_date "$SERIAL")

    JB_STATUS=$(lookup_jailbreak_from_json "$MODEL" "$OS_VER")
    if [ -n "$JB_STATUS" ]; then
        JB_SOURCE="ios.cfw.guide"
    else
        JB_STATUS=$(check_jailbreak_support "$OS_VER")
        JB_SOURCE="built-in table"
    fi

    echo "-- general"
    echo "Device Name        : ${DEV_NAME:-N/A}"
    echo "Device Class       : ${DEV_CLASS:-N/A}"
    echo "Product Model      : ${MODEL:-N/A}"
    echo "Model Number       : ${MODEL_NUM:-N/A}"
    echo "Region Code        : ${REGION:-N/A}"
    echo "Estimated Prod Date: ${PROD_DATE}"
    echo ""
    echo "-- system"
    echo "iOS/iPadOS Version : ${OS_VER:-N/A} (${BUILD_VER:-N/A})"
    echo "Jailbreak Support  : ${JB_STATUS} [source: ${JB_SOURCE}]"
    echo "Activation State   : ${ACTIVATED:-N/A}"
    echo "Find My iPhone     : ${FMI:-N/A}"
    echo "Passcode Enabled   : ${PASS:-N/A}"
    echo ""
    echo "-- hardware"
    echo "Battery Level      : ${BATT_LEVEL:-N/A}%"
    echo "Battery Health     : ${BATT_HEALTH}"
    echo "Battery Cycles     : ${CYCLE_COUNT:-N/A}"
    echo "Current Capacity   : ${MAX_CAP:-N/A} mAh"
    echo "Design Capacity    : ${DESIGN_CAP:-N/A} mAh"
    echo ""
    echo "-- ident."
    echo "Serial Number      : ${SERIAL:-N/A}"
    echo "UDID               : ${UDID}"
    echo "IMEI               : ${IMEI:-N/A}"
    echo "MEID               : ${MEID:-N/A}"
    echo "Wi-Fi Address      : ${WIFI_MAC:-N/A}"
    echo ""
    echo "github.com/dontbeskid"
}

main() {
    check_dependencies
    get_device_info
}

main
