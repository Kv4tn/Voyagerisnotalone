#!/bin/bash
# PDF Generation Script for Development Reports
# Requires: pandoc and pdflatex (MacTeX)

REPORT_DIR="/Users/asenpisen/voyagerisnotalone/.kiro/reports"
REPORT_FILE="$1"

if [ -z "$REPORT_FILE" ]; then
    echo "Usage: ./generate_pdf.sh <report_markdown_file>"
    echo "Example: ./generate_pdf.sh REPORT_2024-11-17_specification-complete.md"
    exit 1
fi

REPORT_PATH="$REPORT_DIR/$REPORT_FILE"
PDF_PATH="${REPORT_PATH%.md}.pdf"

if [ ! -f "$REPORT_PATH" ]; then
    echo "Error: Report file not found: $REPORT_PATH"
    exit 1
fi

echo "Generating PDF from $REPORT_FILE..."

# Check if pandoc is installed
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc not installed"
    echo "Install with: brew install pandoc"
    exit 1
fi

# Check if pdflatex is installed
if ! command -v pdflatex &> /dev/null; then
    echo "Error: pdflatex not installed"
    echo "Install MacTeX: brew install --cask mactex-no-gui"
    exit 1
fi

# Generate PDF
pandoc "$REPORT_PATH" \
    -o "$PDF_PATH" \
    --pdf-engine=pdflatex \
    -V geometry:margin=1in \
    -V fontsize=11pt \
    -V documentclass=article \
    -V colorlinks=true \
    -V linkcolor=blue \
    -V urlcolor=blue \
    -V toccolor=black \
    --toc \
    --toc-depth=2 \
    --highlight-style=tango \
    --metadata title="Voyager Is Not Alone - Development Report" \
    --metadata author="Kiro AI Assistant" \
    --metadata date="$(date +%Y-%m-%d)"

if [ $? -eq 0 ]; then
    echo "✅ PDF generated successfully: $PDF_PATH"
    echo "File size: $(ls -lh "$PDF_PATH" | awk '{print $5}')"
else
    echo "❌ PDF generation failed"
    exit 1
fi
