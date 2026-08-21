#!/usr/bin/env python3
"""
Read or search sections of a .tscn or .tres text file.

Usage:
    python3 tools/ship_tools/read_tscn_section.py [file_path] [--lines N] [--find KEYWORD]
"""

import sys
import os
import argparse

def read_section(file_path, count=60, start=None, end=None, find=None):
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    total = len(lines)
    print(f"Total lines in {file_path}: {total}")

    if find:
        print(f"=== Matches for '{find}' ===")
        for i, line in enumerate(lines):
            if find.lower() in line.lower():
                # print context
                ctx_start = max(0, i - 2)
                ctx_end = min(total, i + 3)
                print(f"--- Around line {i+1} ---")
                for j in range(ctx_start, ctx_end):
                    mark = " > " if j == i else "   "
                    print(f"{j+1:4d}{mark}{lines[j]}", end="")
        return

    if start is not None and end is not None:
        s = max(1, start)
        e = min(total, end)
        print(f"=== Lines {s} to {e} ===")
        for i in range(s - 1, e):
            print(f"{i+1:4d}: {lines[i]}", end="")
    else:
        print(f"=== Last {count} lines ===")
        start_idx = max(0, total - count)
        for i in range(start_idx, total):
            print(f"{i+1:4d}: {lines[i]}", end="")

def main():
    parser = argparse.ArgumentParser(description="Read or search Godot .tscn/.tres files.")
    parser.add_argument("file", nargs="?", default="scenes/prefabs/ships/cargo_ship_1.tscn", help="Path to .tscn or .tres")
    parser.add_argument("-n", "--lines", type=int, default=60, help="Number of lines to read from end")
    parser.add_argument("--start", type=int, default=None, help="Start line (1-indexed)")
    parser.add_argument("--end", type=int, default=None, help="End line (1-indexed)")
    parser.add_argument("--find", type=str, default=None, help="Search keyword")
    args = parser.parse_args()

    read_section(args.file, args.lines, args.start, args.end, args.find)

if __name__ == '__main__':
    main()

