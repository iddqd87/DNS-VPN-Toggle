#!/system/bin/sh
# DNS-VPN-Toggle (robust, all interfaces)
# Author: iddqd87
VPN_INTERFACES="tun0 tun1 tun2 tun3 ppp0 ppp1 ppp2 ppp3 wg0 wg1 wg2 clat0 swlan0 vnic0 vnic1 vnic2 vnic3 vep0 vep1 ep0 ep1 ep2 ep3"
LOG_FILE="/data/adb/modules/dnsvpntoggle/service.log"
CHECK_INTERVAL=0.8
SLEEP_ON_NETWORK_OFF=10

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

is_root() {
    [ "$(id -u)" -eq 0 ]
}

ANDROID_API=$(getprop ro.build.version.sdk)
if [ "$ANDROID_API" -lt 28 ]; then
    log "ERROR: Requires Android 9+ for Private DNS. Exiting."
    exit 1
fi

get_private_dns_mode() {
    settings get global private_dns_mode 2>/dev/null
}

set_private_dns_mode() {
    local mode="$1"
    if ! settings put global private_dns_mode "$mode" 2>/dev/null; then
        log "ERROR: Failed to set private DNS mode to '$mode'"
        return 1
    fi
    log "Set private DNS mode to '$mode'"
    return 0
}

check_vpn() {
    for iface in $VPN_INTERFACES; do
        if ip link show "$iface" 2>/dev/null | grep -E "UP|LOWER_UP" >/dev/null; then
            log "INFO: Detected VPN interface '$iface' is UP."
            return 0
        fi
    done
    log "INFO: No VPN interface detected UP."
    return 1
}

networks_enabled() {
    airplane=$(settings get global airplane_mode_on)
    [ "$airplane" = "1" ] && return 1
    wifi=$(settings get global wifi_on)
    [ "$wifi" = "1" ] && return 0
    data0=$(settings get global mobile_data)
    data1=$(settings get global mobile_data1)
    [ "$data0" = "1" ] && return 0
    [ "$data1" = "1" ] && return 0
    return 1
}

test_settings_command() {
    testval=$(get_private_dns_mode)
    if echo "$testval" | grep -q -E 'Permission denied|security exception|cannot' || [ -z "$testval" ]; then
        log "ERROR: Unable to access 'settings' command as root. Magisk DenyList/Zygisk/ROM restrictions?"
        return 1
    fi
    return 0
}

if ! is_root; then
    log "ERROR: Not running as root. Magisk module not enabled or root blocked?"
    exit 1
fi

SELINUX=$(getenforce 2>/dev/null)
if [ "$SELINUX" = "Enforcing" ]; then
    log "WARN: SELinux is enforcing. If toggling fails, see ROM policy."
fi

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
log "Starting DNS-VPN-Toggle service..."

VPN_STATE=0
DNS_WAS_MANUAL=0
while true; do
    if ! networks_enabled; then
        log "All networks disabled or airplane mode active; polling paused."
        sleep "$SLEEP_ON_NETWORK_OFF"
        continue
    fi
    if ! test_settings_command; then
        log "ERROR: Skipping DNS toggling due to settings command restriction."
        sleep "$SLEEP_ON_NETWORK_OFF"
        continue
    fi
    DNS_CURRENT=$(get_private_dns_mode)
    if check_vpn; then
        if [ "$VPN_STATE" -eq 0 ]; then
            if [ "$DNS_CURRENT" != "off" ]; then
                log "VPN connected: disabling Private DNS."
                set_private_dns_mode off
                DNS_WAS_MANUAL=1
            else
                log "VPN connected: Private DNS already off, no change made."
                DNS_WAS_MANUAL=0
            fi
            VPN_STATE=1
        fi
    else
        if [ "$VPN_STATE" -eq 1 ]; then
            if [ "$DNS_WAS_MANUAL" -eq 1 ]; then
                log "VPN disconnected: restoring Private DNS provider hostname."
                set_private_dns_mode hostname
            else
                log "VPN disconnected: DNS was already off, nothing to restore."
            fi
            VPN_STATE=0
        fi
    fi
    sleep "$CHECK_INTERVAL"
done
