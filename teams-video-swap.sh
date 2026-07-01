#!/bin/bash

##############################################################################
# Configuration
##############################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/.teams-video-swapper"
BACKUP_DIR="$APP_DIR/backups/original"

mkdir -p "$BACKUP_DIR"

##############################################################################
# Discover Teams folders
##############################################################################

discover_teams_folders() {

    local candidates=()

    while IFS= read -r path
    do
        [ -d "$path" ] && candidates+=("$path")
    done <<EOF
$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds
$HOME/Library/Containers/Microsoft Teams/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds
$HOME/Library/Application Support/Microsoft/Teams/Backgrounds
EOF

    while IFS= read -r path
    do
	if find "$path" -maxdepth 1 -name "*.mp4" | grep -q .
	then
    		candidates+=("$path")
	fi
    done < <(
        find "$HOME/Library" \
            -type d \
            -name "Backgrounds" \
            2>/dev/null
    )

    local unique=()

    for folder in "${candidates[@]}"
    do
        local found=0

        for existing in "${unique[@]}"
        do
            [ "$folder" = "$existing" ] && found=1 && break
        done

        [ $found -eq 0 ] && unique+=("$folder")
    done

    DETECTED_FOLDERS=("${unique[@]}")
}

##############################################################################
# Select best Teams folder
##############################################################################

select_best_folder() {

    local best_score=0
    local best_folder=""

    for folder in "${DETECTED_FOLDERS[@]}"
    do
        local mp4_count
        local thumb_count
        local score

        mp4_count=$(find "$folder" -maxdepth 1 -name "*.mp4" 2>/dev/null | wc -l | tr -d ' ')

        thumb_count=$(
            find "$folder" -maxdepth 1 \( \
                -iname "*.png" -o \
                -iname "*.jpg" -o \
                -iname "*.jpeg" -o \
                -iname "*.webp" \
            \) 2>/dev/null | wc -l | tr -d ' '
        )

        score=0
        score=$((score + mp4_count * 100))
        score=$((score + thumb_count * 20))

        [[ "$folder" == *"MSTeams"* ]] && score=$((score + 5))
        [[ "$folder" == *"com.microsoft.teams2"* ]] && score=$((score + 5))

        if [ "$score" -gt "$best_score" ]
        then
            best_score=$score
            best_folder="$folder"
        fi
    done

    TEAMS_FOLDER="$best_folder"
}

##############################################################################
# List background slots
##############################################################################

list_slots() {

    SLOTS=()

    echo
    echo "Available Teams Background Slots"
    echo "================================"
    echo

    local count=1

    while IFS= read -r file
    do
        SLOTS+=("$file")

        echo "$count) $(basename "$file")"

        count=$((count + 1))

    done < <(
        find "$TEAMS_FOLDER" \
            -maxdepth 1 \
            -name "*.mp4" \
            | sort
    )

    echo
}

##############################################################################
# Select slot
##############################################################################

select_slot() {

    read -p "Select slot: " slot_num

    if ! [[ "$slot_num" =~ ^[0-9]+$ ]]
    then
        echo "Invalid selection."
        exit 1
    fi

    slot_index=$((slot_num - 1))

    TARGET_FILE="${SLOTS[$slot_index]}"

    if [ ! -f "$TARGET_FILE" ]
    then
        echo "Invalid slot."
        exit 1
    fi
}

##############################################################################
# Select replacement MP4
##############################################################################

select_video() {

    SELECTED_FILE=$(osascript <<EOF
set chosenFile to choose file of type {"public.mpeg-4"} with prompt "Choose replacement video"
POSIX path of chosenFile
EOF
)

    if [ -z "$SELECTED_FILE" ]
    then
        echo "No file selected."
        exit 1
    fi
}

##############################################################################
# Backup original (only once)
##############################################################################

backup_original() {

    local filename
    filename=$(basename "$TARGET_FILE")

    local backup_file="$BACKUP_DIR/$filename"

    if [ ! -f "$backup_file" ]
    then
        echo
        echo "Backing up original..."

        cp "$TARGET_FILE" "$backup_file"

        echo "Saved:"
        echo "$backup_file"
    else
        echo
        echo "Original already backed up."
    fi
}

##############################################################################
# Replace video
##############################################################################

replace_video() {

    echo
    echo "Installing custom video..."

    # Verify the selected video is readable
    if [ "$FFMPEG_AVAILABLE" -eq 1 ]; then
        if ! ffprobe -v error "$SELECTED_FILE" >/dev/null 2>&1
        then
            echo
            echo "The selected file is not a valid MP4 video."
            return 1
        fi
    fi


    cp -f "$SELECTED_FILE" "$TARGET_FILE"

    echo
    echo "Done."
    echo
    echo "Replaced:"
    echo "$(basename "$TARGET_FILE")"
}



##############################################################################
# Regenerate thumbnail
##############################################################################

generate_thumbnail() {

    [ "$FFMPEG_AVAILABLE" -eq 0 ] && return

    local thumb=""

    for ext in png jpg jpeg webp
        do
            if [ -f "${TARGET_FILE%.mp4}.$ext" ]
            then
                thumb="${TARGET_FILE%.mp4}.$ext"
                break
            fi
        done

    [ -z "$thumb" ] && thumb="${TARGET_FILE%.mp4}.png"

    echo
    echo "Generating thumbnail..."

    duration=$(ffprobe \
    -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$TARGET_FILE")

    time=$(awk "BEGIN {print $duration*0.2}")

    ffmpeg \
        -y \
        -ss "$time" \
        -i "$TARGET_FILE" \
        -frames:v 1 \
        -q:v 2 \
        -vf "scale=320:-1" \
        "$thumb" \
        >/dev/null 2>&1

    if [ -f "$thumb" ]
    then
        echo "Thumbnail updated."
    else
        echo "Unable to generate thumbnail."
    fi
}



restore_originals() {

    echo
    echo "Restore all original Teams backgrounds?"
    echo
    read -p "[y/N]: " answer

    case "$answer" in
        y|Y)

            echo
            echo "Restoring..."

            local restored=0

            while IFS= read -r file
            do
                cp -p "$file" "$TEAMS_FOLDER/"

                restored=$((restored + 1))

            done < <(
                find "$BACKUP_DIR" \
                    -maxdepth 1 \
                    -type f
            )

            echo
            echo "Restore complete."
            echo "Files restored: $restored"
            ;;

        *)
            echo
            echo "Restore cancelled."
            ;;
    esac
}



##############################################################################
# FFmpeg Detection
##############################################################################

check_ffmpeg() {

    FFMPEG_AVAILABLE=0

    if command -v ffmpeg >/dev/null 2>&1
    then
        FFMPEG_AVAILABLE=1
        return
    fi

    echo
    echo "FFmpeg is not installed."
    echo
    echo "Thumbnail regeneration will be unavailable."
    echo
    echo "1) Install via Homebrew"
    echo "2) Continue without FFmpeg"
    echo "3) Exit"
    echo

    read -p "Choose: " ffchoice

    case "$ffchoice" in

        1)

            if ! command -v brew >/dev/null 2>&1
            then
                echo
                echo "Homebrew is not installed."
                echo
                echo "Install Homebrew from:"
                echo "https://brew.sh"
                echo
                exit 1
            fi

            echo
            echo "Installing FFmpeg..."
            echo

            brew install ffmpeg

            if command -v ffmpeg >/dev/null 2>&1
            then
                FFMPEG_AVAILABLE=1
            else
                echo
                echo "FFmpeg installation failed."
                exit 1
            fi
            ;;

        2)

            FFMPEG_AVAILABLE=0
            ;;

        *)

            exit 0
            ;;
    esac
}




##############################################################################
# Main
##############################################################################


discover_teams_folders

if [ ${#DETECTED_FOLDERS[@]} -eq 0 ]
then
    echo "No Teams Backgrounds folder found."
    exit 1
fi

select_best_folder
check_ffmpeg

while true
do


    echo
    echo "Teams Video Background Swapper"
    echo "============================="
    echo
    echo "Using:"
    echo "$TEAMS_FOLDER"
    echo

    if [ "$FFMPEG_AVAILABLE" -eq 1 ]
    then
        echo "FFmpeg: Installed"
    else
        echo "FFmpeg: Not Installed"
    fi

    echo
    echo 1) "Replace Background"
    echo 2) "Restore Originals"
    echo 3) "Show Detected Teams Locations"
    echo 4) "Debug Teams Installation"
    echo 5) "Exit"
    echo

    read -p "Choose: " choice

    case "$choice" in

        1)

            list_slots
            select_slot
            select_video
            backup_original
	    if replace_video
               then
               generate_thumbnail
            fi
            ;;

        2)

            restore_originals
            ;;

        3)

            exit 0
            ;;

        *)

            echo
            echo "Invalid selection."
            ;;
    esac

done

