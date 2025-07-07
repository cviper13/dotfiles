#!/bin/bash

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Function to get signal strength icon
get_signal_icon() {
    local signal="$1"
    if [ "$signal" -ge 75 ]; then
        echo "📶"
    elif [ "$signal" -ge 50 ]; then
        echo "📶"
    elif [ "$signal" -ge 25 ]; then
        echo "📱"
    else
        echo "📵"
    fi
}

# Function to get connection type icon
get_connection_icon() {
    local connection="$1"
    local conn_type=$(nmcli -t -f TYPE connection show "$connection" 2>/dev/null)
    case "$conn_type" in
        "802-11-wireless") echo "📶" ;;
        "802-3-ethernet") echo "🔌" ;;
        "wireguard") echo "🛡️" ;;
        "vpn") echo "🔒" ;;
        "bluetooth") echo "🔵" ;;
        "tun") echo "🌐" ;;
        *) echo "🔗" ;;
    esac
}

# Function to get network frequency
get_network_frequency() {
    local ssid="$1"
    nmcli -t -f FREQ device wifi list | grep -A1 "$ssid" | tail -1 | cut -d':' -f2
}

# Function to check if network is 5GHz
is_5ghz_network() {
    local freq="$1"
    [ "$freq" -gt 4000 ] 2>/dev/null && echo "5G" || echo "2.4G"
}

# Function to get device temperature (if available)
get_device_temp() {
    if command -v sensors &> /dev/null; then
        sensors 2>/dev/null | grep -i wifi | grep -o '[0-9]\+\.[0-9]\+°C' | head -1
    fi
}

# Function to get data usage
get_data_usage() {
    local interface="$1"
    if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ] && [ -f "/sys/class/net/$interface/statistics/tx_bytes" ]; then
        local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
        local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
        echo "RX: $(numfmt --to=iec $rx_bytes)B TX: $(numfmt --to=iec $tx_bytes)B"
    fi
}

# WiFi and VPN Controller configuration
ROFI_THEME="$HOME/.cache/wal/colors-rofi-dark.rasi"

# Configuration
SCAN_INTERVAL=30
SIGNAL_THRESHOLD=30
LOG_FILE="$HOME/.cache/wifi_selector.log"
CONFIG_FILE="$HOME/.config/wifi_selector.conf"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check if NetworkManager is available
if ! command -v nmcli &> /dev/null; then
    notify-send "Error" "NetworkManager (nmcli) not found"
    exit 1
fi

# Check if rofi is available
if ! command -v rofi &> /dev/null; then
    notify-send "Error" "Rofi not found"
    exit 1
fi

# Function to get WiFi status
get_wifi_status() {
    nmcli radio wifi
}

# Function to get current connection
get_current_connection() {
    nmcli -t -f NAME connection show --active | grep -v "lo\|docker\|br-"
}

# Function to get current wifi connection
get_current_wifi_connection() {
    nmcli -t -f NAME,TYPE connection show --active | grep -E ":802-11-wireless$" | cut -d':' -f1
}

# Function to get current VPN connection
get_current_vpn_connection() {
    nmcli -t -f NAME,TYPE connection show --active | grep -E "wireguard|vpn" | cut -d':' -f1 | head -n1
}

# Function to scan and list WiFi networks
list_networks() {
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | tail -n +1 | sort -t: -k2 -nr
}

# Function to get saved connections
get_saved_connections() {
    nmcli -t -f NAME connection show | grep -v "lo\|docker\|br-"
}

# Function to connect to network
connect_network() {
    local ssid="$1"
    local security="$2"

    # Check if network is already saved
    if nmcli connection show "$ssid" &> /dev/null; then
        nmcli connection up "$ssid"
        if [ $? -eq 0 ]; then
            notify-send "WiFi" "Connected to $ssid"
        else
            notify-send "WiFi Error" "Failed to connect to $ssid"
        fi
    else
        # New network, need password if secured
        if [[ "$security" == *"WPA"* ]] || [[ "$security" == *"WEP"* ]]; then
            password=$(rofi -dmenu -password -p "Password for $ssid" -theme "$ROFI_THEME")
            if [ -n "$password" ]; then
                nmcli device wifi connect "$ssid" password "$password"
                if [ $? -eq 0 ]; then
                    notify-send "WiFi" "Connected to $ssid"
                else
                    notify-send "WiFi Error" "Failed to connect to $ssid"
                fi
            fi
        else
            # Open network
            nmcli device wifi connect "$ssid"
            if [ $? -eq 0 ]; then
                notify-send "WiFi" "Connected to $ssid"
            else
                notify-send "WiFi Error" "Failed to connect to $ssid"
            fi
        fi
    fi
}

# Function to disconnect from network
disconnect_network() {
    local connection="$1"
    nmcli connection down "$connection"
    if [ $? -eq 0 ]; then
        notify-send "WiFi" "Disconnected from $connection"
    else
        notify-send "WiFi Error" "Failed to disconnect from $connection"
    fi
}

# Function to toggle WiFi
toggle_wifi() {
    local status=$(get_wifi_status)
    if [ "$status" = "enabled" ]; then
        nmcli radio wifi off
        notify-send "WiFi" "WiFi disabled"
    else
        nmcli radio wifi on
        notify-send "WiFi" "WiFi enabled"
    fi
}

# Function to forget network
forget_network() {
    local connection="$1"
    nmcli connection delete "$connection"
    if [ $? -eq 0 ]; then
        notify-send "WiFi" "Forgot network $connection"
    else
        notify-send "WiFi Error" "Failed to forget network $connection"
    fi
}

# Function to show network info
show_network_info() {
    local connection="$1"
    local connection_type=$(nmcli -t -f TYPE connection show "$connection")

    if [[ "$connection_type" =~ ^(wireguard|vpn)$ ]]; then
        show_vpn_info "$connection"
    else
        local info=$(nmcli connection show "$connection" | grep -E "connection.id|802-11-wireless.ssid|ipv4.addresses|ipv4.gateway|connection.autoconnect")
        echo "$info" | rofi -dmenu -p "Network Info: $connection" -theme "$ROFI_THEME"
    fi
}

# Function to get VPN connections
get_vpn_connections() {
    nmcli -t -f NAME,TYPE connection show | grep "wireguard\|vpn" | cut -d':' -f1
}

# Function to get VPN status
get_vpn_status() {
    local vpn_name="$1"
    if [ -z "$vpn_name" ]; then
        # Check if any VPN is active
        nmcli -t -f NAME,TYPE connection show --active | grep -E "wireguard|vpn" | cut -d':' -f1 | head -n1
    else
        # Check specific VPN status
        if nmcli -t -f NAME connection show --active | grep -q "^$vpn_name$"; then
            echo "connected"
        else
            echo "disconnected"
        fi
    fi
}

# Function to connect VPN
connect_vpn() {
    local vpn_name="$1"
    nmcli connection up "$vpn_name"
    if [ $? -eq 0 ]; then
        notify-send "VPN" "Connected to $vpn_name"
    else
        notify-send "VPN Error" "Failed to connect to $vpn_name"
    fi
}

# Function to disconnect VPN
disconnect_vpn() {
    local vpn_name="$1"
    nmcli connection down "$vpn_name"
    if [ $? -eq 0 ]; then
        notify-send "VPN" "Disconnected from $vpn_name"
    else
        notify-send "VPN Error" "Failed to disconnect from $vpn_name"
    fi
}

# Function to show VPN info
show_vpn_info() {
    local vpn_name="$1"
    local info=$(nmcli connection show "$vpn_name" | grep -E "connection.id|connection.type|ipv4.addresses|ipv4.gateway|connection.autoconnect")
    echo "$info" | rofi -dmenu -p "VPN Info: $vpn_name" -theme "$ROFI_THEME"
}

# Main menu function
show_main_menu() {
    local wifi_status=$(get_wifi_status)
    local current_wifi=$(get_current_wifi_connection)
    local current_vpn=$(get_current_vpn_connection)

    local menu_items=""

    # WiFi section
    if [ "$wifi_status" = "enabled" ]; then
        menu_items+="🔍 Scan Networks\n"
        if [ -n "$current_wifi" ]; then
            menu_items+="📶 WiFi: $current_wifi\n"
        fi
        menu_items+="📋 Saved Networks\n"
        menu_items+="📴 Turn WiFi Off\n"
    else
        menu_items+="📶 Turn WiFi On\n"
    fi

    # VPN section
    menu_items+="🔒 VPN Connections\n"
    if [ -n "$current_vpn" ]; then
        menu_items+="🟢 VPN: $current_vpn\n"
    fi

    menu_items+="🔄 Refresh\n"
    menu_items+="❌ Exit"

    echo -e "$menu_items"
}

# Network selection menu
show_network_menu() {
    echo "🔄 Scanning networks..."
    local networks=$(list_networks)
    local menu_items="🔙 Back\n"

    while IFS=':' read -r ssid signal security; do
        if [ -n "$ssid" ] && [ "$ssid" != "SSID" ] && [[ ! "$ssid" =~ ^[[:space:]]*$ ]]; then
            local icon="📶"
            if [[ "$security" == *"WPA"* ]] || [[ "$security" == *"WEP"* ]]; then
                icon="🔒"
            fi
            # Clean up signal value (remove any extra characters)
            signal=$(echo "$signal" | tr -d ' ')
            menu_items+="$icon $ssid ($signal%)\n"
        fi
    done <<< "$networks"

    echo -e "$menu_items"
}

# Saved networks menu
show_saved_menu() {
    local saved_networks=$(get_saved_connections)
    local menu_items="🔙 Back\n"

    while IFS= read -r connection; do
        if [ -n "$connection" ]; then
            menu_items+="📱 $connection\n"
        fi
    done <<< "$saved_networks"

    echo -e "$menu_items"
}

# Saved network actions menu
show_saved_actions() {
    local connection="$1"
    local menu_items="🔙 Back\n"
    menu_items+="🔌 Connect\n"
    menu_items+="🗑️  Forget Network\n"
    menu_items+="ℹ️  Show Info"

    echo -e "$menu_items"
}

# VPN selection menu
show_vpn_menu() {
    local vpn_connections=$(get_vpn_connections)
    local menu_items="🔙 Back\n"

    if [ -z "$vpn_connections" ]; then
        menu_items+="❌ No VPN connections found\n"
    else
        while IFS= read -r vpn; do
            if [ -n "$vpn" ]; then
                local status=$(get_vpn_status "$vpn")
                local icon="🔒"
                if [ "$status" = "connected" ]; then
                    icon="🟢"
                fi
                menu_items+="$icon $vpn\n"
            fi
        done <<< "$vpn_connections"
    fi

    echo -e "$menu_items"
}

# VPN actions menu
show_vpn_actions() {
    local vpn_name="$1"
    local status=$(get_vpn_status "$vpn_name")
    local menu_items="🔙 Back\n"

    if [ "$status" = "connected" ]; then
        menu_items+="🔌 Disconnect\n"
    else
        menu_items+="🔌 Connect\n"
    fi

    menu_items+="ℹ️  Show Info\n"
    menu_items+="🗑️  Delete VPN"

    echo -e "$menu_items"
}

# Main script logic
main() {
    while true; do
        choice=$(show_main_menu | rofi -dmenu -p "WiFi & VPN Controller" -theme "$ROFI_THEME")

        case "$choice" in
            "🔍 Scan Networks")
                while true; do
                    network_choice=$(show_network_menu | rofi -dmenu -p "Select Network" -theme "$ROFI_THEME")

                    if [ "$network_choice" = "🔙 Back" ] || [ -z "$network_choice" ]; then
                        break
                    else
                        # Extract SSID from choice (remove icon and signal info)
                        ssid=$(echo "$network_choice" | sed 's/^[🔒📶] //' | sed 's/ ([0-9]*%)$//')
                        # Get security info from the raw network list
                        security=$(list_networks | grep "^$ssid:" | cut -d':' -f3)
                        connect_network "$ssid" "$security"
                        break
                    fi
                done
                ;;
            "📶 WiFi:"*)
                # Handle WiFi connection selection
                current_wifi=$(get_current_wifi_connection)
                if [ -n "$current_wifi" ]; then
                    action=$(echo -e "🔌 Disconnect\nℹ️  Network Info\n🔙 Back" | rofi -dmenu -p "$current_wifi" -theme "$ROFI_THEME")
                    case "$action" in
                        "🔌 Disconnect")
                            disconnect_network "$current_wifi"
                            ;;
                        "ℹ️  Network Info")
                            show_network_info "$current_wifi"
                            ;;
                    esac
                fi
                ;;
            "🟢 VPN:"*)
                # Handle VPN connection selection
                current_vpn=$(get_current_vpn_connection)
                if [ -n "$current_vpn" ]; then
                    action=$(echo -e "🔌 Disconnect\nℹ️  VPN Info\n🔙 Back" | rofi -dmenu -p "$current_vpn" -theme "$ROFI_THEME")
                    case "$action" in
                        "🔌 Disconnect")
                            disconnect_vpn "$current_vpn"
                            ;;
                        "ℹ️  VPN Info")
                            show_vpn_info "$current_vpn"
                            ;;
                    esac
                fi
                ;;
            "🔒 VPN Connections")
                while true; do
                    vpn_choice=$(show_vpn_menu | rofi -dmenu -p "VPN Connections" -theme "$ROFI_THEME")

                    if [ "$vpn_choice" = "🔙 Back" ] || [ -z "$vpn_choice" ] || [ "$vpn_choice" = "❌ No VPN connections found" ]; then
                        break
                    else
                        vpn_name=$(echo "$vpn_choice" | sed 's/^[🔒🟢] //')

                        while true; do
                            action_choice=$(show_vpn_actions "$vpn_name" | rofi -dmenu -p "$vpn_name" -theme "$ROFI_THEME")

                            case "$action_choice" in
                                "🔙 Back"|"")
                                    break
                                    ;;
                                "🔌 Connect")
                                    connect_vpn "$vpn_name"
                                    break 2
                                    ;;
                                "🔌 Disconnect")
                                    disconnect_vpn "$vpn_name"
                                    break 2
                                    ;;
                                "ℹ️  Show Info")
                                    show_vpn_info "$vpn_name"
                                    ;;
                                "🗑️  Delete VPN")
                                    confirm=$(echo -e "No\nYes" | rofi -dmenu -p "Delete $vpn_name?" -theme "$ROFI_THEME")
                                    if [ "$confirm" = "Yes" ]; then
                                        nmcli connection delete "$vpn_name"
                                        if [ $? -eq 0 ]; then
                                            notify-send "VPN" "Deleted VPN $vpn_name"
                                        else
                                            notify-send "VPN Error" "Failed to delete VPN $vpn_name"
                                        fi
                                        break 2
                                    fi
                                    ;;
                            esac
                        done
                    fi
                done
                ;;
            "📋 Saved Networks")
                while true; do
                    saved_choice=$(show_saved_menu | rofi -dmenu -p "Saved Networks" -theme "$ROFI_THEME")

                    if [ "$saved_choice" = "🔙 Back" ] || [ -z "$saved_choice" ]; then
                        break
                    else
                        connection=$(echo "$saved_choice" | sed 's/^📱 //')

                        while true; do
                            action_choice=$(show_saved_actions "$connection" | rofi -dmenu -p "$connection" -theme "$ROFI_THEME")

                            case "$action_choice" in
                                "🔙 Back"|"")
                                    break
                                    ;;
                                "🔌 Connect")
                                    nmcli connection up "$connection"
                                    if [ $? -eq 0 ]; then
                                        notify-send "WiFi" "Connected to $connection"
                                    else
                                        notify-send "WiFi Error" "Failed to connect to $connection"
                                    fi
                                    break 2
                                    ;;
                                "🗑️  Forget Network")
                                    confirm=$(echo -e "No\nYes" | rofi -dmenu -p "Forget $connection?" -theme "$ROFI_THEME")
                                    if [ "$confirm" = "Yes" ]; then
                                        forget_network "$connection"
                                        break 2
                                    fi
                                    ;;
                                "ℹ️  Show Info")
                                    show_network_info "$connection"
                                    ;;
                            esac
                        done
                    fi
                done
                ;;
            "📴 Turn WiFi Off")
                toggle_wifi
                ;;
            "📶 Turn WiFi On")
                toggle_wifi
                ;;
            "🔄 Refresh")
                continue
                ;;
            "❌ Exit"|"")
                exit 0
                ;;
        esac
    done
}

# Run the main function
main
