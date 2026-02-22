# Subtitle Renamer Script

A zsh script to automatically rename subtitle files to match video filenames based on episode identifiers.

**Part of the vt745 Oh My Zsh custom plugin**

## Purpose

When you have video files (MKV, MP4, AVI) and subtitle files (SRT) with different naming conventions, this script matches them by episode number (e.g., S01E01) and renames the subtitles to match the video filenames exactly.

## Example

**Before:**
- Video: `Gotham.S01E01.720p.x265-ZMNT.mkv`
- Subtitle: `Gotham.S01E01.HDTV.x264-LOL.srt`

**After:**
- Video: `Gotham.S01E01.720p.x265-ZMNT.mkv`
- Subtitle: `Gotham.S01E01.720p.x265-ZMNT.srt` ✓

## Usage

```bash
rename_subtitle <folder_path>
```

### Example

```bash
rename_subtitle "/path/to/TV Show/Season 01"
```

Or with the full path:

```bash
~/.oh-my-zsh/custom/plugins/vt745/rename_subtitles.sh "/path/to/TV Show/Season 01"
```

## Features

- ✅ Matches subtitles with videos by episode identifier (S01E01, S02E15, etc.)
- ✅ Supports multiple video formats: MKV, MP4, AVI
- ✅ Supports multiple subtitle formats: SRT, SUB
- ✅ Handles both SxxExx and 1x01 naming patterns
- ✅ Color-coded output for easy reading
- ✅ Shows preview before renaming
- ✅ Asks for confirmation before making changes
- ✅ Handles duplicate subtitles (warns and skips them)
- ✅ Safe: Won't overwrite existing files
- ✅ Only renames subtitle files, never video files

## What It Does

1. **Scans** the folder for video files (`.mkv`, `.mp4`, `.avi`)
2. **Scans** for subtitle files (`.srt`, `.sub`)
3. **Extracts** episode identifiers (like S01E01) from filenames
4. **Matches** subtitles to videos by episode number
5. **Shows** you what will be renamed
6. **Asks** for confirmation
7. **Renames** subtitle files to match video filenames

## Handling Duplicates

If multiple subtitle files exist for the same episode (e.g., different release groups), the script will:
- Rename the first matching subtitle
- Warn you about additional subtitles
- Skip renaming the duplicates to avoid conflicts

Example output:
```
⚠ Duplicate subtitle for episode S01E20:
  Skipping: Gotham.S01E20.720p.HDTV.x264-DIMENSION.srt
  (Another subtitle for this episode will be renamed)
```

## Safety Features

- **Preview mode**: Shows all changes before executing
- **Confirmation required**: Won't rename without your approval
- **No overwriting**: Won't replace existing files
- **Subtitle-only**: Only renames subtitle files, never touches video files
- **Error handling**: Reports any issues during renaming

## Error Handling

The script will report:
- Subtitles with no matching video file
- Target files that already exist
- Any rename failures

## Location

The script is saved at:
```
~/.oh-my-zsh/custom/plugins/vt745/rename_subtitles.sh
```

As part of the vt745 Oh My Zsh custom plugin.

## Installation

The script is automatically available when you have the `vt745` plugin enabled in your `~/.zshrc`:

```bash
plugins=(... vt745)
```

After adding the plugin, reload your shell:
```bash
source ~/.zshrc
```

## Using the Alias

Once the plugin is loaded, you can use the `rename_subtitle` alias from anywhere:

```bash
rename_subtitle "/path/to/folder"
```

The alias points to the script in the vt745 plugin directory.

## Example Output

```
Analyzing folder: /path/to/Gotham/Season 01

Finding video files...
  ✓ Found video: Gotham.S01E01.720p.x265-ZMNT.mkv [S01E01]
  ✓ Found video: Gotham.S01E02.720p.x265-ZMNT.mkv [S01E02]
  ...

Finding subtitle files...
  Found subtitle: Gotham.S01E01.HDTV.x264-LOL.srt [S01E01]
  Found subtitle: Gotham.S01E02.HDTV.x264-LOL.srt [S01E02]
  ...

Matching subtitles with videos...

Match found for episode S01E01:
  Current:  Gotham.S01E01.HDTV.x264-LOL.srt
  Rename to: Gotham.S01E01.720p.x265-ZMNT.srt

================================================
Summary: 22 subtitle file(s) will be renamed
================================================

Do you want to proceed with renaming? (yes/no): yes

Renaming files...

✓ Renamed: Gotham.S01E01.HDTV.x264-LOL.srt -> Gotham.S01E01.720p.x265-ZMNT.srt
✓ Renamed: Gotham.S01E02.HDTV.x264-LOL.srt -> Gotham.S01E02.720p.x265-ZMNT.srt
...

================================================
Successfully renamed: 22 file(s)
================================================
```

## Requirements

- Zsh shell (with Oh My Zsh)
- Linux/Unix operating system
- vt745 plugin enabled in ~/.zshrc
- Execute permission on the script (should be set by default)

## Troubleshooting

**Alias not found:**
Make sure the `vt745` plugin is enabled in your `~/.zshrc` and reload your shell:
```bash
source ~/.zshrc
```

**Script says "command not found":**
```bash
chmod +x ~/.oh-my-zsh/custom/plugins/vt745/rename_subtitles.sh
```

**Script doesn't find any matches:**
- Make sure your files use standard episode numbering (S01E01, 1x01, etc.)
- Check that video and subtitle files are in the same folder

**"Target file already exists" error:**
- You already have a subtitle file with the target name
- The script won't overwrite it for safety

## License

Free to use and modify as needed.
