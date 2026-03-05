#!/usr/bin/env bash
# =============================================================================
# exiftool.sh — ExifTool GPS Geotagging Helper
# =============================================================================
# Purpose    : Geotag images/videos from a GPS track log using ExifTool.
#              Supports geosync (clock-drift correction) and custom geotime
#              to ensure accurate GPS positioning for each image.
# Requires   : exiftool (https://exiftool.org)
# Author     : vt745 plugin
# Usage      : See exiftool_README.md or run: ./exiftool.sh --help
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
GPS_LOG=""                  # GPS track log file (required for geotag mode)
TARGET=""                   # Target image file, directory, or glob (required)
GEOSYNC_VALUES=()              # Time offsets or sync references (optional, multiple allowed)
GEOTIME_VALUE=""            # Override Geotime source tag (optional)
TIMEZONE=""                 # Timezone to apply to Geotime (e.g. +07:00)
TAG_GROUP=""                # Force tag group: exif | xmp | quicktime
DATE_TAG="DateTimeOriginal" # Date tag used when GEOTIME_VALUE is not set
RECURSIVE=false             # Process directories recursively (-r)
DRY_RUN=false               # Preview changes without writing
VERBOSE=false               # Enable -v2 verbosity
PRESERVE_DATES=false        # Preserve FileModifyDate after write
DELETE_TAGS=false           # Delete GPS tags written by geotag
EXTRA_LOGS=()               # Additional GPS log files
MAX_INT_SECS=""             # GeoMaxIntSecs API option
MAX_EXT_SECS=""             # GeoMaxExtSecs API option
BACKUP=true                 # Create ExifTool backup files (_original)
GEOLOCATION=false           # Auto-write city/state/country alongside GPS

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }
divider() { echo -e "${BOLD}─────────────────────────────────────────────────${RESET}"; }

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
check_deps() {
    if ! command -v exiftool &>/dev/null; then
        die "exiftool is not installed. Install it from https://exiftool.org or via your package manager."
    fi
}

# ---------------------------------------------------------------------------
# Usage / Help
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF

${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${RESET} — ExifTool GPS Geotagging Helper

${BOLD}SYNOPSIS${RESET}
  $SCRIPT_NAME [OPTIONS] -l <track.log> <target>

${BOLD}CORE OPTIONS${RESET}
  -l, --log    <file>      GPS track log file (GPX, NMEA, KML, CSV, …)
                           May be specified multiple times for multiple logs.
  -t, --target <path>      Image file, directory, or glob pattern to geotag.
  -o, --output-group <grp> Force tag group: exif | xmp | quicktime  (default: exif)

${BOLD}GEOSYNC OPTIONS${RESET}  (synchronise camera clock to GPS time)
  -s, --geosync <value>    Time offset applied before GPS lookup. Formats:
                             +SS / -SS           seconds (e.g. +25 or -80)
                             +MM:SS / -MM:SS     minutes and seconds
                             +HH:MM:SS           hours, minutes, seconds
                             <gps_time>@<img.jpg>  extract sync from file pair
                             <gps_time>@<img_time> explicit GPS/camera pair
                           Specify multiple times for clock-drift correction.

${BOLD}GEOTIME OPTIONS${RESET}  (select which camera timestamp drives GPS lookup)
  -g, --geotime <tag>      ExifTool tag to use as reference time for GPS
                           interpolation. Default: DateTimeOriginal (with
                           SubSecDateTimeOriginal preferred when available).
                           Examples: CreateDate  FileModifyDate
  -z, --timezone <tz>      Append timezone to Geotime (e.g. +07:00, -05:00).
                           Use when images lack embedded timezone info.

${BOLD}ACCURACY OPTIONS${RESET}
  --max-int-secs <N>       Max interpolation gap in seconds (default: 1800).
  --max-ext-secs <N>       Max extrapolation distance in seconds (default: 1800).

${BOLD}WRITE / BEHAVIOUR OPTIONS${RESET}
  -r, --recursive          Process directory tree recursively.
  -n, --no-backup          Do NOT create ExifTool _original backup files.
  -P, --preserve-dates     Preserve FileModifyDate after rewrite.
  -d, --delete             Delete GPS tags previously written by geotag.
      --geolocation        Also write city / state / country from GPS position.
  -v, --verbose            Enable verbose ExifTool output (-v2).
      --dry-run            Print the ExifTool command without executing it.

${BOLD}OTHER${RESET}
  -h, --help               Show this help.
      --version            Show version.

${BOLD}EXAMPLES${RESET}
  # Basic geotag from a GPX file
  $SCRIPT_NAME -l track.gpx ./photos/

  # Geotag with a 25-second camera clock offset (camera was 25 s slow)
  $SCRIPT_NAME -l track.gpx -s +25 ./photos/

  # Geotag with timezone and specific date tag
  $SCRIPT_NAME -l track.gpx -z +07:00 -g CreateDate ./photos/

  # Dry-run to preview the command
  $SCRIPT_NAME --dry-run -l track.gpx -s +00:01:30 ./photos/

  # Delete GPS tags previously written by geotag
  $SCRIPT_NAME --delete ./photos/photo.jpg

  # Multiple logs + clock-drift via reference images
  $SCRIPT_NAME -l morning.gpx -l afternoon.gpx -s ref1.jpg -s ref2.jpg -r ./photos/

  # XMP tags only + geolocation (city/state/country)
  $SCRIPT_NAME -l track.gpx -o xmp --geolocation ./photos/

  # Preserve FileModifyDate and skip backup
  $SCRIPT_NAME -l track.gpx -P -n ./photos/

EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    [[ $# -eq 0 ]] && { usage; exit 0; }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--log)
                if [[ -z "${2:-}" ]]; then die "--log requires a value"; fi
                if [[ -z "$GPS_LOG" ]]; then
                    GPS_LOG="$2"
                else
                    EXTRA_LOGS+=("$2")
                fi
                shift 2 ;;
            -t|--target)
                if [[ -z "${2:-}" ]]; then die "--target requires a value"; fi
                TARGET="$2"; shift 2 ;;
            -s|--geosync)
                if [[ -z "${2:-}" ]]; then die "--geosync requires a value"; fi
                GEOSYNC_VALUES+=("$2"); shift 2 ;;
            -g|--geotime)
                if [[ -z "${2:-}" ]]; then die "--geotime requires a value"; fi
                GEOTIME_VALUE="$2"; shift 2 ;;
            -z|--timezone)
                if [[ -z "${2:-}" ]]; then die "--timezone requires a value"; fi
                TIMEZONE="$2"; shift 2 ;;
            -o|--output-group)
                if [[ -z "${2:-}" ]]; then die "--output-group requires a value"; fi
                TAG_GROUP="$(echo "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;; # lowercase
            --max-int-secs)
                if [[ -z "${2:-}" ]]; then die "--max-int-secs requires a value"; fi
                MAX_INT_SECS="$2"; shift 2 ;;
            --max-ext-secs)
                if [[ -z "${2:-}" ]]; then die "--max-ext-secs requires a value"; fi
                MAX_EXT_SECS="$2"; shift 2 ;;
            -r|--recursive)   RECURSIVE=true;       shift ;;
            -n|--no-backup)   BACKUP=false;          shift ;;
            -P|--preserve-dates) PRESERVE_DATES=true; shift ;;
            -d|--delete)      DELETE_TAGS=true;      shift ;;
            --geolocation)    GEOLOCATION=true;      shift ;;
            -v|--verbose)     VERBOSE=true;          shift ;;
            --dry-run)        DRY_RUN=true;          shift ;;
            -h|--help)        usage; exit 0 ;;
            --version)        echo "$SCRIPT_NAME v$SCRIPT_VERSION"; exit 0 ;;
            -*)               die "Unknown option: $1. Run '$SCRIPT_NAME --help' for usage." ;;
            *)
                # Treat bare positional argument as target if not yet set
                if [[ -z "$TARGET" ]]; then
                    TARGET="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
validate_args() {
    # Delete mode only needs a target
    if $DELETE_TAGS; then
        if [[ -z "$TARGET" ]]; then die "Provide a target file or directory when using --delete."; fi
        return 0
    fi

    if [[ -z "$GPS_LOG" ]]; then die "GPS track log (-l) is required. Run '$SCRIPT_NAME --help'."; fi
    if [[ -z "$TARGET" ]];  then die "Target path is required. Run '$SCRIPT_NAME --help'."; fi

    # Validate log file exists (skip glob patterns and dry-run mode)
    if ! $DRY_RUN && [[ "$GPS_LOG" != *"*"* && "$GPS_LOG" != *"?"* ]]; then
        if [[ ! -f "$GPS_LOG" ]]; then die "GPS log file not found: $GPS_LOG"; fi
    fi

    # Validate tag group
    if [[ -n "$TAG_GROUP" ]]; then
        case "$TAG_GROUP" in
            exif|xmp|quicktime) ;;
            *) die "Invalid tag group '$TAG_GROUP'. Use: exif, xmp, or quicktime." ;;
        esac
    fi

    # Validate timezone format (loose check: +/-HH:MM)
    if [[ -n "$TIMEZONE" && ! "$TIMEZONE" =~ ^[+-][0-9]{2}:[0-9]{2}$ ]]; then
        warn "Timezone '$TIMEZONE' looks unusual. Expected format: +HH:MM or -HH:MM"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Build ExifTool command into global CMD_ARGS array
# ---------------------------------------------------------------------------
CMD_ARGS=()

build_cmd() {
    CMD_ARGS=(exiftool)

    # ── Deletion mode ──────────────────────────────────────────────
    if $DELETE_TAGS; then
        local prefix=""
        if [[ -n "$TAG_GROUP" ]]; then prefix="${TAG_GROUP}:"; fi
        CMD_ARGS+=("-${prefix}geotag=")
        if $RECURSIVE;       then CMD_ARGS+=("-r");                  fi
        if $PRESERVE_DATES;  then CMD_ARGS+=("-P");                  fi
        if $VERBOSE;         then CMD_ARGS+=("-v2");                 fi
        if ! $BACKUP;        then CMD_ARGS+=("-overwrite_original"); fi
        CMD_ARGS+=("$TARGET")
        return
    fi

    # ── Primary GPS log ────────────────────────────────────────────
    CMD_ARGS+=("-geotag" "$GPS_LOG")

    # ── Additional GPS logs ────────────────────────────────────────
    for extra_log in "${EXTRA_LOGS[@]:-}"; do
        if [[ -n "$extra_log" ]]; then CMD_ARGS+=("-geotag" "$extra_log"); fi
    done

    # ── Geosync (time offset / clock-drift) ────────────────────────
    for gsync in "${GEOSYNC_VALUES[@]:-}"; do
        if [[ -n "$gsync" ]]; then CMD_ARGS+=("-geosync=$gsync"); fi
    done

    # ── Geotime (reference timestamp) ──────────────────────────────
    # ExifTool copy-tag syntax: -Geotime<${TagName}+07:00
    # The shell must NOT expand ${TagName}, so we store it using single-quote form
    # for display; when executing we pass the literal string as an array element.
    local geotime_tag="Geotime"
    if [[ -n "$TAG_GROUP" ]]; then geotime_tag="${TAG_GROUP}:${geotime_tag}"; fi

    if [[ -n "$GEOTIME_VALUE" ]]; then
        if [[ "$GEOTIME_VALUE" =~ ^[0-9]{4}: ]]; then
            # Datetime literal e.g. "2024:06:01 12:00:00+07:00"
            CMD_ARGS+=("-${geotime_tag}=${GEOTIME_VALUE}${TIMEZONE}")
        else
            # Tag name — use ExifTool copy syntax (literal ${TagName})
            if [[ -n "$TIMEZONE" ]]; then
                CMD_ARGS+=("-${geotime_tag}<\${${GEOTIME_VALUE}}${TIMEZONE}")
            else
                CMD_ARGS+=("-${geotime_tag}<${GEOTIME_VALUE}")
            fi
        fi
    else
        # Default: rely on exiftool's built-in SubSecDateTimeOriginal / DateTimeOriginal
        # Override only when timezone or group prefix is needed
        if [[ -n "$TIMEZONE" || -n "$TAG_GROUP" ]]; then
            if [[ -n "$TIMEZONE" ]]; then
                CMD_ARGS+=("-${geotime_tag}<\${${DATE_TAG}}${TIMEZONE}")
            else
                CMD_ARGS+=("-${geotime_tag}<${DATE_TAG}")
            fi
        fi
    fi

    # ── Geolocation (city / state / country) ───────────────────────
    if $GEOLOCATION; then CMD_ARGS+=("-geolocate=geotag"); fi

    # ── Accuracy API options ───────────────────────────────────────
    if [[ -n "$MAX_INT_SECS" ]]; then CMD_ARGS+=("-api" "GeoMaxIntSecs=${MAX_INT_SECS}"); fi
    if [[ -n "$MAX_EXT_SECS" ]]; then CMD_ARGS+=("-api" "GeoMaxExtSecs=${MAX_EXT_SECS}"); fi

    # ── Behaviour flags ────────────────────────────────────────────
    if $RECURSIVE;      then CMD_ARGS+=("-r");                  fi
    if $PRESERVE_DATES; then CMD_ARGS+=("-P");                  fi
    if $VERBOSE;        then CMD_ARGS+=("-v2");                 fi
    if ! $BACKUP;       then CMD_ARGS+=("-overwrite_original"); fi

    # ── Target ─────────────────────────────────────────────────────
    CMD_ARGS+=("$TARGET")
}

# ---------------------------------------------------------------------------
# Summary banner
# ---------------------------------------------------------------------------
print_summary() {
    divider
    echo -e "${BOLD}ExifTool Geotagging Summary${RESET}"
    divider
    if $DELETE_TAGS; then
        echo -e "  Mode       : ${YELLOW}DELETE GPS tags${RESET}"
    else
        echo -e "  Mode       : ${GREEN}GEOTAG${RESET}"
        echo    "  GPS Log    : $GPS_LOG"
        if [[ ${#EXTRA_LOGS[@]} -gt 0 ]]; then echo "  Extra Logs : ${EXTRA_LOGS[*]}"; fi
        if [[ ${#GEOSYNC_VALUES[@]} -gt 0 ]]; then
            echo "  Geosync    : ${GEOSYNC_VALUES[*]}"
        fi
        if [[ -n "$GEOTIME_VALUE" ]]; then
            echo "  Geotime    : $GEOTIME_VALUE"
        else
            echo "  Geotime    : (default: DateTimeOriginal)"
        fi
        if [[ -n "$TIMEZONE"     ]]; then echo "  Timezone   : $TIMEZONE";                  fi
        if [[ -n "$TAG_GROUP"    ]]; then echo "  Tag Group  : $TAG_GROUP";                  fi
        if $GEOLOCATION;             then echo "  Geolocation: yes (city/state/country)";    fi
        if [[ -n "$MAX_INT_SECS" ]]; then echo "  MaxIntSecs : $MAX_INT_SECS";              fi
        if [[ -n "$MAX_EXT_SECS" ]]; then echo "  MaxExtSecs : $MAX_EXT_SECS";              fi
    fi
    echo    "  Target     : $TARGET"
    if $RECURSIVE;      then echo "  Recursive  : yes";                                              fi
    if $PRESERVE_DATES; then echo "  Preserve   : FileModifyDate";                                  fi
    if ! $BACKUP;       then echo "  Backup     : disabled (overwrite_original)";                   fi
    if $VERBOSE;        then echo "  Verbose    : yes";                                             fi
    if $DRY_RUN;        then echo -e "  ${YELLOW}DRY RUN${RESET}    : command will NOT be executed"; fi
    divider
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    check_deps
    parse_args "$@"
    validate_args
    print_summary
    build_cmd

    if $DRY_RUN; then
        echo -e "\n${BOLD}Generated ExifTool command:${RESET}"
        # Pretty-print: quote args containing spaces, $, or < to aid readability
        local display_args=()
        for arg in "${CMD_ARGS[@]}"; do
            if [[ "$arg" == *" "* || "$arg" == *'$'* || "$arg" == *"<"* ]]; then
                display_args+=("'${arg}'")
            else
                display_args+=("${arg}")
            fi
        done
        echo -e "  ${CYAN}${display_args[*]}${RESET}\n"
        exit 0
    fi

    info "Running ExifTool…"
    echo

    # Execute directly via array — preserves all argument quoting correctly
    "${CMD_ARGS[@]}"

    echo
    ok "Done."
    divider
}

main "$@"
