#!/bin/bash

# Wallhaven Browser Script with Rofi UI
# Browse and download wallpapers from wallhaven.cc

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallhaven"
CURRENT_PAGE=1
SEARCH_QUERY=""
CATEGORY="111"  # 111 = General, Anime, People (all categories)
PURITY="100"    # 100 = SFW only
SORTING="date_added"
ORDER="desc"
RESOLUTION=""

# Rofi theme options
ROFI_THEME="$HOME/.cache/wal/colors-rofi-dark.rasi"
ROFI_LINES=15
ROFI_WIDTH=80

# Create necessary directories
mkdir -p "$WALLPAPER_DIR" "$CACHE_DIR"

# Function to show notification
notify() {
    local message="$1"
    local urgency="${2:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "Wallhaven Browser" "$message"
    fi
}

# Function to show rofi menu
show_rofi_menu() {
    local prompt="$1"
    local options="$2"
    local selected_lines="${3:-$ROFI_LINES}"
    echo -e "$options" | rofi -dmenu -i -p "$prompt" -l "$selected_lines" -theme "$ROFI_THEME" -width 80 -columns 1
}

# Function to get user input via rofi
get_rofi_input() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        echo "$default" | rofi -dmenu -p "$prompt" -theme "$ROFI_THEME" -width 60 -lines 1
    else
        rofi -dmenu -p "$prompt" -theme "$ROFI_THEME" -width 60 -lines 1
    fi
}

# Function to fetch wallpapers from API
fetch_wallpapers() {
    local url="https://wallhaven.cc/api/v1/search?"
    url+="page=$CURRENT_PAGE"
    url+="&categories=$CATEGORY"
    url+="&purity=$PURITY"
    url+="&sorting=$SORTING"
    url+="&order=$ORDER"
    
    if [ -n "$SEARCH_QUERY" ]; then
        url+="&q=$(echo "$SEARCH_QUERY" | sed 's/ /%20/g')"
    fi
    
    if [ -n "$RESOLUTION" ]; then
        url+="&resolutions=$RESOLUTION"
    fi
    
    notify "Fetching wallpapers..." "low"
    
    local response=$(curl -s "$url")
    if [ $? -ne 0 ]; then
        notify "Error: Failed to fetch wallpapers" "critical"
        return 1
    fi
    
    echo "$response" > "$CACHE_DIR/current_page.json"
    return 0
}

# Function to parse and display wallpapers
display_wallpapers() {
    if [ ! -f "$CACHE_DIR/current_page.json" ]; then
        notify "No wallpapers data found" "critical"
        return 1
    fi
    
    local total=$(jq -r '.meta.total' "$CACHE_DIR/current_page.json" 2>/dev/null)
    local current_page=$(jq -r '.meta.current_page' "$CACHE_DIR/current_page.json" 2>/dev/null)
    local last_page=$(jq -r '.meta.last_page' "$CACHE_DIR/current_page.json" 2>/dev/null)
    
    # Create wallpaper list for rofi
    local wallpaper_list=""
    local count=1
    
    while IFS='|' read -r id url resolution file_size path; do
        local size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc 2>/dev/null || echo "Unknown")
        wallpaper_list+="[$count] ID: $id | $resolution | ${size_mb}MB\n"
        ((count++))
    done < <(jq -r '.data[] | "\(.id)|\(.url)|\(.resolution)|\(.file_size)|\(.path)"' "$CACHE_DIR/current_page.json" 2>/dev/null)
    
    # Create main menu options
    local menu_options=""
    local search_text=""
    if [ -n "$SEARCH_QUERY" ]; then
        search_text=" (Search: $SEARCH_QUERY)"
    fi
    
    menu_options+="📖 Browse Wallpapers - Page $current_page/$last_page$search_text\n"
    menu_options+="🔍 Search Wallpapers\n"
    menu_options+="📂 Change Categories\n"
    menu_options+="🔄 Change Sorting\n"
    menu_options+="📏 Filter by Resolution\n"
    menu_options+="⬅️  Previous Page\n"
    menu_options+="➡️  Next Page\n"
    menu_options+="❌ Quit\n"
    menu_options+="---\n"
    menu_options+="$wallpaper_list"
    
    echo -e "$menu_options"
}

# Function to download wallpaper
download_wallpaper() {
    local num=$1
    if [ -z "$num" ] || ! [[ "$num" =~ ^[0-9]+$ ]]; then
        notify "Please specify a valid wallpaper number" "critical"
        return 1
    fi
    
    local wallpaper_data=$(jq -r ".data[$((num-1))] | \"\(.id)|\(.path)\"" "$CACHE_DIR/current_page.json" 2>/dev/null)
    if [ "$wallpaper_data" = "null|null" ] || [ -z "$wallpaper_data" ]; then
        notify "Invalid wallpaper number" "critical"
        return 1
    fi
    
    local id=$(echo "$wallpaper_data" | cut -d'|' -f1)
    local path=$(echo "$wallpaper_data" | cut -d'|' -f2)
    local filename=$(basename "$path")
    
    notify "Downloading wallpaper $id..." "low"
    
    if curl -L -o "$WALLPAPER_DIR/$filename" "$path"; then
        notify "✓ Downloaded: $filename\nSaved to: $WALLPAPER_DIR/$filename" "normal"
    else
        notify "✗ Failed to download wallpaper" "critical"
        return 1
    fi
}

# Function to view wallpaper in browser
view_wallpaper() {
    local num=$1
    if [ -z "$num" ] || ! [[ "$num" =~ ^[0-9]+$ ]]; then
        notify "Please specify a valid wallpaper number" "critical"
        return 1
    fi
    
    local url=$(jq -r ".data[$((num-1))].url" "$CACHE_DIR/current_page.json" 2>/dev/null)
    if [ "$url" = "null" ] || [ -z "$url" ]; then
        notify "Invalid wallpaper number" "critical"
        return 1
    fi
    
    notify "Opening wallpaper in browser..." "low"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url"
    elif command -v open >/dev/null 2>&1; then
        open "$url"
    else
        notify "Copy this URL to your browser: $url" "normal"
        echo "$url" | xclip -selection clipboard 2>/dev/null || echo "$url"
    fi
}

# Function to show wallpaper info
show_wallpaper_info() {
    local num=$1
    if [ -z "$num" ] || ! [[ "$num" =~ ^[0-9]+$ ]]; then
        notify "Please specify a valid wallpaper number" "critical"
        return 1
    fi
    
    local wallpaper_info=$(jq -r ".data[$((num-1))]" "$CACHE_DIR/current_page.json" 2>/dev/null)
    if [ "$wallpaper_info" = "null" ]; then
        notify "Invalid wallpaper number" "critical"
        return 1
    fi
    
    local id=$(echo "$wallpaper_info" | jq -r '.id')
    local url=$(echo "$wallpaper_info" | jq -r '.url')
    local resolution=$(echo "$wallpaper_info" | jq -r '.resolution')
    local file_size=$(echo "$wallpaper_info" | jq -r '.file_size')
    local category=$(echo "$wallpaper_info" | jq -r '.category')
    local purity=$(echo "$wallpaper_info" | jq -r '.purity')
    local views=$(echo "$wallpaper_info" | jq -r '.views')
    local favorites=$(echo "$wallpaper_info" | jq -r '.favorites')
    
    local size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc 2>/dev/null || echo "Unknown")
    
    local info_text="ID: $id\nURL: $url\nResolution: $resolution\nFile Size: ${size_mb}MB\nCategory: $category\nPurity: $purity\nViews: $views\nFavorites: $favorites"
    
    local action_options="📥 Download\n🌐 View in Browser\n🔙 Back"
    local action=$(echo -e "$action_options" | show_rofi_menu "Wallpaper Info - $id" "$action_options" 3)
    
    case "$action" in
        "📥 Download")
            download_wallpaper "$num"
            ;;
        "🌐 View in Browser")
            view_wallpaper "$num"
            ;;
        "🔙 Back"|"")
            return 0
            ;;
    esac
}

# Function to change search query
change_search() {
    local new_search=$(get_rofi_input "Enter search query (empty for all)" "$SEARCH_QUERY")
    if [ $? -eq 0 ]; then
        SEARCH_QUERY="$new_search"
        CURRENT_PAGE=1
        notify "Search query updated" "low"
        return 0
    fi
    return 1
}

# Function to change categories
change_categories() {
    local category_options="General only\nAnime only\nPeople only\nGeneral + Anime\nGeneral + People\nAnime + People\nAll categories"
    local choice=$(show_rofi_menu "Select categories" "$category_options" 7)
    
    case "$choice" in
        "General only") CATEGORY="100" ;;
        "Anime only") CATEGORY="010" ;;
        "People only") CATEGORY="001" ;;
        "General + Anime") CATEGORY="110" ;;
        "General + People") CATEGORY="101" ;;
        "Anime + People") CATEGORY="011" ;;
        "All categories") CATEGORY="111" ;;
        "") return 1 ;;
        *) notify "Invalid choice" "critical"; return 1 ;;
    esac
    
    CURRENT_PAGE=1
    notify "Categories updated" "low"
    return 0
}

# Function to change sorting
change_sorting() {
    local sorting_options="Date added (newest first)\nDate added (oldest first)\nRelevance\nRandom\nViews\nFavorites"
    local choice=$(show_rofi_menu "Select sorting" "$sorting_options" 6)
    
    case "$choice" in
        "Date added (newest first)") SORTING="date_added"; ORDER="desc" ;;
        "Date added (oldest first)") SORTING="date_added"; ORDER="asc" ;;
        "Relevance") SORTING="relevance"; ORDER="desc" ;;
        "Random") SORTING="random"; ORDER="desc" ;;
        "Views") SORTING="views"; ORDER="desc" ;;
        "Favorites") SORTING="favorites"; ORDER="desc" ;;
        "") return 1 ;;
        *) notify "Invalid choice" "critical"; return 1 ;;
    esac
    
    CURRENT_PAGE=1
    notify "Sorting updated" "low"
    return 0
}

# Function to change resolution filter
change_resolution() {
    local new_resolution=$(get_rofi_input "Enter resolution (e.g., 1920x1080) or empty for all" "$RESOLUTION")
    if [ $? -eq 0 ]; then
        RESOLUTION="$new_resolution"
        CURRENT_PAGE=1
        notify "Resolution filter updated" "low"
        return 0
    fi
    return 1
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing+=("curl")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        missing+=("bc")
    fi
    
    if ! command -v rofi >/dev/null 2>&1; then
        missing+=("rofi")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        local install_msg="Missing required dependencies: ${missing[*]}\n\nInstall commands:\nUbuntu/Debian: sudo apt install ${missing[*]}\nArch Linux: sudo pacman -S ${missing[*]}\nmacOS: brew install ${missing[*]}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "Wallhaven Browser" "$install_msg"
        else
            echo "Missing required dependencies: ${missing[*]}"
            echo "Please install them using your package manager:"
            echo "Ubuntu/Debian: sudo apt install ${missing[*]}"
            echo "Arch Linux: sudo pacman -S ${missing[*]}"
            echo "macOS: brew install ${missing[*]}"
        fi
        exit 1
    fi
}

# Function to handle wallpaper selection
handle_wallpaper_selection() {
    local selection="$1"
    
    # Extract wallpaper number from selection
    if [[ "$selection" =~ ^\[([0-9]+)\] ]]; then
        local num="${BASH_REMATCH[1]}"
        
        # Show wallpaper action menu
        local action_options="📥 Download\n🌐 View in Browser\nℹ️  Show Info\n🔙 Back"
        local action=$(show_rofi_menu "Wallpaper Actions" "$action_options" 4)
        
        case "$action" in
            "📥 Download")
                download_wallpaper "$num"
                ;;
            "🌐 View in Browser")
                view_wallpaper "$num"
                ;;
            "ℹ️  Show Info")
                show_wallpaper_info "$num"
                ;;
            "🔙 Back"|"")
                return 0
                ;;
        esac
    fi
}

# Main loop
main() {
    check_dependencies
    
    notify "Welcome to Wallhaven Browser!\nWallpapers will be saved to: $WALLPAPER_DIR" "low"
    
    # Initial fetch
    fetch_wallpapers
    
    while true; do
        local menu_content=$(display_wallpapers)
        local selection=$(echo -e "$menu_content" | show_rofi_menu "Wallhaven Browser" "$menu_content" 15)
        
        case "$selection" in
            "📖 Browse Wallpapers"*)
                # Just refresh the current view
                continue
                ;;
            "🔍 Search Wallpapers")
                if change_search; then
                    fetch_wallpapers
                fi
                ;;
            "📂 Change Categories")
                if change_categories; then
                    fetch_wallpapers
                fi
                ;;
            "🔄 Change Sorting")
                if change_sorting; then
                    fetch_wallpapers
                fi
                ;;
            "📏 Filter by Resolution")
                if change_resolution; then
                    fetch_wallpapers
                fi
                ;;
            "⬅️  Previous Page")
                if [ $CURRENT_PAGE -gt 1 ]; then
                    CURRENT_PAGE=$((CURRENT_PAGE - 1))
                    fetch_wallpapers
                else
                    notify "Already on first page" "low"
                fi
                ;;
            "➡️  Next Page")
                CURRENT_PAGE=$((CURRENT_PAGE + 1))
                fetch_wallpapers
                ;;
            "❌ Quit"|"")
                notify "Goodbye!" "low"
                exit 0
                ;;
            \[*\]*)
                handle_wallpaper_selection "$selection"
                ;;
        esac
    done
}

# Run main function
main "$@"