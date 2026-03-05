#!/usr/bin/env bash
# =============================================================================
# exiftool.sh — ExifTool GPS Geotagging Helper
# =============================================================================
# Purpose    : GPS tools for images/videos using ExifTool:
#              1. Geotag from GPS track log (Geotag/Geosync/Geotime tags)
#              2. Write GPS coordinates directly (no track log)
#              3. Read & display all metadata (with optional GPS-only filter)
#              4. Extract GPS track from images into a GPX file
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
GPS_LAT=""                  # Direct latitude  (decimal degrees, e.g. -6.2088)
GPS_LON=""                  # Direct longitude (decimal degrees, e.g. 106.8456)
GPS_ALT=""                  # Direct altitude  (metres, e.g. 10 or -5 for below sea level)
READ_MODE=false             # Read and display metadata without writing
GPS_ONLY=false              # With --read: show GPS tags only
EXTRACT_GPX=false           # Extract GPS track from images into a GPX file
GPX_OUTPUT="track.gpx"      # Output filename for --extract-gpx
GPX_FMT_TMP=""              # Runtime temp file for GPX format template (auto-set)
GPX_CFG_TMP=""              # Runtime temp file for ExifTool config  (auto-set)

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
  $SCRIPT_NAME [OPTIONS] -l <track.log> <target>           # geotag from GPS log
  $SCRIPT_NAME [OPTIONS] --apply-gpx <track.gpx> <target>  # apply GPX → write EXIF GPS
  $SCRIPT_NAME [OPTIONS] --lat <N> --lon <N> <target>       # direct GPS coordinates
  $SCRIPT_NAME [OPTIONS] --read [--gps-only] <target>       # read / inspect metadata
  $SCRIPT_NAME [OPTIONS] --extract-gpx <target>             # extract GPS → GPX track

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

${BOLD}DIRECT GPS OPTIONS${RESET}  (write coordinates without a track log)
  --lat <degrees>          Latitude  in decimal degrees. Positive = North, negative = South.
                           Example: --lat -6.2088   (Jakarta South)
  --lon <degrees>          Longitude in decimal degrees. Positive = East,  negative = West.
                           Example: --lon 106.8456
  --alt <metres>           Altitude  in metres above sea level (negative = below).
                           Example: --alt 10
  Mutually exclusive with -l / --log (cannot combine track log + direct coords).

${BOLD}READ OPTIONS${RESET}  (display metadata without writing)
  --read                   Show all metadata tags for target file(s).
  --gps-only               Show GPS tags only (implies --read).

${BOLD}EXTRACT GPX OPTIONS${RESET}  (build a GPX track from embedded GPS in images/videos)
  --extract-gpx            Extract GPS coords from images and write a GPX track.
  --gpx-output <file>      Output GPX file path.  (default: track.gpx)

${BOLD}APPLY GPX OPTIONS${RESET}  (write GPS from a GPX track log into image EXIF metadata)
  --apply-gpx <file>       Apply a GPX track file to images — writes GPS coordinates
                           (and optionally speed/track/altitude) into EXIF tags.
                           Alias for -l / --log; supports all Geosync/Geotime options.
                           Combine with -z <tz> when images lack an embedded timezone.

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

  # Write GPS coordinates directly (no track log)
  $SCRIPT_NAME --lat -6.2088 --lon 106.8456 ./photos/DSC_0001.jpg

  # Direct coords with altitude and geolocation tags
  $SCRIPT_NAME --lat -6.2088 --lon 106.8456 --alt 10 --geolocation ./photos/

  # Read all metadata from an image
  $SCRIPT_NAME --read ./photos/DSC_0001.jpg

  # Read GPS tags only
  $SCRIPT_NAME --gps-only ./photos/DSC_0001.jpg

  # Extract GPS track from all tagged photos into a GPX file
  $SCRIPT_NAME --extract-gpx ./photos/

  # Extract GPX recursively with a custom output filename
  $SCRIPT_NAME --extract-gpx -r --gpx-output trip.gpx ./photos/

  # Apply a GPX file to write GPS coordinates into image EXIF metadata
  $SCRIPT_NAME --apply-gpx track.gpx ./photos/

  # Apply GPX with a timezone offset (camera clock was in local time)
  $SCRIPT_NAME --apply-gpx track.gpx -z +07:00 ./photos/

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
            --lat|--latitude)
                if [[ -z "${2:-}" ]]; then die "--lat requires a decimal degree value"; fi
                GPS_LAT="$2"; shift 2 ;;
            --lon|--longitude)
                if [[ -z "${2:-}" ]]; then die "--lon requires a decimal degree value"; fi
                GPS_LON="$2"; shift 2 ;;
            --alt|--altitude)
                if [[ -z "${2:-}" ]]; then die "--alt requires a value in metres"; fi
                GPS_ALT="$2"; shift 2 ;;
            --read)        READ_MODE=true; shift ;;
            --gps-only)    GPS_ONLY=true; READ_MODE=true; shift ;;
            --extract-gpx) EXTRACT_GPX=true; shift ;;
            --gpx-output)
                if [[ -z "${2:-}" ]]; then die "--gpx-output requires a filename"; fi
                GPX_OUTPUT="$2"; shift 2 ;;
            --apply-gpx)
                # Semantic alias for -l / --log: applies a GPX track to write GPS into EXIF
                if [[ -z "${2:-}" ]]; then die "--apply-gpx requires a GPX file path"; fi
                if [[ -z "$GPS_LOG" ]]; then GPS_LOG="$2"; else EXTRA_LOGS+=("$2"); fi
                shift 2 ;;
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
    # Read / extract-gpx modes only need a target
    if $READ_MODE || $EXTRACT_GPX; then
        if [[ -z "$TARGET" ]]; then die "Target path is required. Run '$SCRIPT_NAME --help'."; fi
        return 0
    fi

    # Delete mode only needs a target
    if $DELETE_TAGS; then
        if [[ -z "$TARGET" ]]; then die "Provide a target file or directory when using --delete."; fi
        return 0
    fi

    # Direct GPS mode: --lat/--lon provided instead of a track log
    if [[ -n "$GPS_LAT" || -n "$GPS_LON" ]]; then
        if [[ -n "$GPS_LOG" ]]; then
            die "Cannot combine --lat/--lon (direct mode) with -l/--log (track log mode)."
        fi
        if [[ -z "$GPS_LAT" || -z "$GPS_LON" ]]; then
            die "--lat and --lon must both be provided for direct GPS mode."
        fi
        if [[ -z "$TARGET" ]]; then die "Target path is required. Run '$SCRIPT_NAME --help'."; fi
        # Validate numeric format (allow optional leading minus, digits, optional decimal)
        if ! [[ "$GPS_LAT" =~ ^-?[0-9]+(\.([0-9]+))?$ ]]; then
            die "--lat value '$GPS_LAT' is not a valid decimal number."
        fi
        if ! [[ "$GPS_LON" =~ ^-?[0-9]+(\.([0-9]+))?$ ]]; then
            die "--lon value '$GPS_LON' is not a valid decimal number."
        fi
        if [[ -n "$GPS_ALT" ]] && ! [[ "$GPS_ALT" =~ ^-?[0-9]+(\.([0-9]+))?$ ]]; then
            die "--alt value '$GPS_ALT' is not a valid decimal number."
        fi
        # Validate ranges
        local abs_lat; abs_lat="${GPS_LAT#-}"
        local abs_lon; abs_lon="${GPS_LON#-}"
        if awk "BEGIN{exit !($abs_lat > 90)}"; then die "Latitude must be between -90 and 90."; fi
        if awk "BEGIN{exit !($abs_lon > 180)}"; then die "Longitude must be between -180 and 180."; fi
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
# Rename ExifTool backup files from the default `filename.ext_original`
# format to `filename.orig.ext` so backups stay in the same directory with
# a clean, predictable name.
#
# Called automatically after any write operation when BACKUP=true.
# Only renames files created during this run — matches *_original pattern.
# ---------------------------------------------------------------------------
rename_backups() {
    local target="$1"
    local search_path

    # Determine where to search for backup files
    if [[ -f "$target" ]]; then
        search_path="$(dirname "$target")"
    else
        search_path="$target"
    fi

    # Build find args; restrict depth to 1 unless --recursive was given
    local -a find_args
    find_args=("$search_path" "-name" "*_original")
    if ! $RECURSIVE; then
        find_args+=("-maxdepth" "1")
    fi

    while IFS= read -r orig_file; do
        # orig_file: /path/photo.jpg_original
        # Strip the trailing _original suffix to get the original path
        local base; base="${orig_file%_original}"       # /path/photo.jpg
        local ext; ext="${base##*.}"                    # jpg
        local name; name="${base%.*}"                   # /path/photo
        local new_name; new_name="${name}.orig.${ext}"  # /path/photo.orig.jpg
        mv "$orig_file" "$new_name"
        info "Backup : $(basename "$new_name")"
    done < <(find "${find_args[@]}" 2>/dev/null)
}

# ---------------------------------------------------------------------------
# Write the ExifTool config file that defines a GPXTime composite tag.
# GPXTime returns the first defined value from:
#   1. GPSDateTime   (UTC from GPS data — best quality)
#   2. DateTimeOriginal (local camera capture time)
#   3. FileModifyDate   (filesystem mtime — always available)
# Sets the global GPX_CFG_TMP variable.
# ---------------------------------------------------------------------------
write_gpx_config() {
    GPX_CFG_TMP="$(mktemp /tmp/exiftool-gpx-cfg.XXXXXX)"
    cat > "$GPX_CFG_TMP" <<'GPXCFG'
%Image::ExifTool::UserDefined = (
    'Image::ExifTool::Composite' => {
        GPXTime => {
            Desire => {
                0 => 'GPSDateTime',
                1 => 'DateTimeOriginal',
                2 => 'FileModifyDate',
            },
            # Return the first defined date value (GPS time > capture time > file time)
            ValueConv => 'defined $val[0] ? $val[0] : defined $val[1] ? $val[1] : $val[2]',
            PrintConv => '$val',
        },
    },
);
1;
GPXCFG
}

# ---------------------------------------------------------------------------
# Write a temporary GPX print-format file used by --extract-gpx
# Sets the global GPX_FMT_TMP variable.
# ---------------------------------------------------------------------------
write_gpx_fmt() {
    GPX_FMT_TMP="$(mktemp /tmp/exiftool-gpx-fmt.XXXXXX)"
    cat > "$GPX_FMT_TMP" <<'GPXFMT'
#[HEAD]<?xml version="1.0" encoding="utf-8"?>
#[HEAD]<gpx version="1.0"
#[HEAD] creator="ExifTool $ExifToolVersion"
#[HEAD] xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
#[HEAD] xmlns="http://www.topografix.com/GPX/1/0"
#[HEAD] xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
#[HEAD]<trk>
#[HEAD]<trkseg>
#[BODY]<trkpt lat="$GPSLatitude#" lon="$GPSLongitude#">
#[BODY]  <ele>$GPSAltitude#</ele>
#[BODY]  <time>${GPXTime;s/(\d{4}):(\d{2}):(\d{2})/$1-$2-$3/;s/ /T/}</time>
#[BODY]  <name>$FileName</name>
#[BODY]</trkpt>
#[TAIL]</trkseg>
#[TAIL]</trk>
#[TAIL]</gpx>
GPXFMT
}

# ---------------------------------------------------------------------------
# Build ExifTool command into global CMD_ARGS array
# ---------------------------------------------------------------------------
CMD_ARGS=()

build_cmd() {
    CMD_ARGS=(exiftool)

    # ── Read / inspect metadata mode ──────────────────────────────
    if $READ_MODE; then
        if $GPS_ONLY; then
            # Show GPS group tags only, grouped, including duplicates
            CMD_ARGS+=("-a" "-u" "-G1" "-gps:all")
        else
            # Show all tags, grouped, including duplicates and unknown tags
            CMD_ARGS+=("-a" "-u" "-G1")
        fi
        if $RECURSIVE; then CMD_ARGS+=("-r");   fi
        if $VERBOSE;   then CMD_ARGS+=("-v2");  fi
        CMD_ARGS+=("$TARGET")
        return
    fi

    # ── Extract GPS → GPX track mode ──────────────────────────────
    if $EXTRACT_GPX; then
        write_gpx_config
        write_gpx_fmt
        # -config: loads composite GPXTime tag (GPS time > DateTimeOriginal > FileModifyDate)
        # -p:      print using format template
        # -if:     process only files that have GPS coordinates
        CMD_ARGS+=("-config" "$GPX_CFG_TMP")
        CMD_ARGS+=("-p" "$GPX_FMT_TMP")
        CMD_ARGS+=("-if" 'defined($GPSLatitude) and defined($GPSLongitude)')
        if $RECURSIVE; then CMD_ARGS+=("-r");   fi
        if $VERBOSE;   then CMD_ARGS+=("-v2");  fi
        CMD_ARGS+=("$TARGET")
        return
    fi

    # ── Direct GPS coordinates mode ────────────────────────────────
    if [[ -n "$GPS_LAT" ]]; then
        # Derive N/S and E/W references from the sign of the values
        local lat_val lon_val lat_ref lon_ref
        if [[ "$GPS_LAT" == -* ]]; then
            lat_ref="S"; lat_val="${GPS_LAT#-}"
        else
            lat_ref="N"; lat_val="$GPS_LAT"
        fi
        if [[ "$GPS_LON" == -* ]]; then
            lon_ref="W"; lon_val="${GPS_LON#-}"
        else
            lon_ref="E"; lon_val="$GPS_LON"
        fi

        # ExifVersion=0232 forces ExifTool to create an ExifIFD sub-IFD.
        # Without ExifIFD many EXIF parsers (Pic2Map, exif-js, browser tools)
        # declare "no EXIF data" even though GPS tags are physically present in
        # the file — they look for the ExifIFD pointer (0x8769) in IFD0 first.
        # GPSDateStamp / GPSTimeStamp record when the geotag was applied (UTC).
        local gps_date gps_time
        gps_date="$(date -u +%Y:%m:%d)"
        gps_time="$(date -u +%H:%M:%S)"

        CMD_ARGS+=(
            "-ExifVersion=0232"
            "-GPSDateStamp=${gps_date}"
            "-GPSTimeStamp=${gps_time}"
            "-GPSLatitude=${lat_val}"
            "-GPSLatitudeRef=${lat_ref}"
            "-GPSLongitude=${lon_val}"
            "-GPSLongitudeRef=${lon_ref}"
        )

        # Altitude is optional
        if [[ -n "$GPS_ALT" ]]; then
            local alt_val alt_ref
            if [[ "$GPS_ALT" == -* ]]; then
                alt_ref="1"; alt_val="${GPS_ALT#-}"   # 1 = below sea level
            else
                alt_ref="0"; alt_val="$GPS_ALT"        # 0 = above sea level
            fi
            CMD_ARGS+=("-GPSAltitude=${alt_val}" "-GPSAltitudeRef=${alt_ref}")
        fi

        if $GEOLOCATION; then CMD_ARGS+=("-geolocate=geotag"); fi
        if $RECURSIVE;      then CMD_ARGS+=("-r");                  fi
        if $PRESERVE_DATES; then CMD_ARGS+=("-P");                  fi
        if $VERBOSE;        then CMD_ARGS+=("-v2");                 fi
        if ! $BACKUP;       then CMD_ARGS+=("-overwrite_original"); fi
        CMD_ARGS+=("$TARGET")
        return
    fi

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
    echo -e "${BOLD}ExifTool Summary${RESET}"
    divider
    if $READ_MODE; then
        if $GPS_ONLY; then
            echo -e "  Mode       : ${CYAN}READ GPS TAGS ONLY${RESET}"
        else
            echo -e "  Mode       : ${CYAN}READ ALL METADATA${RESET}"
        fi
    elif $EXTRACT_GPX; then
        echo -e "  Mode       : ${CYAN}EXTRACT GPS → GPX TRACK${RESET}"
        echo    "  Output     : $GPX_OUTPUT"
    elif [[ -n "$GPS_LAT" ]]; then
        echo -e "  Mode       : ${GREEN}DIRECT GPS COORDS${RESET}"
        echo    "  Latitude   : $GPS_LAT ($([ "${GPS_LAT:0:1}" = '-' ] && echo S || echo N))"
        echo    "  Longitude  : $GPS_LON ($([ "${GPS_LON:0:1}" = '-' ] && echo W || echo E))"
        if [[ -n "$GPS_ALT" ]]; then
            echo    "  Altitude   : ${GPS_ALT} m $([ "${GPS_ALT:0:1}" = '-' ] && echo '(below sea level)' || echo '(above sea level)')"
        fi
        echo    "  GPS UTC    : $(date -u +%Y:%m:%d) $(date -u +%H:%M:%S)Z  (GPSDateStamp + GPSTimeStamp)"
        echo    "  ExifIFD    : created (ensures compatibility with all EXIF parsers)"
        if $GEOLOCATION; then echo "  Geolocation: yes (city/state/country)"; fi
    elif $DELETE_TAGS; then
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
# Pre-pass: ensure DateTimeOriginal is set on any image that lacks it.
#
# Without DateTimeOriginal:
#   - Geotag mode cannot interpolate GPS coordinates from a track log.
#   - Extract-GPX mode falls back to FileModifyDate via GPXTime composite,
#     but an explicit DateTimeOriginal makes the <time> element more reliable.
#
# Strategy: copy DateTimeOriginal from FileModifyDate for files that lack it.
# Uses -overwrite_original + -P so no backup is created and file mtime is
# preserved — this step is transparent to the user's file system.
# Reports how many files were updated so the user knows what happened.
# ---------------------------------------------------------------------------
ensure_datetime_original() {
    local target="$1"
    local -a pre_args
    pre_args=(
        exiftool
        "-if" 'not defined $DateTimeOriginal'
        "-DateTimeOriginal<FileModifyDate"
        "-overwrite_original"   # no backup — this is a transparent repair step
        "-P"                    # preserve FileModifyDate after the tag write
    )
    if $RECURSIVE; then pre_args+=("-r"); fi
    pre_args+=("$target")

    info "Pre-pass: setting DateTimeOriginal for images that lack it…"
    # grep filters to only the summary line; || true absorbs grep's exit code 1
    # (no match) and exiftool's exit code 2 (0 files processed by -if filter)
    "${pre_args[@]}" 2>&1 | grep -E '[0-9]+ image files' || true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    # Clean up both GPX temp files on any exit
    cleanup() {
        if [[ -n "$GPX_FMT_TMP" && -f "$GPX_FMT_TMP" ]]; then rm -f "$GPX_FMT_TMP"; fi
        if [[ -n "$GPX_CFG_TMP" && -f "$GPX_CFG_TMP" ]]; then rm -f "$GPX_CFG_TMP"; fi
    }
    trap cleanup EXIT

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
        echo -e "  ${CYAN}${display_args[*]}${RESET}"
        if $EXTRACT_GPX; then
            echo -e "  ${CYAN}> ${GPX_OUTPUT}${RESET}"
        fi
        echo
        exit 0
    fi

    # Extract GPX: stdout must be redirected to the output file
    if $EXTRACT_GPX; then
        # Ensure DateTimeOriginal exists so GPX <time> elements are accurate
        ensure_datetime_original "$TARGET"
        info "Extracting GPS track from images…"
        echo
        "${CMD_ARGS[@]}" > "$GPX_OUTPUT"
        echo
        ok "GPX track written to: $GPX_OUTPUT"
        divider
        return
    fi

    if $READ_MODE; then
        info "Reading metadata…"
    else
        # Geotag mode: ensure DateTimeOriginal exists so track interpolation succeeds
        if [[ -n "$GPS_LOG" ]]; then
            ensure_datetime_original "$TARGET"
        fi
        info "Running ExifTool…"
    fi
    echo

    # Execute directly via array — preserves all argument quoting correctly
    "${CMD_ARGS[@]}"

    # Rename ExifTool's default backup files (photo.jpg_original → photo.orig.jpg)
    # Only for write modes that keep backups (BACKUP=true, not read/extract-gpx)
    if ! $READ_MODE && $BACKUP; then
        rename_backups "$TARGET"
    fi

    echo
    ok "Done."
    divider
}

main "$@"
