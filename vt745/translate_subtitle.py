#!/usr/bin/env python3
"""
Subtitle Translation Tool
Supports multiple translation modes and auto-detection of source language.
"""

import argparse
import sys
import os
from pathlib import Path
from typing import Tuple, List
import re
import time

try:
    import srt
    from deep_translator import GoogleTranslator
    from langdetect import detect, DetectorFactory
except ImportError as e:
    print(f"ERROR: Missing dependency - {e}", file=sys.stderr)
    print("Run: pip install srt deep-translator langdetect", file=sys.stderr)
    sys.exit(1)

# For consistent language detection results
DetectorFactory.seed = 0


class SubtitleTranslator:
    """Main translator class handling all translation operations."""

    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        # Map translation modes to (source_lang, target_lang)
        self.modes = {
            "1": ("auto", "en"),     # Auto-detect → English
            "2": ("en", "id"),       # English → Indonesian
        }

    def log(self, msg: str):
        """Print verbose log messages."""
        if self.verbose:
            print(f"[INFO] {msg}", file=sys.stderr)

    def detect_language(self, text: str) -> str:
        """Detect language of subtitle content."""
        # Extract text only from SRT (remove timing, numbers)
        clean_text = re.sub(r"\d+\n\d{2}:\d{2}:\d{2}.*?-->.*?\n", "", text)
        # Remove HTML tags
        clean_text = re.sub(r"</?[^>]+>", "", clean_text)
        # Get first meaningful chunk
        lines = [l.strip() for l in clean_text.split("\n") if l.strip()]
        sample = " ".join(lines[:20])  # First 20 lines

        if not sample or len(sample) < 50:
            return "en"  # Default to English if insufficient text

        try:
            detected = detect(sample)
            self.log(f"Detected language: {detected}")
            return detected
        except Exception as e:
            self.log(f"Language detection failed: {e}, defaulting to 'en'")
            return "en"

    def protect_tags(self, text: str) -> Tuple[str, dict]:
        """Protect XML/HTML tags and special markers from translation."""
        tokens = {}
        idx = 0

        def replace(m):
            nonlocal idx
            key = f"__TAG{idx}__"
            tokens[key] = m.group(0)
            idx += 1
            return key

        # Protect HTML-like tags and common subtitle markup
        protected = re.sub(r"</?[^>]+>", replace, text)
        return protected, tokens

    def restore_tags(self, text: str, tokens: dict) -> str:
        """Restore protected tags back into translated text."""
        for key, value in tokens.items():
            text = text.replace(key, value)
        return text

    def translate_line(
        self, line: str, translator: GoogleTranslator
    ) -> str:
        """Translate a single line with retry logic."""
        if not line.strip():
            return line

        # Skip pure punctuation/symbol lines
        if re.fullmatch(r"[\W_\s]+", line.strip()):
            return line

        protected, tokens = self.protect_tags(line)

        for attempt in range(5):
            try:
                translated = translator.translate(protected)
                result = self.restore_tags(translated, tokens)
                return result
            except Exception as e:
                self.log(
                    f"Translation attempt {attempt + 1}/5 failed: {e}"
                )
                time.sleep(1.5 * (attempt + 1))

        self.log(f"Translation failed after 5 attempts, keeping original")
        return line

    def translate_subtitles(
        self,
        input_file: Path,
        output_file: Path,
        mode: str,
    ) -> bool:
        """
        Translate subtitle file according to specified mode.
        Returns True on success, False on failure.
        """
        if mode not in self.modes:
            print(f"ERROR: Unknown mode '{mode}'. Available modes: {list(self.modes.keys())}", file=sys.stderr)
            return False

        source_lang, target_lang = self.modes[mode]

        # Read input file
        try:
            input_text = input_file.read_text(encoding="utf-8", errors="replace")
            subs = list(srt.parse(input_text))
            self.log(f"Loaded {len(subs)} subtitle cues from {input_file}")
        except Exception as e:
            print(f"ERROR: Failed to read input file: {e}", file=sys.stderr)
            return False

        if not subs:
            print("ERROR: No subtitles found in input file", file=sys.stderr)
            return False

        # Detect source language if mode is "auto"
        if source_lang == "auto":
            detected = self.detect_language(input_text)
            source_lang = detected
            self.log(f"Auto-detected source language: {source_lang}")
            print(f"Detected source language: {source_lang}", file=sys.stderr)

        # Mode 2: Verify that source is English
        if mode == "2":
            if source_lang.lower() not in ["en", "eng"]:
                print(
                    f"ERROR: Mode 2 requires English source subtitle, but detected '{source_lang}'",
                    file=sys.stderr,
                )
                return False
            self.log("Source verified as English, proceeding with translation to Indonesian")

        # Initialize translator
        try:
            translator = GoogleTranslator(source=source_lang, target=target_lang)
            self.log(
                f"Initialized translator: {source_lang} → {target_lang}"
            )
        except Exception as e:
            print(f"ERROR: Failed to initialize translator: {e}", file=sys.stderr)
            return False

        # Translate each subtitle
        for i, sub in enumerate(subs, start=1):
            lines = sub.content.split("\n")
            translated_lines = [
                self.translate_line(line, translator) for line in lines
            ]
            sub.content = "\n".join(translated_lines)

            if i % 200 == 0:
                print(f"Progress: {i}/{len(subs)} cues translated", file=sys.stderr)

        # Write output file
        try:
            output_file.write_text(srt.compose(subs), encoding="utf-8")
            self.log(f"Wrote {len(subs)} cues to {output_file}")
            print(f"✓ Successfully translated {len(subs)} cues to {output_file}", file=sys.stderr)
            return True
        except Exception as e:
            print(f"ERROR: Failed to write output file: {e}", file=sys.stderr)
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Translate subtitle files with language auto-detection",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes:
  1 (default)  Detect subtitle language and translate to English
  2            Translate from English to Indonesian (aborts if not English)

Examples:
  %(prog)s input.srt output.srt
  %(prog)s input.srt output.srt 1
  %(prog)s english.srt indonesian.srt 2
        """,
    )
    parser.add_argument("input_file", help="Input subtitle file (.srt)")
    parser.add_argument("output_file", help="Output subtitle file (.srt)")
    parser.add_argument(
        "mode",
        nargs="?",
        default="1",
        help="Translation mode: 1 (auto→en) or 2 (en→id) [default: 1]",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose logging"
    )

    args = parser.parse_args()

    # Validate input file
    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    if not input_path.suffix.lower() == ".srt":
        print(f"WARNING: Input file is not .srt format", file=sys.stderr)

    # Validate output file directory
    output_path = Path(args.output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Run translation
    translator = SubtitleTranslator(verbose=args.verbose)
    success = translator.translate_subtitles(input_path, output_path, args.mode)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
