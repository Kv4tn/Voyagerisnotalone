#!/bin/bash
# Builds report.html and report.pdf next to a Markdown report.
# Needs only what ships with macOS: python3 and osascript.
# Usage: .kiro/reports/tools/build_report.sh .kiro/reports/REPORT_xxx.md
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 path/to/REPORT.md" >&2
    exit 1
fi

TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
# Absolute path: the macOS print system rejects relative file URLs.
SOURCE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
HTML="${SOURCE%.md}.html"
PDF="${SOURCE%.md}.pdf"

python3 "$TOOLS_DIR/md_to_html.py" "$SOURCE" "$HTML"
osascript -l JavaScript "$TOOLS_DIR/html_to_pdf.js" "$HTML" "$PDF"
rm -f "$HTML"
