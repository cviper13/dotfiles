#!/bin/bash

# Directory where your wallpapers are
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Let user select a wallpaper with rofi
SELECTED=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) \
    | sort \
    | rofi -theme $HOME/.cache/wal/colors-rofi-dark.rasi -dmenu -i -p "Select Wallpaper")

# Exit if user didn't choose anything
[ -z "$SELECTED" ] && exit 1

# Run wal and swww in parallel
wal -i "$SELECTED" --cols16 &
swww img "$SELECTED" --transition-type grow --transition-duration 0.45 --transition-fps 144 &

# Wait for both to finish
wait

bash ~/.config/mako/updateTheme.sh
