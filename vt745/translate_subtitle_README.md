# Subtitle Translation Tool

A flexible, easy-to-use subtitle translation tool that automatically detects source language and translates to English, or converts English subtitles to Indonesian with verification.

## Features

- **Language Auto-Detection**: Automatically detects subtitle language using machine learning
- **Multiple Translation Modes**: 
  - Mode 1: Auto-detect → English (default)
  - Mode 2: English → Indonesian (with English verification)
- **SRT Structure Preservation**: Maintains subtitle timing, cue numbers, and HTML/XML tags
- **Error Handling**: Robust error detection and meaningful error messages
- **Extensible Design**: Easy to add new translation modes in the future
- **Virtual Environment Isolation**: Dependencies auto-installed in isolated venv

## Installation

The tool is already integrated into the `vt745` oh-my-zsh plugin. No manual installation needed!

### Dependencies
Automatically installed on first run:
- `srt` - SRT subtitle file parser
- `deep-translator` - Translation backend using Google Translate API
- `langdetect` - Language detection

## Usage

```bash
translate_subtitle <input_file> <output_file> [mode] [options]
```

### Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `input_file` | Path to input subtitle file (.srt) | Yes |
| `output_file` | Path to output subtitle file (.srt) | Yes |
| `mode` | Translation mode: 1 or 2 (default: 1) | No |

### Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose logging for debugging |
| `-h, --help` | Display help message |

## Translation Modes

### Mode 1: Auto-Detect to English (Default)

Automatically detects the subtitle language and translates to English.

**Best for**: Converting subtitles from any language to English

```bash
# Simple usage (auto-detect + translate to English)
translate_subtitle movie.srt movie_en.srt

# Equivalent to:
translate_subtitle movie.srt movie_en.srt 1

# With verbose output
translate_subtitle movie.srt movie_en.srt 1 -v
```

**Example**: 
- Input: Indonesian subtitles → Output: English subtitles
- Input: Spanish subtitles → Output: English subtitles
- Input: Any language → Output: English subtitles

### Mode 2: English to Indonesian (With Verification)

Translates English subtitles to Indonesian with automatic verification that source is English.

**Best for**: Creating Indonesian versions of English content

```bash
# Translate English to Indonesian
translate_subtitle movie_en.srt movie_id.srt 2

# With verbose output
translate_subtitle movie_en.srt movie_id.srt 2 -v
```

**Features**:
- Verifies source subtitle is English before proceeding
- Aborts with clear error if source is not English
- Ensures data integrity by confirming input language

**Example Error**:
```
ERROR: Mode 2 requires English source subtitle, but detected 'id'
```

## Examples

### Example 1: Translate Indonesian to English
```bash
# Movie with Indonesian subtitles
translate_subtitle About.Family.indo.srt About.Family.en.srt

# Auto-detects Indonesian and translates to English
```

### Example 2: Create Indonesian version from English
```bash
# Movie with English subtitles
translate_subtitle About.Family.en.srt About.Family.id.srt 2

# Verifies source is English, then translates to Indonesian
```

### Example 3: Multi-language conversion workflow
```bash
# Step 1: Convert any language to English
translate_subtitle movie_spanish.srt movie_en.srt

# Step 2: Create Indonesian version
translate_subtitle movie_en.srt movie_id.srt 2
```

### Example 4: Debug with verbose output
```bash
# See language detection and translation progress
translate_subtitle subtitle.srt output.srt 1 --verbose
```

## Output

The tool provides clear feedback:

```
ℹ Subtitle Translation Tool

Input file:    movie.srt
Output file:   movie_en.srt
Mode:          1 (Auto-detect → English)

ℹ Setting up Python virtual environment...
ℹ Checking dependencies...
ℹ Starting translation...
Detected source language: id
Progress: 200/1200 cues translated
Progress: 400/1200 cues translated
...

✓ Successfully translated 1200 cues to movie_en.srt
✓ Translation completed successfully!
```

## How It Works

### Architecture

```
translate_subtitle.sh (Bash Wrapper)
    ├─ Environment Setup
    ├─ Argument Validation
    ├─ Dependency Management
    └─ Calls: translate_subtitle.py

translate_subtitle.py (Python Engine)
    ├─ Language Detection (langdetect)
    ├─ Tag Protection (preserves formatting)
    ├─ Translation (deep_translator + Google API)
    ├─ Error Recovery (retry logic)
    └─ SRT Output (srt library)
```

### Process Flow

1. **Input Validation**: Check if input file exists and is readable
2. **Language Detection**: Sample first 20 lines to auto-detect source language
3. **Mode Verification**: For Mode 2, verify source is English
4. **Translation**: Translate each subtitle cue line-by-line
5. **Tag Preservation**: HTML/XML tags protected during translation
6. **Error Recovery**: Retry failed translations up to 5 times
7. **Output**: Write translated subtitles preserving original timing

## Configuration and Extension

### Adding New Translation Modes

Edit `translate_subtitle.py` in the `SubtitleTranslator` class:

```python
self.modes = {
    "1": ("auto", "en"),           # Existing: Auto-detect → English
    "2": ("en", "id"),             # Existing: English → Indonesian
    "3": ("auto", "es"),           # New: Auto-detect → Spanish
    "4": ("en", "fr"),             # New: English → French
}
```

### Changing Translation Service

Replace `GoogleTranslator` with other services that support `deep_translator`:

```python
from deep_translator import MicrosoftTranslator, PonsTranslator, etc.
translator = MicrosoftTranslator(source=source_lang, target=target_lang)
```

### Custom Configuration File

Future enhancement: Create `translate_subtitle.conf` for:
- Default translation service
- Language pair mappings
- Supported languages
- API keys for premium services

## Troubleshooting

### "Python script not found"
```bash
# Ensure the vt745 plugin folder has the scripts
ls -la ~/.oh-my-zsh/custom/plugins/vt745/
```

### "Input file not found"
```bash
# Use absolute path or verify the file exists
translate_subtitle /full/path/to/movie.srt output.srt
```

### Mode 2 Error: "requires English source"
```bash
# Input subtitle is not English. Use Mode 1 first:
translate_subtitle input.srt input_en.srt 1
translate_subtitle input_en.srt output_id.srt 2
```

### Translation seems slow
- First run installs dependencies (slower)
- Network latency affects translation speed
- Use verbose mode `-v` to see detailed progress
- Consider splitting large files (>3000 cues)

### Missing Python dependencies
```bash
# Manual installation (auto-done on first run)
pip install srt deep-translator langdetect

# Or reinstall venv
rm -rf ~/.oh-my-zsh/custom/plugins/vt745/.venv_subtitle
translate_subtitle input.srt output.srt
```

## Performance Notes

- **First run**: ~30-60 seconds (includes virtualenv setup and dependency installation)
- **Subsequent runs**: 2-5 minutes depending on subtitle length (network-dependent)
- **Per cue**: ~200-400ms average translation time
- **Large files**: 3000+ cues may take 15-20 minutes

## Limitations

- Requires internet connection (uses Google Translate API)
- Rate limiting may apply for very large batches
- Translation quality depends on Google Translate accuracy
- Language detection works best with 50+ subtitle lines
- Only supports `.srt` format

## Future Enhancements

- [ ] Batch processing multiple files
- [ ] Custom translation service selection
- [ ] Local translation models (offline mode)
- [ ] Quality checking and confidence scores
- [ ] Translation memory/caching
- [ ] Support for VTT, ASS, SUB formats
- [ ] Configuration file support
- [ ] API key management for premium services

## License

Part of the `vt745` oh-my-zsh plugin. Same license as the plugin.

## Support & Issues

For issues or feature requests, check the main `vt745` plugin documentation or create an issue in the plugin repository.

---

**Quick Tip**: Create an alias for common translations:
```bash
# Add to your .zshrc or .bashrc
alias translate_to_en='translate_subtitle'
alias translate_to_id='translate_subtitle $1 ${1%.srt}_id.srt 2'
```
