#!/bin/bash
# Subtitle Translation Wrapper
# Translates subtitles with language detection
# Supports multiple translation modes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/translate_subtitle.py"
VENV_DIR="${SCRIPT_DIR}/.venv_subtitle"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}✗ Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_usage() {
    cat <<EOF
${BLUE}Subtitle Translation Tool${NC}

Usage: $(basename "$0") <input_file> <output_file> [mode] [options]

Arguments:
  input_file     Input subtitle file (.srt)
  output_file    Output subtitle file (.srt)
  mode           Translation mode (default: 1)
                   1 = Auto-detect language → English
                   2 = English → Indonesian (with verification)

Options:
  -v, --verbose  Enable verbose output
  -h, --help     Show this help message

Examples:
  # Auto-detect and translate to English
  $(basename "$0") movie.srt movie_en.srt

  # Translate from English to Indonesian
  $(basename "$0") movie_en.srt movie_id.srt 2

  # With verbose output
  $(basename "$0") movie.srt movie_en.srt 1 -v

${BLUE}Translation Modes:${NC}
  Mode 1 (Default): Automatically detects the subtitle language and translates to English
  Mode 2:          Translates from English to Indonesian
                   - Verifies source is English; aborts if not
                   - Ensures accuracy by confirming input language

${BLUE}Configuration:${NC}
  Virtual environment location: ${VENV_DIR}
  Dependencies will be auto-installed on first run
EOF
}

# Check if Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    print_error "Python script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Check for help flag first
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    print_usage
    exit 0
fi

# Parse arguments
if [ $# -lt 2 ]; then
    print_error "Missing required arguments"
    echo ""
    print_usage
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
MODE="${3:-1}"
EXTRA_ARGS="${@:4}"

# Validate input file
if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file not found: $INPUT_FILE"
    exit 1
fi

if [[ "$INPUT_FILE" != *.srt ]]; then
    print_warning "Input file may not be an SRT subtitle: $INPUT_FILE"
fi

if [[ "$OUTPUT_FILE" != *.srt ]]; then
    print_warning "Output file may not be an SRT subtitle: $OUTPUT_FILE"
fi

# Validate mode
if ! [[ "$MODE" =~ ^[1-2]$ ]]; then
    print_error "Invalid mode: $MODE (must be 1 or 2)"
    exit 1
fi

print_info "Subtitle Translation Tool"
echo ""
echo "Input file:    $INPUT_FILE"
echo "Output file:   $OUTPUT_FILE"
if [ "$MODE" == "1" ]; then
    echo "Mode:          1 (Auto-detect → English)"
else
    echo "Mode:          2 (English → Indonesian)"
fi
echo ""

# Setup Python virtual environment if needed
if [ ! -d "$VENV_DIR" ]; then
    print_info "Setting up Python virtual environment..."
    python3 -m venv "$VENV_DIR" || {
        print_error "Failed to create virtual environment"
        exit 1
    }
fi

# Activate venv
source "${VENV_DIR}/bin/activate" || {
    print_error "Failed to activate virtual environment"
    exit 1
}

# Install/upgrade dependencies
print_info "Checking dependencies..."
pip install --upgrade pip >/dev/null 2>&1 || true
pip install -q srt deep-translator langdetect 2>/dev/null || {
    print_error "Failed to install Python dependencies"
    deactivate 2>/dev/null || true
    exit 1
}

# Run Python translation script
print_info "Starting translation..."
echo ""

if python "$PYTHON_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE" "$MODE" $EXTRA_ARGS; then
    echo ""
    print_success "Translation completed successfully!"
    print_info "Output file: $(cd "$(dirname "$OUTPUT_FILE")" && pwd)/$(basename "$OUTPUT_FILE")"
    deactivate 2>/dev/null || true
    exit 0
else
    echo ""
    print_error "Translation failed"
    deactivate 2>/dev/null || true
    exit 1
fi
