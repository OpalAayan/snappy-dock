#!/bin/bash

# Resolves an app class name to an icon file path.
# Usage: ./icon-lookup.sh <class_name>

if [ -z "$1" ]; then
    exit 1
fi

APP_CLASS="$1"
APP_CLASS_LOWER=$(echo "$APP_CLASS" | tr '[:upper:]' '[:lower:]')

# Build the list of .desktop search directories
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
IFS=':' read -ra DATA_DIRS <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

DESKTOP_DIRS=("$DATA_HOME/applications")
for dir in "${DATA_DIRS[@]}"; do
    DESKTOP_DIRS+=("$dir/applications")
done
DESKTOP_DIRS+=(
    "/var/lib/flatpak/exports/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
)

# Helper function to extract Icon= value from a .desktop file, only from [Desktop Entry]
extract_icon() {
    local desktop_file="$1"
    if [ ! -f "$desktop_file" ]; then
        return 1
    fi
    
    # Read line by line. Stop if we reach another section.
    # Print Icon value if in [Desktop Entry].
    awk '
        /^\[Desktop Entry\]/ { in_entry = 1; next }
        /^\[.*\]/ && !/^\[Desktop Entry\]/ { in_entry = 0 }
        in_entry && /^Icon=/ {
            sub(/^Icon=/, "")
            print
            exit
        }
    ' "$desktop_file"
}

# Helper function to resolve an icon name to a file path
resolve_icon_name() {
    local icon_name="$1"
    
    # If absolute path and exists, just print it
    if [[ "$icon_name" == /* ]]; then
        if [ -e "$icon_name" ]; then
            echo "$icon_name"
            return 0
        fi
        # Try appending extensions if not exist, some .desktop files have full path without ext (rare but happens)
        for ext in .svg .png .xpm; do
            if [ -e "${icon_name}${ext}" ]; then
                echo "${icon_name}${ext}"
                return 0
            fi
        done
        return 1
    fi

    local exts=(".png" ".svg" ".xpm")
    local sizes=("256x256" "128x128" "64x64" "48x48" "scalable")
    
    # Search locations
    local icon_dirs=(
        "$HOME/.local/share/icons"
        "$HOME/.local/share/flatpak/exports/share/icons"
        "/var/lib/flatpak/exports/share/icons"
        "/usr/share/icons"
    )
    
    # Try finding in hicolor first, by preferred sizes
    for size in "${sizes[@]}"; do
        for ext in "${exts[@]}"; do
            for base_dir in "${icon_dirs[@]}"; do
                local candidate="$base_dir/hicolor/$size/apps/${icon_name}${ext}"
                if [ -e "$candidate" ]; then
                    echo "$candidate"
                    return 0
                fi
            done
        done
    done
    
    # Try pixmaps
    for ext in "${exts[@]}"; do
        local candidate="/usr/share/pixmaps/${icon_name}${ext}"
        if [ -e "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# Processes a .desktop file: extracts icon, resolves it, prints it, and exits if found.
process_desktop_file() {
    local file="$1"
    local icon_val
    icon_val=$(extract_icon "$file")
    if [ -n "$icon_val" ]; then
        local resolved
        resolved=$(resolve_icon_name "$icon_val")
        if [ -n "$resolved" ]; then
            echo "$resolved"
            exit 0
        fi
    fi
}

# 1. Exact match
for dir in "${DESKTOP_DIRS[@]}"; do
    candidate="$dir/${APP_CLASS}.desktop"
    if [ -f "$candidate" ]; then
        process_desktop_file "$candidate"
    fi
done

# 2. Lowercase match
for dir in "${DESKTOP_DIRS[@]}"; do
    candidate="$dir/${APP_CLASS_LOWER}.desktop"
    if [ -f "$candidate" ]; then
        process_desktop_file "$candidate"
    fi
done

# 3. Reverse-DNS match
if [[ "$APP_CLASS" == *.* ]]; then
    # Last segment
    last_seg="${APP_CLASS##*.}"
    last_seg_lower=$(echo "$last_seg" | tr '[:upper:]' '[:lower:]')
    for dir in "${DESKTOP_DIRS[@]}"; do
        candidate="$dir/${last_seg}.desktop"
        if [ -f "$candidate" ]; then
            process_desktop_file "$candidate"
        fi
        
        candidate_lower="$dir/${APP_CLASS_LOWER}.desktop"
        if [ -f "$candidate_lower" ]; then
            process_desktop_file "$candidate_lower"
        fi
    done
fi

# 4. Substring scan
for dir in "${DESKTOP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        for file in "$dir"/*.desktop; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
                if [[ "$filename_lower" == *"$APP_CLASS_LOWER"* ]]; then
                    process_desktop_file "$file"
                fi
            fi
        done
    fi
done

# 5. StartupWMClass scan
for dir in "${DESKTOP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        for file in "$dir"/*.desktop; do
            if [ -f "$file" ]; then
                # grep -qi to match StartupWMClass=$APP_CLASS (case-insensitive on APP_CLASS? the spec says StartupWMClass is matched exactly but the prompt says case-insensitive match for StartupWMClass=<name>)
                if grep -Eqi "^StartupWMClass=${APP_CLASS}$" "$file"; then
                    process_desktop_file "$file"
                fi
            fi
        done
    fi
done

exit 0
