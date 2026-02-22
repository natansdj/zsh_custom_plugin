#!/usr/bin/env zsh

# Script to rename subtitle files to match video filenames
# Usage: rename_subtitle <folder_path>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to extract episode identifier (e.g., S01E01, S02E15, etc.)
extract_episode_id() {
    local filename="$1"
    # Match patterns like S01E01, s01e01, 1x01, etc.
    # In zsh, regex matches are stored in $match array, not BASH_REMATCH
    if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
        # Normalize to uppercase SxxExx format
        # Use 10# prefix to force base-10 interpretation (avoid octal issues with 08, 09)
        printf "S%02dE%02d" "$((10#${match[1]}))" "$((10#${match[2]}))"
    elif [[ "$filename" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
        # Handle 1x01 format
        printf "S%02dE%02d" "$((10#${match[1]}))" "$((10#${match[2]}))"
    else
        echo ""
    fi
}

# Check if folder path is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No folder path provided${NC}"
    echo "Usage: $0 <folder_path>"
    exit 1
fi

FOLDER="$1"

# Check if folder exists
if [ ! -d "$FOLDER" ]; then
    echo -e "${RED}Error: Folder '$FOLDER' does not exist${NC}"
    exit 1
fi

echo -e "${BLUE}Analyzing folder: $FOLDER${NC}"
echo ""

# Change to the target directory
cd "$FOLDER"

# Declare associative arrays
declare -A video_files    # episode_id -> video filename
declare -A subtitle_files # subtitle filename -> episode_id
declare -A episode_processed # episode_id -> 1 if already processed
declare -a rename_pairs   # Array to store rename operations

# Find all video files
echo -e "${YELLOW}Finding video files...${NC}"
setopt null_glob
for video in *.mkv *.mp4 *.avi *.MKV *.MP4 *.AVI; do
    [ -e "$video" ] || continue
    episode_id=$(extract_episode_id "$video")
    if [ -n "$episode_id" ]; then
        video_files["$episode_id"]="$video"
        echo -e "  ${GREEN}✓${NC} Found video: $video [$episode_id]"
    fi
done

echo ""
echo -e "${YELLOW}Finding subtitle files...${NC}"

# Find all subtitle files
for subtitle in *.srt *.SRT *.sub *.SUB; do
    [ -e "$subtitle" ] || continue
    episode_id=$(extract_episode_id "$subtitle")
    if [ -n "$episode_id" ]; then
        subtitle_files["$subtitle"]="$episode_id"
        echo -e "  Found subtitle: $subtitle [$episode_id]"
    fi
done

echo ""
echo -e "${YELLOW}Matching subtitles with videos...${NC}"
echo ""

# Match subtitles with videos
for subtitle in "${(@k)subtitle_files}"; do
    episode_id="${subtitle_files[$subtitle]}"
    
    # Check if we have a video file for this episode
    if [ -n "${video_files[$episode_id]:-}" ]; then
        video="${video_files[$episode_id]}"
        video_basename="${video%.*}"
        new_subtitle_name="${video_basename}.srt"
        
        # Only suggest rename if the subtitle name is different
        if [ "$subtitle" != "$new_subtitle_name" ]; then
            # Check if we've already processed this episode
            if [ -n "${episode_processed[$episode_id]:-}" ]; then
                echo -e "${YELLOW}⚠ Duplicate subtitle for episode $episode_id:${NC}"
                echo -e "  Skipping: $subtitle"
                echo -e "  (Another subtitle for this episode will be renamed)"
                echo ""
            else
                rename_pairs+=("$subtitle|$new_subtitle_name")
                episode_processed[$episode_id]=1
                echo -e "${BLUE}Match found for episode $episode_id:${NC}"
                echo -e "  Current:  $subtitle"
                echo -e "  Rename to: ${GREEN}$new_subtitle_name${NC}"
                echo ""
            fi
        fi
    else
        echo -e "${RED}No video file found for subtitle: $subtitle [$episode_id]${NC}"
        echo ""
    fi
done

# Check if there are any renames to perform
if [ ${#rename_pairs} -eq 0 ]; then
    echo -e "${GREEN}No subtitle files need renaming. All subtitles already match their video files!${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}Summary: ${#rename_pairs} subtitle file(s) will be renamed${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""

# Ask for confirmation
read "?Do you want to proceed with renaming? (yes/no): " REPLY
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Renaming cancelled.${NC}"
    exit 0
fi

# Perform the renaming
echo -e "${GREEN}Renaming files...${NC}"
echo ""

success_count=0
error_count=0

for pair in "${(@)rename_pairs}"; do
    IFS='|' read -r old_name new_name <<< "$pair"
    
    # Check if target file already exists
    if [ -e "$new_name" ] && [ "$old_name" != "$new_name" ]; then
        echo -e "${RED}✗ Error: Target file already exists: $new_name${NC}"
        error_count=$((error_count + 1))
        continue
    fi
    
    # Perform the rename
    if mv "$old_name" "$new_name" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Renamed: $old_name -> $new_name"
        success_count=$((success_count + 1))
    else
        echo -e "${RED}✗ Error renaming: $old_name${NC}"
        error_count=$((error_count + 1))
    fi
done

echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${GREEN}Successfully renamed: $success_count file(s)${NC}"
if [ $error_count -gt 0 ]; then
    echo -e "${RED}Failed: $error_count file(s)${NC}"
fi
echo -e "${YELLOW}================================================${NC}"
