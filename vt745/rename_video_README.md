# Video File Renamer Script

A zsh script to rename video files from dot notation to space notation with proper year formatting.

## Purpose

Renames video files (MKV, MP4, AVI) that use dot notation into clean filenames with spaces and properly formatted years in brackets.

## Example Transformations

**Movies:**
- `The.Movie.Name.2024.720p.x265.mkv` → `The Movie Name (2024) 720p x265.mkv`
- `Another.Film.(2023).1080p.mkv` → `Another Film (2023) 1080p.mkv`

**TV Shows:**
- `Show.Name.S01E01.720p.mkv` → `Show Name S01E01 720p.mkv`
- `Series.S02E15.1080p.x264.mkv` → `Series S02E15 1080p x264.mkv`

## Usage

```bash
rename_video <folder_path>
```

### Examples

```bash
# With relative path
rename_video "Movies/Action"

# With absolute path
rename_video "/media/movies/2024"
```

## Features

- ✅ Scans for video files: MKV, MP4, AVI
- ✅ Detects dot notation in filenames
- ✅ Converts dots to spaces
- ✅ Ensures year is in brackets (YYYY format)
- ✅ Preserves quality indicators (720p, 1080p, etc.)
- ✅ Shows preview before renaming
- ✅ Asks for confirmation before making changes
- ✅ Safe: Won't overwrite existing files
- ✅ Color-coded output for easy reading

## What It Does

1. **Scans** the folder for video files (`.mkv`, `.mp4`, `.avi`)
2. **Identifies** files with dot notation in names
3. **Converts** dots to spaces
4. **Formats** year in brackets `(YYYY)`
5. **Shows** you what will be renamed
6. **Asks** for confirmation
7. **Renames** files when approved

## Year Handling

The script intelligently handles years:

- `Movie.Name.2024` → `Movie Name (2024)`
- `Movie.Name.(2024)` → `Movie Name (2024)` (already formatted)
- `Movie.Name.2024.720p` → `Movie Name (2024) 720p`

## Safety Features

- **Preview mode**: Shows all changes before executing
- **Confirmation required**: Won't rename without your approval
- **No overwriting**: Won't replace existing files
- **Extension preserved**: Never modifies file extensions
- **Error handling**: Reports any issues during renaming

## Location

The script is saved at:
```
~/.oh-my-zsh/custom/plugins/vt745/rename_video.sh
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

Once the plugin is loaded, you can use the `rename_video` alias from anywhere:

```bash
rename_video "/path/to/folder"
```

## Example Output

```
Analyzing folder: /media/movies

Finding video files with dot notation...

Found:
  Current:  The.Dark.Knight.2008.720p.BluRay.x264.mkv
  Rename to: The Dark Knight (2008) 720p BluRay x264.mkv

Found:
  Current:  Inception.(2010).1080p.x265.mkv
  Rename to: Inception (2010) 1080p x265.mkv

================================================
Summary: 2 video file(s) will be renamed
================================================

Do you want to proceed with renaming? (yes/no): yes

Renaming files...

✓ Renamed: The.Dark.Knight.2008.720p.BluRay.x264.mkv
       -> The Dark Knight (2008) 720p BluRay x264.mkv
✓ Renamed: Inception.(2010).1080p.x265.mkv
       -> Inception (2010) 1080p x265.mkv

================================================
Successfully renamed: 2 file(s)
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
chmod +x ~/.oh-my-zsh/custom/plugins/vt745/rename_video.sh
```

**Script doesn't find any files:**
- Make sure your video files have dots in their names
- Check that you're pointing to the correct folder

**"Target file already exists" error:**
- You already have a file with the target name
- The script won't overwrite it for safety

## Notes

- The script only processes files in the specified folder (not subdirectories)
- Original filenames are preserved if renaming fails
- Extension case is preserved (e.g., `.mkv` stays `.mkv`, `.MKV` stays `.MKV`)
- Multiple consecutive spaces are cleaned up automatically

## License

Free to use and modify as needed.
