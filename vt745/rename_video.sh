#!/usr/bin/env zsh

# Script to rename video files from dot notation to space notation with year in brackets
# Usage: rename_video <folder_path>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Arrays to store rename operations
declare -a rename_pairs

# Find all video files
echo -e "${YELLOW}Finding video files with dot notation...${NC}"
echo ""

setopt null_glob
for video in *.mkv *.mp4 *.avi *.MKV *.MP4 *.AVI; do
    [ -e "$video" ] || continue
    
    # Get base name without extension
    base="${video%.*}"
    # Get extension
    ext="${video##*.}"
    
    # Check if the base name contains dots (indicating it needs renaming)
    if [[ "$base" == *.* ]]; then
        # Replace dots with spaces
        new_base=$(echo "$base" | sed 's/\./ /g')
        
        # Handle year in brackets - pattern: (YYYY)
        # First check if year is already in brackets at the end
        if [[ $new_base =~ ^(.*)[[:space:]]\(([0-9]{4})\)(.*)$ ]]; then
            # Year already in brackets - keep it as is
            title="${match[1]}"
            year="${match[2]}"
            quality="${match[3]}"
            new_base="$title ($year)$quality"
        # Check for year without brackets at the end
        elif [[ $new_base =~ ^(.*)[[:space:]]([0-9]{4})(.*)$ ]]; then
            # Year without brackets - add them
            title="${match[1]}"
            year="${match[2]}"
            quality="${match[3]}"
            new_base="$title ($year)$quality"
        fi
        
        # Clean up multiple spaces
        new_base=$(echo "$new_base" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
        
        # Construct new filename
        new_filename="$new_base.$ext"
        
        # Only add to rename list if filename changed
        if [[ "$video" != "$new_filename" ]]; then
            rename_pairs+=("$video|$new_filename")
            echo -e "${BLUE}Found:${NC}"
            echo -e "  Current:  $video"
            echo -e "  Rename to: ${GREEN}$new_filename${NC}"
            echo ""
        fi
    fi
done

# Check if there are any renames to perform
if [ ${#rename_pairs} -eq 0 ]; then
    echo -e "${GREEN}No video files need renaming. All files are already properly formatted!${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}Summary: ${#rename_pairs} video file(s) will be renamed${NC}"
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
        echo -e "${GREEN}✓${NC} Renamed: $old_name"
        echo -e "       -> $new_name"
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
