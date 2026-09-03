#!/bin/bash

clear

echo "██████████████████████████████████████████████████"
echo "██████████████████████████████████████████████████"
echo "██████████████████████████████████████████████████"
echo "██████████████████████████████████████████████████"
echo "██████████████              ██████████████████████"
echo "██████████████  ███      ███  ████████████████████"
echo "██████████████  ████████████  ████████████████████"
echo "██████████████  ████████████  ████████████████████"
echo "██████████████  ████████████  ████████████████████"
echo "██████████████  ████████████  ████████████████████"
echo "██████████████  ████████████  ████████████████████"
echo "██████████████  ████████████  ████████████████████"
echo "██████████████  ████████████  ██    ██████████████"
echo "██████████████  ████████████  ██     █████████████"
echo "██████████████  ████████████  ██     █████████████"
echo "██████████████  ████████████  ██     █████████████"
echo "██████████████  ████████████  ██    ██████████████"
echo "██████████████  ████████████  ███  ███████████████"
echo "███████████████              ████  ███████████████"
echo "████████████████████    █████████  ███████████████"
echo "█████████████████████  █████████   ███████████████"
echo "██████████████████████   █████    ████████████████"
echo "████████████████████████       ███████████████████"
echo "██████████████████████████████████████████████████"
echo "██████████████████████████████████████████████████"
echo "██████████████████████████████████████████████████"
echo "                                 
 _ _____ _   ___     _           
|_|     | |_|_  |___| |_ ___ ___ 
| |   --|   |_  |  _| '_| -_|  _|
|_|_____|_|_|___|___|_,_|___|_|  
                                     
"

JB_JSON_URL="${JB_JSON_URL:-https://raw.githubusercontent.com/dontbeskid/iCh3cker/refs/heads/main/devices.json}"

check_dependencies() {
    local missing=()
    command -v ideviceinfo &>/dev/null || missing+=("ideviceinfo")
    command -v idevicediagnostics &>/dev/null || missing+=("idevicediagnostics")

    if [ ${#missing[@]} -ne 0 ]; then
        echo "Error: Required tools are missing (${missing[*]}):"
        echo "Please install libimobiledevice package:"
        echo "  - macOS: brew install libimobiledevice"
        echo "  - Linux: sudo apt-get install libimobiledevice-utils"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Note: 'jq' not found - jailbreak lookups will fall back to the built-in static table."
        echo "  - macOS: brew install jq"
        echo "  - Linux: sudo apt-get install jq"
        echo ""
    fi
}

get_production_date() {
    local serial="$1"
    local len=${#serial}
    if [ $len -eq 12 ]; then
        local year_code="${serial:3:1}"
        local week_code="${serial:4:1}"

        local year=""
        case "$year_code" in
            C) year="2010/2020 (H1)";; D) year="2010/2020 (H2)";;
            F) year="2011/2021 (H1)";; G) year="2011/2021 (H2)";;
            H) year="2012/2022 (H1)";; J) year="2012/2022 (H2)";;
            K) year="2013/2023 (H1)";; L) year="2013/2023 (H2)";;
            M) year="2014/2024 (H1)";; N) year="2014/2024 (H2)";;
            P) year="2015/2025 (H1)";; Q) year="2015/2025 (H2)";;
            R) year="2016 (H1)";;       S) year="2016 (H2)";;
            T) year="2017 (H1)";;       V) year="2017 (H2)";;
            W) year="2018 (H1)";;       X) year="2018 (H2)";;
            Y) year="2019 (H1)";;       Z) year="2019 (H2)";;
            *) year="Unknown";;
        esac
        echo "$year (Week code: $week_code)"
    else
        echo "N/A (Randomized Serial)"
    fi
}

check_jailbreak_support() {
    local ver="$1"
    local major_ver=$(echo "$ver" | cut -d'.' -f1)
    local minor_ver=$(echo "$ver" | cut -d'.' -f2)

    if [ -z "$major_ver" ]; then
        echo "Unknown"
        return
    fi

    if [ "$major_ver" -le 14 ]; then
        echo "Supported (Unc0ver, Taurine, Checkra1n)"
    elif [ "$major_ver" -eq 15 ]; then
        echo "Supported (Dopamine, Palera1n)"
    elif [ "$major_ver" -eq 16 ]; then
        echo "Supported (Dopamine 2.0 / Palera1n on checkm8)"
    elif [ "$major_ver" -eq 17 ]; then
        if [ "$minor_ver" -le 0 ]; then
            echo "Partial / Semi-Jailbreak (Bootstrap/Serotonin)"
        else
            echo "Not Supported (No public jailbreak available)"
        fi
    else
        echo "Not Supported"
    fi
}

version_in_range() {
    local v="$1" lo="$2" hi="$3"
    [ "$(printf '%s\n%s\n' "$lo" "$v" | sort -V | head -n1)" = "$lo" ] || return 1
    [ "$(printf '%s\n%s\n' "$v" "$hi" | sort -V | head -n1)" = "$v" ] || return 1
    return 0
}

lookup_jailbreak_from_json() {
    local model="$1" ver="$2"

    command -v jq &>/dev/null || return 1
    command -v curl &>/dev/null || return 1

    local tmp_json
    tmp_json=$(mktemp 2>/dev/null || echo "/tmp/ich3cker_jb.json")
    
    # Прямое скачивание свежего JSON
    if ! curl -fsSL "$JB_JSON_URL" -o "$tmp_json" 2>/dev/null; then
        rm -f "$tmp_json"
        return 1
    fi

    # Чтение через структуру .devices[$id]
    local dev
    dev=$(jq -c --arg id "$model" '.devices[$id] // empty' "$tmp_json" 2>/dev/null)
    
    if [ -z "$dev" ]; then
        rm -f "$tmp_json"
        return 1
    fi

    local name latest
    name=$(echo "$dev" | jq -r '.name // "device"')
    latest=$(echo "$dev" | jq -r '.latest_jailbreakable // empty')

    local count i frm to jb url
    count=$(echo "$dev" | jq '.versions | length')
    for ((i = 0; i < count; i++)); do
        frm=$(echo "$dev" | jq -r ".versions[$i].from")
        to=$(echo "$dev" | jq -r ".versions[$i].to")
        jb=$(echo "$dev" | jq -r ".versions[$i].jailbreak")
        url=$(echo "$dev" | jq -r ".versions[$i].url")

        if version_in_range "$ver" "$frm" "$to" 2>/dev/null; then
            rm -f "$tmp_json"
            if [ "$jb" = "null" ] || [ -z "$jb" ]; then
                echo "Not Supported ($name on $ver has no known jailbreak)"
            else
                echo "$jb ($url)"
            fi
            return 0
        fi
    done

    rm -f "$tmp_json"
    echo "Unknown for this version ($name, latest jailbreakable known: ${latest:-N/A})"
    return 0
}

get_device_info() {
    echo "iCh3cker | <3 | github.com/dontbeskid"
    echo "Searching for connected iOS device..."
    echo ""

    local udid
    udid=$(ideviceinfo -k UniqueDeviceID 2>/dev/null)

    if [ -z "$udid" ]; then
        echo "Status: No device detected."
        echo "Ensure your device is connected via USB and trusted on this computer."
        exit 1
    fi

    local name=$(ideviceinfo -k DeviceName 2>/dev/null)
    local class=$(ideviceinfo -k DeviceClass 2>/dev/null)
    local model=$(ideviceinfo -k ProductType 2>/dev/null)
    local os_ver=$(ideviceinfo -k ProductVersion 2>/dev/null)
    local build_ver=$(ideviceinfo -k BuildVersion 2>/dev/null)
    local model_num=$(ideviceinfo -k ModelNumber 2>/dev/null)
    local region_code=$(ideviceinfo -k RegionInfo 2>/dev/null)
    local serial=$(ideviceinfo -k SerialNumber 2>/dev/null)
    local imei=$(ideviceinfo -k InternationalMobileEquipmentIdentity 2>/dev/null)
    local meid=$(ideviceinfo -k MobileEquipmentIdentifier 2>/dev/null)
    local wifi_mac=$(ideviceinfo -k WiFiAddress 2>/dev/null)

    local activated=$(ideviceinfo -k ActivationState 2>/dev/null)
    local fmi=$(ideviceinfo -q com.apple.fmip -k FindMyiPhoneEnabled 2>/dev/null)
    local pass_status=$(ideviceinfo -k PasswordProtected 2>/dev/null)

    local batt_raw
    batt_raw=$(idevicediagnostics ioregentry AppleSmartBattery 2>/dev/null)
    if [ -z "$batt_raw" ]; then
        batt_raw=$(idevicediagnostics ioregentry AppleARMPMUCharger 2>/dev/null)
    fi

    local cycle_count=$(echo "$batt_raw" | grep -A 1 "CycleCount" | grep -oE '[0-9]+' | head -n 1)
    local max_cap=$(echo "$batt_raw" | grep -A 1 "AppleRawMaxCapacity" | grep -oE '[0-9]+' | head -n 1)
    local design_cap=$(echo "$batt_raw" | grep -A 1 "DesignCapacity" | grep -oE '[0-9]+' | head -n 1)
    local batt_level=$(ideviceinfo -q com.apple.mobile.battery -k BatteryCurrentCapacity 2>/dev/null)

    local batt_health="N/A"
    if [ -n "$max_cap" ] && [ -n "$design_cap" ] && [ "$design_cap" -gt 0 ]; then
        local health_calc=$(( (max_cap * 100) / design_cap ))
        if [ "$health_calc" -gt 100 ]; then
            health_calc=100
        fi
        batt_health="${health_calc}%"
    fi

    local prod_date=$(get_production_date "$serial")

    local jb_status jb_source
    jb_status=$(lookup_jailbreak_from_json "$model" "$os_ver")
    if [ -n "$jb_status" ]; then
        jb_source="ios.cfw.guide"
    else
        jb_status=$(check_jailbreak_support "$os_ver")
        jb_source="built-in table"
    fi

    echo "-- general"
    echo "Device Name        : ${name:-N/A}"
    echo "Device Class       : ${class:-N/A}"
    echo "Product Model      : ${model:-N/A}"
    echo "Model Number       : ${model_num:-N/A}"
    echo "Region Code        : ${region_code:-N/A}"
    echo "Estimated Prod Date: ${prod_date}"
    echo ""
    echo "-- system"
    echo "iOS/iPadOS Version : ${os_ver:-N/A} (${build_ver:-N/A})"
    echo "Jailbreak Support  : ${jb_status} [source: ${jb_source}]"
    echo "Activation State   : ${activated:-N/A}"
    echo "Find My iPhone     : ${fmi:-N/A}"
    echo "Passcode Enabled   : ${pass_status:-N/A}"
    echo ""
    echo "-- hardware"
    echo "Battery Level      : ${batt_level:-N/A}%"
    echo "Battery Health     : ${batt_health}"
    echo "Battery Cycles     : ${cycle_count:-N/A}"
    echo "Current Capacity   : ${max_cap:-N/A} mAh"
    echo "Design Capacity    : ${design_cap:-N/A} mAh"
    echo ""
    echo "-- ident."
    echo "Serial Number      : ${serial:-N/A}"
    echo "UDID               : ${udid}"
    echo "IMEI               : ${imei:-N/A}"
    echo "MEID               : ${meid:-N/A}"
    echo "Wi-Fi Address      : ${wifi_mac:-N/A}"
    echo ""
    echo "github.com/dontbeskid"
}

main() {
    check_dependencies
    get_device_info
}

main
