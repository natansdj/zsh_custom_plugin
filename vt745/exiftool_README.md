# exiftool.sh — GPS Geotagging Helper

A purpose-built Bash wrapper around [ExifTool](https://exiftool.org) that streamlines GPS geotagging for photos and videos.  
It surfaces the three core ExifTool geotag-family tags — **Geotag**, **Geosync**, and **Geotime** — through a clean, documented CLI.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Core Concepts](#core-concepts)
   - [Geotag](#geotag)
   - [Geosync](#geosync)
   - [Geotime](#geotime)
4. [Usage](#usage)
5. [Options Reference](#options-reference)
6. [Examples](#examples)
   - [Basic Geotagging](#1-basic-geotagging)
   - [Camera Clock Offset](#2-camera-clock-offset)
   - [Specific Timezone](#3-specific-timezone)
   - [Custom Date Tag](#4-custom-date-tag)
   - [Multiple Track Logs](#5-multiple-track-logs)
   - [Clock-Drift Correction](#6-clock-drift-correction)
   - [XMP Tags Only](#7-xmp-tags-only)
   - [Write Geolocation Tags](#8-write-geolocation-tags)
   - [Videos (QuickTime)](#9-videos-quicktime)
   - [Delete GPS Tags](#10-delete-gps-tags)
   - [Dry Run](#11-dry-run)
   - [Preserve FileModifyDate](#12-preserve-filemodifydate)
   - [Accuracy Tuning](#13-accuracy-tuning)
   - [Direct GPS Coordinates (No Track Log)](#14-direct-gps-coordinates-no-track-log)
   - [Read All Metadata](#15-read-all-metadata)
   - [Extract GPS Track to GPX](#16-extract-gps-track-to-gpx)
   - [Apply GPX to EXIF Metadata](#17-apply-gpx-to-exif-metadata)
7. [GPS Log Formats](#gps-log-formats)
8. [Tags Written](#tags-written)
9. [Troubleshooting](#troubleshooting)
10. [Time Synchronisation Tips](#time-synchronisation-tips)

---

## Requirements

| Dependency | Version | Install |
|------------|---------|---------|
| `exiftool` | ≥ 12.x  | `brew install exiftool` (macOS) · `apt install libimage-exiftool-perl` (Debian/Ubuntu) · [exiftool.org](https://exiftool.org) |
| `bash`     | ≥ 4     | Pre-installed on macOS/Linux |

---

## Installation

```bash
# Copy into the vt745 Oh My Zsh plugin folder (already done if cloned from the repo)
chmod +x ~/.oh-my-zsh/custom/plugins/vt745/exiftool.sh

# Optional: add a global alias in your shell config (.zshrc / .bashrc)
alias geotag='~/.oh-my-zsh/custom/plugins/vt745/exiftool.sh'
```

---

## Core Concepts

### Geotag

The `Geotag` tag activates ExifTool's geotagging engine.  
You assign it the path to a **GPS track log** file, and ExifTool linearly interpolates each image's GPS coordinates from the track data at the time the photo was taken.

```
exiftool -geotag track.gpx /path/to/photos/
```

Supported log formats: **GPX**, **NMEA**, **KML**, **IGC**, **Garmin TCX/XML**, **Google Takeout JSON**, **DJI CSV**, **ExifTool CSV**, and more.

### Geosync

`Geosync` corrects the **time difference** between your camera's clock and GPS time before the coordinates are looked up.

| Scenario | Geosync value |
|----------|---------------|
| Camera was 25 s slow | `+25` or `+00:00:25` |
| Camera was 1 m 20 s fast | `-1:20` |
| Extract offset from a reference image | `<gps_time>@ref_image.jpg` |
| Both times explicit | `"19:32:21Z@14:31:49-05:00"` |

Multiple `--geosync` values (each pointing to a reference image) enable **piecewise linear clock-drift correction**.

### Geotime

`Geotime` specifies **which camera timestamp** is used to perform the GPS track lookup.  
By default ExifTool uses `SubSecDateTimeOriginal` (if present) or `DateTimeOriginal`.

Override this when:
- Images use `CreateDate` instead of `DateTimeOriginal`
- Images lack an embedded timezone
- Images have timestamps only in `FileModifyDate`

---

## Usage

```
exiftool.sh [OPTIONS] -l <track.log> <target>           # geotag from GPS log
exiftool.sh [OPTIONS] --apply-gpx <track.gpx> <target>  # apply GPX → write EXIF GPS
exiftool.sh [OPTIONS] --lat <N> --lon <N> <target>      # direct GPS coordinates
exiftool.sh [OPTIONS] --read [--gps-only] <target>      # read / inspect metadata
exiftool.sh [OPTIONS] --extract-gpx <target>            # extract GPS → GPX track
```

`<target>` can be a single file, a directory, or a glob pattern  
(quote globs to prevent shell expansion: `"photos/*.jpg"`).

---

## Options Reference

### Core

| Flag | Long form | Description |
|------|-----------|-------------|
| `-l <file>` | `--log <file>` | GPS track log. Repeat for multiple logs. |
| `-t <path>` | `--target <path>` | Target file, directory, or glob. Positional arg also accepted. |
| `-o <grp>` | `--output-group <grp>` | Force tag group: `exif` · `xmp` · `quicktime` |

### Geosync

| Flag | Long form | Description |
|------|-----------|-------------|
| `-s <value>` | `--geosync <value>` | Time offset or reference file/pair. Repeat for drift correction. |

### Geotime

| Flag | Long form | Description |
|------|-----------|-------------|
| `-g <tag>` | `--geotime <tag>` | ExifTool tag to use as reference time (default: `DateTimeOriginal`). |
| `-z <tz>` | `--timezone <tz>` | Append timezone to Geotime, e.g. `+07:00`. |

### Accuracy

| Flag | Description | Default |
|------|-------------|---------|
| `--max-int-secs <N>` | Max gap between track fixes for interpolation (seconds). | 1800 |
| `--max-ext-secs <N>` | Max distance outside track for extrapolation (seconds). | 1800 |
### Direct GPS Coordinates

Write GPS coordinates **without a track log**. Mutually exclusive with `-l / --log`.

| Flag | Long form | Description |
|------|-----------|-------------|
| `--lat <deg>` | `--latitude <deg>` | Latitude in decimal degrees. Positive = North, negative = South. |
| `--lon <deg>` | `--longitude <deg>` | Longitude in decimal degrees. Positive = East, negative = West. |
| `--alt <m>` | `--altitude <m>` | Altitude in metres. Positive = above sea level, negative = below. |

### Read Metadata

Display embedded metadata without making any changes.

| Flag | Description |
|------|-------------|
| `--read` | Show all metadata tags, grouped by family (e.g. EXIF, GPS, IPTC, XMP). |
| `--gps-only` | Show GPS group tags only. Implies `--read`. |

### Extract GPS Track

Build a GPX track log from GPS coordinates already embedded in images/videos.

| Flag | Description |
|------|-------------|
| `--extract-gpx` | Extract GPS coords from files and write a GPX track. |
| `--gpx-output <file>` | Output GPX filename (default: `track.gpx`). |

> **Tip:** Use `-r` with `--extract-gpx` to recurse into sub-directories.

### Apply GPX to EXIF

Read a GPX track file and write GPS coordinates into image EXIF metadata.  
This is the reverse of `--extract-gpx` and works identically to `-l / --log`.

| Flag | Description |
|------|-------------|
| `--apply-gpx <file>` | Apply a GPX track file — writes GPS lat/lon/alt/time into EXIF. Alias for `-l`. |

> **Tip:** Combine with `-z <tz>` when images lack an embedded timezone, and `-s <offset>` to correct camera clock drift.

### Write Behaviour

| Flag | Long form | Description |
|------|-----------|-------------|
| `-r` | `--recursive` | Recurse into sub-directories. |
| `-n` | `--no-backup` | Skip backup files (pass `-overwrite_original` to ExifTool). |
| `-P` | `--preserve-dates` | Preserve `FileModifyDate` after rewrite. |
| `-d` | `--delete` | Delete GPS tags previously written by geotag. |
| | `--geolocation` | Also write city / state / country derived from GPS position. |
| `-v` | `--verbose` | Enable ExifTool verbose output (`-v2`). |
| | `--dry-run` | Print the generated command without executing it. |
| `-h` | `--help` | Show usage help. |
| | `--version` | Print script version. |

---

## Examples

### 1. Basic Geotagging

```bash
./exiftool.sh -l track.gpx ./photos/
```

Geotags every image in `./photos/` using GPS positions from `track.gpx`.  
ExifTool writes `GPSLatitude`, `GPSLongitude`, `GPSAltitude`, `GPSDateStamp`, `GPSTimeStamp`, and related EXIF tags.

---

### 2. Camera Clock Offset

```bash
# Camera was 25 seconds SLOW (add 25 s to camera time to reach GPS time)
./exiftool.sh -l track.gpx -s +25 ./photos/

# Camera was 1 minute 20 seconds FAST
./exiftool.sh -l track.gpx -s -1:20 ./photos/
```

`+` means GPS was ahead of the camera clock; `-` means camera was ahead of GPS.

---

### 3. Specific Timezone

```bash
# Photos taken in Jakarta (WIB = UTC+7) without an embedded timezone
./exiftool.sh -l track.gpx -z +07:00 ./photos/

# Photos were taken in US Eastern (UTC-5)
./exiftool.sh -l track.gpx -z -05:00 ./photos/
```

---

### 4. Custom Date Tag

```bash
# Images store capture time in CreateDate, not DateTimeOriginal
./exiftool.sh -l track.gpx -g CreateDate ./photos/

# Images only have FileModifyDate; preserve it after rewrite
./exiftool.sh -l track.gpx -g FileModifyDate -P ./photos/
```

---

### 5. Multiple Track Logs

```bash
# Combine logs that span a long trip (wildcard — quote to avoid shell expansion)
./exiftool.sh -l "logs/*.gpx" ./photos/

# Explicit multiple logs
./exiftool.sh -l morning.gpx -l afternoon.gpx ./photos/
```

---

### 6. Clock-Drift Correction

Take a picture of your GPS unit's clock display.  
After the shoot, use those reference images to fix the camera-clock drift  
(ExifTool performs piecewise linear interpolation between sync points):

```bash
./exiftool.sh -l track.gpx -s ref_start.jpg -s ref_end.jpg ./photos/
```

Or supply explicit GPS+camera time pairs:

```bash
./exiftool.sh -l track.gpx \
  -s "19:32:21Z@14:31:49-05:00" \
  ./photos/
```

---

### 7. XMP Tags Only

```bash
./exiftool.sh -l track.gpx -o xmp ./photos/
```

Writes GPS data to XMP namespace only — useful for files that prefer XMP over EXIF.

---

### 8. Write Geolocation Tags

```bash
# Automatically derive and write city / state / country from GPS position
./exiftool.sh -l track.gpx --geolocation ./photos/
```

Requires ExifTool's bundled geolocation database (included in standard distributions).

---

### 9. Videos (QuickTime)

```bash
# MP4 / MOV — write GPS to QuickTime Keys metadata
./exiftool.sh -l track.gpx -o quicktime -g CreateDate ./videos/
```

> **Tip:** If `CreateDate` in your videos is already UTC, add  
> `-api QuickTimeUTC` directly to the ExifTool command (use `--dry-run` first to tweak).

---

### 10. Delete GPS Tags

```bash
# Remove GPS tags from a single image
./exiftool.sh --delete ./photos/DSC_0001.jpg

# Remove XMP GPS tags only, recursively
./exiftool.sh --delete -o xmp -r ./photos/
```

> `--delete` removes only the GPS tags that `geotag` wrote, not all GPS tags.  
> To strip *all* GPS tags: `exiftool -gps:all= <file>`

---

### 11. Dry Run

Always preview before writing to a large photo library:

```bash
./exiftool.sh --dry-run -l track.gpx -s +25 -z +07:00 ./photos/
```

Prints the full ExifTool command without executing it.

---

### 12. Preserve FileModifyDate

```bash
./exiftool.sh -l track.gpx -P ./photos/
```

ExifTool normally updates `FileModifyDate` when it rewrites a file.  
`-P` keeps the original filesystem timestamp.

> **Backup naming**: By default, the original file is preserved as `photo.orig.jpg`
> (same folder, same extension). Pass `-n` / `--no-backup` to skip backups entirely.

---

### 13. Accuracy Tuning

```bash
# Only interpolate when GPS fixes are within 5 minutes of each other
# and allow extrapolation up to 10 minutes outside the track
./exiftool.sh -l track.gpx \
  --max-int-secs 300 \
  --max-ext-secs 600 \
  ./photos/
```

---

### 14. Direct GPS Coordinates (No Track Log)

Use this mode when you know the exact GPS coordinates and do not have a track log.  
This writes `GPSLatitude`, `GPSLatitudeRef`, `GPSLongitude`, `GPSLongitudeRef` (and optionally `GPSAltitude`) directly.

Coordinate rules:
- **Latitude**: positive value = North (`N`), negative value = South (`S`)
- **Longitude**: positive value = East (`E`), negative value = West (`W`)
- **Altitude**: positive = above sea level, negative = below sea level

```bash
# Tag a single photo with Jakarta coordinates
./exiftool.sh --lat -6.2088 --lon 106.8456 ./photos/DSC_0001.jpg

# With altitude (35 m above sea level) and auto-write city/state/country
./exiftool.sh --lat 48.8566 --lon 2.3522 --alt 35 --geolocation ./photos/

# Apply to every image in a directory, skip backup files
./exiftool.sh --lat -33.8688 --lon 151.2093 -r -n ./photos/

# Coordinates below sea level (Dead Sea area, ~-430 m)
./exiftool.sh --lat 31.5590 --lon 35.4732 --alt -430 ./photo.jpg

# Preview the generated command before writing
./exiftool.sh --dry-run --lat 35.6762 --lon 139.6503 --alt 40 ./photos/
```

> **Finding coordinates**: Open [Google Maps](https://maps.google.com), right-click any location, and copy the decimal degree values shown at the top of the context menu.

> **Combining with geolocation**: Add `--geolocation` to also write city, state, and country tags derived from the coordinates (requires ExifTool's bundled geolocation database).

---

### 15. Read All Metadata

Inspect all embedded metadata for one or more images — no changes are written.

```bash
# Show ALL metadata tags, grouped by family (EXIF, GPS, IPTC, XMP, …)
./exiftool.sh --read ./photos/DSC_0001.jpg

# Show GPS tags only
./exiftool.sh --gps-only ./photos/DSC_0001.jpg

# Read all metadata recursively across an entire directory
./exiftool.sh --read -r ./photos/
```

The `--read` output groups tags by family (e.g. `[EXIF]`, `[GPS]`) and includes
all duplicate/unknown tags. Equivalent bare ExifTool commands:

```bash
exiftool -a -u -G1 <file>      # all metadata (what --read does)
exiftool -gps:all  <file>      # GPS only     (what --gps-only does)
```

---

### 16. Extract GPS Track to GPX

Build a GPX track log directly from the GPS coordinates already embedded in
your photos or videos — no separate GPS device log needed.

```bash
# Extract GPS from all images in a directory (writes track.gpx)
./exiftool.sh --extract-gpx ./photos/

# Custom output filename
./exiftool.sh --extract-gpx --gpx-output trip-2024.gpx ./photos/

# Recurse into sub-directories
./exiftool.sh --extract-gpx -r --gpx-output full-trip.gpx ./photos/

# Preview the generated command first
./exiftool.sh --dry-run --extract-gpx -r ./photos/
```

Only files that contain both `GPSLatitude` and `GPSLongitude` are included in the
output. The GPX file follows the [GPX 1.0 schema](https://www.topografix.com/GPX/1/0)
and includes `<ele>` (altitude), `<time>`, and `<name>` (filename)
for each track point.

**Time source priority** (first available wins):

| Priority | Tag | Notes |
|----------|-----|-------|
| 1st | `GPSDateTime` | UTC time from GPS data — most accurate |
| 2nd | `DateTimeOriginal` | Local camera capture time |
| 3rd | `FileModifyDate` | File system time — always available |

> **After extracting**: load the `.gpx` file into [GPX Studio](https://gpx.studio),
> [Google My Maps](https://mymaps.google.com), or any mapping app to visualise your route.

> **Round-trip workflow**: geotag photos first with `-l track.gpx`, then re-export
> with `--extract-gpx` to verify that the GPS data was written correctly.

---

### 17. Apply GPX to EXIF Metadata

Read a GPX track log and write GPS coordinates back into image EXIF metadata.
`--apply-gpx` is a semantic alias for `-l / --log` — they are identical in behaviour and
support all the same Geosync, Geotime, and accuracy options.

Before running the track interpolation, the script automatically runs a **pre-pass** that
sets `DateTimeOriginal` from `FileModifyDate` on any image that lacks it — so ExifTool
can always look up GPS coordinates from the track, even on images with no capture timestamp.

```bash
# Apply a GPX track to a single image (no DateTimeOriginal needed)
./exiftool.sh --apply-gpx track.gpx ./photos/DSC_0001.jpg

# Apply to an entire directory
./exiftool.sh --apply-gpx track.gpx ./photos/

# With timezone correction (camera clock was in WIB local time, not UTC)
./exiftool.sh --apply-gpx track.gpx -z +07:00 ./photos/

# With a 25-second camera clock offset
./exiftool.sh --apply-gpx track.gpx -s +25 ./photos/

# Round-trip verify: extract → apply → re-extract to confirm GPS survived
./exiftool.sh --extract-gpx --gpx-output before.gpx ./photos/
./exiftool.sh --apply-gpx before.gpx ./photos/  # writes EXIF back into images
./exiftool.sh --extract-gpx --gpx-output after.gpx ./photos/
```

> **When to use `--apply-gpx` vs `-l`**: They are equivalent. `--apply-gpx` is  
> preferred when the intent is clearly "import GPS from this GPX file into my images",  
> while `-l` is shorter for scripting.

---

## GPS Log Formats

ExifTool reads all major GPS track formats:

| Format | Extension |
|--------|-----------|
| GPX (most common) | `.gpx` |
| NMEA | `.nmea`, `.log`, `.txt` |
| KML / KMZ | `.kml`, `.kmz` |
| IGC (gliders) | `.igc` |
| Garmin XML / TCX | `.xml`, `.tcx` |
| Google Takeout | `.json` |
| DJI CSV | `.csv` |
| ExifTool CSV | `.csv` |

---

## Tags Written

When successful, ExifTool writes the following EXIF tags (availability depends on what the track log contains):

| Tag | Description |
|-----|-------------|
| `GPSLatitude` / `GPSLatitudeRef` | Latitude |
| `GPSLongitude` / `GPSLongitudeRef` | Longitude |
| `GPSAltitude` / `GPSAltitudeRef` | Elevation (m above sea level) |
| `GPSDateStamp` | GPS date (UTC) |
| `GPSTimeStamp` | GPS time (UTC) |
| `GPSSpeed` / `GPSSpeedRef` | Speed at time of capture |
| `GPSTrack` / `GPSTrackRef` | Compass heading |
| `GPSImgDirection` | Camera facing direction |
| `GPSMeasureMode` | 2D / 3D fix |
| `GPSDOP` | Dilution of Precision |

---

## Troubleshooting

### "GPS data written but third-party tools say 'No EXIF data'"

This happens when the image has no **ExifIFD sub-IFD** (the `0x8769` pointer in IFD0).  
Many parsers — including Pic2Map, browser-based exif-js, and similar online tools — look for
`ExifIFD` first; if absent they declare "no EXIF data" even though GPS tags are physically
present in the file.

The script now automatically fixes this by writing `ExifVersion=0232` alongside all GPS tags
in direct mode, which forces ExifTool to create a proper ExifIFD. It also writes `GPSDateStamp`
and `GPSTimeStamp` (current UTC time) so the GPS block is complete.

If you already wrote GPS to an image with an older version of the script, re-run the same
`--lat/--lon` command to update the EXIF structure, or apply the fix manually:

```bash
exiftool -ExifVersion=0232 -GPSDateStamp="$(date -u +%Y:%m:%d)" \
         -GPSTimeStamp="$(date -u +%H:%M:%S)" ./photo.jpg
```

### "No track points found in GPS file"

- Verify the log format is supported (see [GPS Log Formats](#gps-log-formats))
- GPX tracks must have `<trkpt>` elements with `time` attributes
- KML placemarks need `<TimeStamp>` elements

### "0 image files updated" / "No writable tags set"

- **Missing `DateTimeOriginal`**: When using `--apply-gpx` / `-l`, the script now automatically
  runs a pre-pass that copies `FileModifyDate` → `DateTimeOriginal` for any image that lacks it.
  You should not see this warning anymore; if you do, add `--verbose` to see what ExifTool reports.
- The image must have a `DateTimeOriginal` tag (or whichever tag you set with `-g`)
- Run `exiftool -s -time:all <image>` to list all available time tags
- Add `--verbose` for detailed ExifTool output

### "Time is too far before/after track"

- Check timezone: GPS is always UTC; camera time is local
- Use `-z <+HH:MM>` to specify the correct timezone
- Use `--verbose` — ExifTool will print the UTC Geotime value and track start/end

### Verify GPS was written correctly

```bash
exiftool -gps:all <image.jpg>
```

---

## Time Synchronisation Tips

### Method A — Capture a GPS Clock Reference Photo

Take a photo of your GPS unit's time display at the start (and/or end) of a session.

```bash
# Single sync point — constant offset
./exiftool.sh -l track.gpx -s ref.jpg ./photos/

# Two sync points — linear drift correction
./exiftool.sh -l track.gpx -s ref_start.jpg -s ref_end.jpg ./photos/
```

### Method B — Fix Timestamps First, Then Geotag

```bash
# Shift all capture timestamps by +32 seconds
exiftool -alldates+=00:00:32 ./photos/

# Geotag using the corrected timestamps
./exiftool.sh -l track.gpx ./photos/
```

### Method C — Fix and Geotag in One Pass

```bash
exiftool -alldates+=00:00:32 -geosync=+00:00:32 -geotag track.gpx ./photos/
```

> **Note:** The `+` sign in `-geosync` means GPS was *ahead* of the camera clock  
> (i.e. the camera was slow). Subtract this offset from camera time to align with GPS.

---

*Powered by [ExifTool](https://exiftool.org) by Phil Harvey — the Swiss-army knife of image metadata.*
