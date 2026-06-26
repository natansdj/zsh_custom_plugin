#!/usr/bin/env python3
"""
split_log.py — Split a large CSV or log file into smaller chunks.

Usage:
    python split_log.py <source_path> [--size <MB>] [--dest <path>]

Arguments:
    source_path         Path to the file to split (required)

Options:
    --size  <MB>        Max size per output file in MB (default: 10)
    --dest  <path>      Destination folder for output files
                        (default: log_output/ next to this script)
    --no-header         Force disable header preservation (overrides auto-detect)
    --header            Force enable header preservation (overrides auto-detect)

Auto-detection:
    .csv                → header preserved in every output file
    .log / .txt / other → no header, plain split

Examples:
    python split_log.py /path/to/data.csv
    python split_log.py /path/to/app.log
    python split_log.py /path/to/data.csv --size 9.9 --dest /Users/natan/Downloads/output
"""

import os
import sys
import argparse


CSV_EXTENSIONS = {".csv"}


def detect_header(source_path: str) -> bool:
    ext = os.path.splitext(source_path)[1].lower()
    return ext in CSV_EXTENSIONS


def split_file(source_path: str, size_mb: float, dest_path: str, use_header: bool) -> None:
    if not os.path.isfile(source_path):
        print(f"[ERROR] File not found: {source_path}")
        sys.exit(1)

    limit_bytes = int(size_mb * 1024 * 1024)
    os.makedirs(dest_path, exist_ok=True)

    source_ext = os.path.splitext(source_path)[1] or ".log"
    source_size = os.path.getsize(source_path)
    mode = "CSV mode (header preserved in each part)" if use_header else "Log mode (plain split, no header)"

    print(f"Source  : {source_path}")
    print(f"Size    : {source_size / 1024 / 1024:.2f} MB")
    print(f"Split at: {size_mb} MB per file")
    print(f"Mode    : {mode}")
    print(f"Output  : {dest_path}")
    print()

    with open(source_path, "r", encoding="utf-8", errors="replace") as f:
        header = f.readline() if use_header else None

        file_index = 1
        current_size = 0
        current_rows = 0
        out = None

        def open_next():
            nonlocal out, file_index, current_size, current_rows
            if out:
                out.close()
                print(f"  ✔ part_{file_index - 1:02d}{source_ext}  {current_size / 1024 / 1024:.2f} MB  {current_rows:,} lines")
            out_path = os.path.join(dest_path, f"part_{file_index:02d}{source_ext}")
            out = open(out_path, "w", encoding="utf-8")
            if header is not None:
                out.write(header)
                current_size = len(header.encode("utf-8"))
            else:
                current_size = 0
            current_rows = 0
            file_index += 1

        open_next()

        for line in f:
            line_bytes = len(line.encode("utf-8"))
            if current_size + line_bytes > limit_bytes:
                open_next()
            out.write(line)
            current_size += line_bytes
            current_rows += 1

        if out:
            out.close()
            print(f"  ✔ part_{file_index - 1:02d}{source_ext}  {current_size / 1024 / 1024:.2f} MB  {current_rows:,} lines")

    total_files = file_index - 1
    print(f"\nDone — {total_files} file(s) written to: {dest_path}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_dest = os.path.join(script_dir, "log_output")

    parser = argparse.ArgumentParser(
        description="Split a large CSV or log file into smaller chunks.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("source", help="Path to the source file (.csv, .log, .txt, etc.)")
    parser.add_argument(
        "--size",
        type=float,
        default=10.0,
        metavar="MB",
        help="Max size per output file in MB (default: 10)",
    )
    parser.add_argument(
        "--dest",
        default=default_dest,
        metavar="PATH",
        help="Destination folder (default: log_output/ next to this script)",
    )

    # Mutually exclusive override flags
    header_group = parser.add_mutually_exclusive_group()
    header_group.add_argument(
        "--no-header",
        action="store_true",
        help="Force plain split — no header preservation",
    )
    header_group.add_argument(
        "--header",
        action="store_true",
        help="Force header preservation regardless of file extension",
    )

    args = parser.parse_args()

    # Determine header mode: explicit flags override auto-detect
    if args.no_header:
        use_header = False
        print(f"[INFO] Header mode: forced off (--no-header)")
    elif args.header:
        use_header = True
        print(f"[INFO] Header mode: forced on (--header)")
    else:
        use_header = detect_header(args.source)
        ext = os.path.splitext(args.source)[1].lower() or "(none)"
        print(f"[INFO] Header mode: auto-detected from extension '{ext}' → {'on' if use_header else 'off'}")

    split_file(
        source_path=args.source,
        size_mb=args.size,
        dest_path=args.dest,
        use_header=use_header,
    )


if __name__ == "__main__":
    main()
