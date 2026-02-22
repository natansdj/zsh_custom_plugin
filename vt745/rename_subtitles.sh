#!/usr/bin/env zsh

# Script to rename subtitle files to match video filenames
# Multi-strategy matching: episode ID, language-aware, title similarity fallback
#
# Usage: rename_subtitles [options] <folder_path>
#   -n, --dry-run    Preview renames without executing them
#   -r, --recursive  Process all subfolders recursively
#   -y, --yes        Auto-confirm without prompting
#   -v, --verbose    Show detailed matching diagnostics

set -uo pipefail
# NOTE: -e (errexit) intentionally omitted — associative array key tests would
#       trigger false exits in zsh strict mode.

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Global flags ─────────────────────────────────────────────────────────────
DRY_RUN=0
RECURSIVE=0
AUTO_YES=0
VERBOSE=0
TOTAL_SUCCESS=0
TOTAL_ERROR=0

# ─── Supported extensions ─────────────────────────────────────────────────────
VIDEO_EXTS=(mkv mp4 avi mov wmv m4v MKV MP4 AVI MOV WMV M4V)
SUBTITLE_EXTS=(srt SRT sub SUB ass ASS ssa SSA vtt VTT)

# ─── Known language codes that may appear before the extension ─────────────────
# e.g.  Show.S01E01.en.srt  |  Show.S01E01.pt-BR.srt  |  Show.S01E01.fre.srt
LANG_CODES=(en EN fr FR de DE es ES pt PT it IT ja JA ko KO zh ZH ru RU
            pl PL nl NL sv SV da DA fi FI nb NB tr TR ar AR hi HI
            pt-BR pt-br en-US en-us en-GB en-gb zh-CN zh-TW
            por eng fre ger spa ita jpn kor chi rus pol nld swe dan fin nor tur ara hin)

# ─── Helpers ──────────────────────────────────────────────────────────────────

log_verbose() {
    [[ $VERBOSE -eq 1 ]] && echo -e "${DIM}    [DBG] $*${NC}"
}

# Extract normalised episode ID → "S01E01"
# Handles: S01E01  s01e01  1x01  101 (3-digit SEEE)  S01E01-E02 (multi-ep)
extract_episode_id() {
    local filename="$1"
    local base="${filename:t:r}"   # basename without extension

    # Pattern 1: SxxExx / sxxexx  (most common)
    if [[ "$base" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
        printf "S%02dE%02d" "$((10#${match[1]}))" "$((10#${match[2]}))"
        return
    fi

    # Pattern 2: NxNN  (e.g. 1x01, 12x05)
    if [[ "$base" =~ (^|[^0-9])([0-9]{1,2})x([0-9]{1,2})([^0-9]|$) ]]; then
        printf "S%02dE%02d" "$((10#${match[2]}))" "$((10#${match[3]}))"
        return
    fi

    # Pattern 3: 3-digit SEEE  (e.g. 101, 212) — only when surrounded by
    #            non-digits to avoid matching years like 2014
    if [[ "$base" =~ (^|[._\- ])([1-9])([0-9]{2})([._\- ]|$) ]]; then
        local s="${match[2]}"
        local ep="${match[3]}"
        printf "S%02dE%02d" "$((10#$s))" "$((10#$ep))"
        return
    fi

    echo ""
}

# Extract language tag from subtitle filename (returns empty if none)
# e.g. "Show.S01E01.en.srt" → "en"
#      "Show.S01E01.pt-BR.srt" → "pt-BR"
#      "Show.S01E01.srt" → ""
extract_lang_tag() {
    local filename="$1"
    local base="${filename:t:r}"   # remove final extension

    # Walk known language codes, check if the filename ends with .<code>
    local code
    for code in "${LANG_CODES[@]}"; do
        if [[ "$base" == *".$code" ]] || [[ "$base" == *"_$code" ]]; then
            echo "$code"
            return
        fi
    done
    echo ""
}

# Normalise a title string for fuzzy comparison:
#   lower-case, replace separators with spaces, collapse whitespace
normalize_title() {
    local t="${1:l}"                       # lower-case
    t="${t//[._\-]/ }"                     # separators → space
    t="${t//[^a-z0-9 ]/}"                  # strip punctuation
    t=$(echo "$t" | tr -s ' ')             # collapse spaces
    t="${t## }"; t="${t%% }"               # trim
    echo "$t"
}

# Extract the episode title segment from a media filename.
# Convention: {series}.{SxxExx}.{title tokens}.{quality}.{codec}-{group}
# Quality tokens to strip: 720p 1080p 2160p 4K HDTV WEB BluRay x264 x265
#                          HEVC AVC AAC AC3 DTS h264 h265 AMZN NF DSNP etc.
extract_title_segment() {
    local filename="$1"
    local base="${filename:t:r}"

    # Remove everything from the first quality/codec token onwards
    # Build a sed pattern for known quality/source/codec markers
    local stripped
    stripped=$(echo "$base" | sed -E \
        's/[[:space:]._-]+(480|576|720|1080|2160)[pPiI][[:space:]._-].*$//' | sed -E \
        's/[[:space:]._-]+(HDTV|WEB|BluRay|Blu-Ray|WEBRip|DVDRip|BDRIP|HDRIP|HDR|SDR|AMZN|NF|DSNP|HULU|ATVP|PCOK)[[:space:]._-].*$//' | sed -E \
        's/[[:space:]._-]+(x264|x265|H\.?264|H\.?265|HEVC|AVC|XviD|DivX)[[:space:]._-].*$//i' | sed -E \
        's/[[:space:]._-]+[0-9]{3,4}[pPiI][[:space:]._-].*$//')

    # Strip the leading series·episode token  (everything up to and incl. SxxExx)
    local title
    title=$(echo "$stripped" | sed -E 's/^.*[Ss][0-9]{1,2}[Ee][0-9]{1,2}[[:space:]._-]*//')

    normalize_title "$title"
}

# Simple word-overlap similarity score between two normalised title strings.
# Returns integer 0-100.
title_similarity() {
    local a="$1" b="$2"
    [[ -z "$a" || -z "$b" ]] && echo 0 && return

    # Split into word arrays
    local -a wa=("${(s: :)a}") wb=("${(s: :)b}")
    local shared=0 w

    for w in "${wa[@]}"; do
        # Skip very short words (articles, etc.)
        [[ ${#w} -lt 3 ]] && continue
        if (( ${wb[(Ie)$w]} )); then
            (( shared++ ))
        fi
    done

    local total=$(( ${#wa} > ${#wb} ? ${#wa} : ${#wb} ))
    (( total == 0 )) && echo 0 && return
    echo $(( shared * 100 / total ))
}

# ─── Process a single folder ───────────────────────────────────────────────────
process_folder() {
    local FOLDER="$1"

    echo -e "\n${BOLD}${BLUE}━━━ Folder: $FOLDER ${NC}"

    # Zsh associative arrays — MUST use (( ${+arr[key]} )) to test existence
    typeset -A video_map       # episode_id  → video filename
    typeset -A video_title_map # episode_id  → normalised title segment
    typeset -A sub_lang_map    # subtitle filename → lang tag (may be empty)
    typeset -A episode_used    # episode_id → subtitle filename already paired
    typeset -a rename_ops      # "old|new|confidence_label" triples

    # ── Scan videos ────────────────────────────────────────────────────────────
    echo -e "\n${YELLOW}▶ Scanning video files…${NC}"
    setopt local_options null_glob
    local video ep_id
    for ext in "${VIDEO_EXTS[@]}"; do
        for video in "$FOLDER"/*.$ext; do
            [[ -f "$video" ]] || continue
            ep_id=$(extract_episode_id "${video:t}")
            if [[ -n "$ep_id" ]]; then
                video_map[$ep_id]="${video:t}"
                video_title_map[$ep_id]=$(extract_title_segment "${video:t}")
                echo -e "  ${GREEN}✓${NC} ${video:t}  ${DIM}[$ep_id]${NC}"
            else
                echo -e "  ${DIM}–${NC} ${video:t}  ${DIM}[no episode ID]${NC}"
            fi
        done
    done

    local video_count=${#video_map}
    echo -e "  ${CYAN}Total: $video_count video(s) with episode IDs${NC}"

    # ── Scan subtitles ─────────────────────────────────────────────────────────
    echo -e "\n${YELLOW}▶ Scanning subtitle files…${NC}"
    local subtitle lang_tag
    typeset -a subtitles_found
    for ext in "${SUBTITLE_EXTS[@]}"; do
        for subtitle in "$FOLDER"/*.$ext; do
            [[ -f "$subtitle" ]] || continue
            subtitles_found+=("${subtitle:t}")
        done
    done

    if (( ${#subtitles_found} == 0 )); then
        echo -e "  ${DIM}No subtitle files found.${NC}"
        return
    fi

    for subtitle in "${subtitles_found[@]}"; do
        ep_id=$(extract_episode_id "$subtitle")
        lang_tag=$(extract_lang_tag "$subtitle")
        if [[ -n "$ep_id" ]]; then
            sub_lang_map[$subtitle]="$lang_tag"
            echo -e "  ${CYAN}✓${NC} $subtitle  ${DIM}[$ep_id${lang_tag:+ | lang: $lang_tag}]${NC}"
        else
            echo -e "  ${DIM}–${NC} $subtitle  ${DIM}[no episode ID]${NC}"
        fi
    done

    # ── Match subtitles to videos ──────────────────────────────────────────────
    echo -e "\n${YELLOW}▶ Matching subtitles → videos…${NC}\n"

    local sub sub_ep sub_ext sub_base new_name video_base confidence lang_suffix
    local v_title s_title sim

    for sub in "${(@k)sub_lang_map}"; do
        sub_ep=$(extract_episode_id "$sub")
        [[ -z "$sub_ep" ]] && continue

        sub_ext="${sub:e}"                      # extension without dot
        lang_tag="${sub_lang_map[$sub]}"
        lang_suffix="${lang_tag:+.$lang_tag}"   # ".en" or ""

        # ── Strategy 1: exact episode ID match ────────────────────────────────
        if (( ${+video_map[$sub_ep]} )); then
            video="${video_map[$sub_ep]}"
            video_base="${video%.*}"
            new_name="${video_base}${lang_suffix}.${sub_ext}"
            confidence="EXACT"

            # ── Strategy 2: cross-check with title similarity ─────────────────
            v_title="${video_title_map[$sub_ep]}"
            s_title=$(extract_title_segment "$sub")
            sim=$(title_similarity "$v_title" "$s_title")
            log_verbose "Title sim [$sub_ep]: '$v_title' vs '$s_title' → $sim%"

            if (( sim > 0 )); then
                confidence="EXACT+TITLE(${sim}%)"
            fi

        # ── Strategy 3: title-only fuzzy fallback ─────────────────────────────
        #    Iterate all videos with same SEASON but try to match by title
        else
            local best_ep="" best_sim=0 best_video="" candidate_ep candidate_v
            s_title=$(extract_title_segment "$sub")
            local sub_season=""
            [[ "$sub_ep" =~ ^S([0-9]+)E ]] && sub_season="${match[1]}"

            for candidate_ep in "${(@k)video_map}"; do
                # Limit search to same season
                local cand_season=""
                [[ "$candidate_ep" =~ ^S([0-9]+)E ]] && cand_season="${match[1]}"
                [[ "$sub_season" != "$cand_season" ]] && continue

                candidate_v="${video_map[$candidate_ep]}"
                v_title="${video_title_map[$candidate_ep]}"
                sim=$(title_similarity "$v_title" "$s_title")
                log_verbose "  Fuzzy [$sub_ep→$candidate_ep]: '$v_title' vs '$s_title' → $sim%"

                if (( sim > best_sim )); then
                    best_sim=$sim
                    best_ep="$candidate_ep"
                    best_video="$candidate_v"
                fi
            done

            # Accept fuzzy match only if similarity ≥ 60%
            if (( best_sim >= 60 )); then
                video="$best_video"
                video_base="${video%.*}"
                new_name="${video_base}${lang_suffix}.${sub_ext}"
                confidence="FUZZY(${best_sim}%)"
                sub_ep="$best_ep"
            else
                echo -e "  ${RED}✗ No match${NC}: $sub  ${DIM}[$sub_ep]${NC}"
                if (( best_sim > 0 )); then
                    echo -e "    ${DIM}Best fuzzy candidate: '${video_title_map[$best_ep]:-?}' @ ${best_sim}% — below threshold${NC}"
                fi
                echo ""
                continue
            fi
        fi

        # Skip if already identical
        if [[ "$sub" == "$new_name" ]]; then
            echo -e "  ${DIM}= Already correct:${NC} $sub"
            continue
        fi

        # Handle duplicate: same video+lang already claimed
        local dedup_key="${sub_ep}${lang_suffix}"
        if (( ${+episode_used[$dedup_key]} )); then
            echo -e "  ${YELLOW}⚠ Duplicate${NC} [$dedup_key]: $sub"
            echo -e "    ${DIM}Skipped — '${episode_used[$dedup_key]}' already claims this slot${NC}"
            echo ""
            continue
        fi

        episode_used[$dedup_key]="$sub"
        rename_ops+=("$sub|$new_name|$confidence")

        local conf_color="$GREEN"
        [[ "$confidence" == FUZZY* ]] && conf_color="$YELLOW"
        echo -e "  ${conf_color}[$confidence]${NC} $sub"
        echo -e "    ${DIM}→${NC} ${GREEN}$new_name${NC}"
        echo ""
    done

    # ── Summary & execution ────────────────────────────────────────────────────
    if (( ${#rename_ops} == 0 )); then
        echo -e "${GREEN}✓ Nothing to rename — all subtitles already match their videos.${NC}"
        return
    fi

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ${#rename_ops} subtitle(s) queued for rename${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if (( DRY_RUN )); then
        echo -e "${MAGENTA}[DRY-RUN] No files will be changed.${NC}\n"
        for op in "${(@)rename_ops}"; do
            local old="${op%%|*}" rest="${op#*|}"
            local new="${rest%%|*}" conf="${rest##*|}"
            echo -e "  ${DIM}would rename:${NC} $old  →  $new  ${DIM}[$conf]${NC}"
        done
        echo ""
        return
    fi

    # Confirm unless --yes
    if (( ! AUTO_YES )); then
        read "REPLY?  Proceed with renaming? (yes/no): "
        echo ""
        if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
            echo -e "${RED}Renaming cancelled.${NC}"
            return
        fi
    fi

    local ok=0 fail=0
    for op in "${(@)rename_ops}"; do
        local old="${op%%|*}" rest="${op#*|}"
        local new="${rest%%|*}" conf="${rest##*|}"
        local old_path="$FOLDER/$old" new_path="$FOLDER/$new"

        if [[ -e "$new_path" && "$old_path" != "$new_path" ]]; then
            echo -e "  ${RED}✗ Target exists:${NC} $new"
            (( fail++ )) || true
            continue
        fi
        if mv -- "$old_path" "$new_path" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $old  →  $new  ${DIM}[$conf]${NC}"
            (( ok++ )) || true
        else
            echo -e "  ${RED}✗ Failed:${NC} $old"
            (( fail++ )) || true
        fi
    done

    echo ""
    echo -e "  ${GREEN}Renamed: $ok${NC}  ${RED}Failed: $fail${NC}"
    (( TOTAL_SUCCESS += ok ))
    (( TOTAL_ERROR   += fail ))
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
POSITIONAL_ARGS=()
while (( $# )); do
    case "$1" in
        -n|--dry-run)   DRY_RUN=1   ; shift ;;
        -r|--recursive) RECURSIVE=1  ; shift ;;
        -y|--yes)       AUTO_YES=1   ; shift ;;
        -v|--verbose)   VERBOSE=1    ; shift ;;
        -h|--help)
            echo "Usage: ${0:t} [options] <folder>"
            echo "  -n, --dry-run    Preview only, no files changed"
            echo "  -r, --recursive  Process subfolders too"
            echo "  -y, --yes        Auto-confirm renames"
            echo "  -v, --verbose    Show matching diagnostics"
            exit 0 ;;
        -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
        *)  POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

if (( ${#POSITIONAL_ARGS} == 0 )); then
    echo -e "${RED}Error: No folder path provided${NC}"
    echo "Usage: ${0:t} [options] <folder_path>"
    exit 1
fi

ROOT_FOLDER="${POSITIONAL_ARGS[1]}"

if [[ ! -d "$ROOT_FOLDER" ]]; then
    echo -e "${RED}Error: '$ROOT_FOLDER' is not a directory${NC}"
    exit 1
fi

# ─── Entry point ──────────────────────────────────────────────────────────────
if (( RECURSIVE )); then
    # Process root folder + all subdirectories
    setopt null_glob
    process_folder "$ROOT_FOLDER"
    local sub_dir
    for sub_dir in "$ROOT_FOLDER"/**/*(N/); do
        process_folder "$sub_dir"
    done
else
    process_folder "$ROOT_FOLDER"
fi

if (( RECURSIVE )); then
    echo -e "\n${BOLD}${YELLOW}━━━ Grand Total ━━━${NC}"
    echo -e "  ${GREEN}Renamed: $TOTAL_SUCCESS${NC}  ${RED}Failed: $TOTAL_ERROR${NC}\n"
fi
