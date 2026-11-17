#!/usr/bin/env python3
"""
Simple Markdown to PDF converter using markdown2 and weasyprint
Alternative to pandoc for generating development reports

Usage: python3 generate_pdf_python.py REPORT_2024-11-17_specification-complete.md
"""

import sys
import os
from pathlib import Path

def check_dependencies():
    """Check if required packages are installed"""
    try:
        import markdown
        import weasyprint
        return True
    except ImportError as e:
        print(f"Error: Missing dependency - {e}")
        print("\nInstall required packages:")
        print("  pip3 install markdown weasyprint")
        return False

def markdown_to_html(markdown_content):
    """Convert markdown to HTML with styling"""
    import markdown
    
    # HTML template with CSS
    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            @page {{
                size: A4;
                margin: 2cm;
            }}
            body {{
                font-family: 'Helvetica', 'Arial', sans-serif;
                font-size: 11pt;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
                margin: 0 auto;
            }}
            h1 {{
                color: #2c3e50;
                border-bottom: 3px solid #3498db;
                padding-bottom: 10px;
                margin-top: 30px;
            }}
            h2 {{
                color: #34495e;
                border-bottom: 2px solid #95a5a6;
                padding-bottom: 5px;
                margin-top: 25px;
            }}
            h3 {{
                color: #7f8c8d;
                margin-top: 20px;
            }}
            code {{
                background-color: #f4f4f4;
                padding: 2px 6px;
                border-radius: 3px;
                font-family: 'Courier New', monospace;
                font-size: 10pt;
            }}
            pre {{
                background-color: #f8f8f8;
                border: 1px solid #ddd;
                border-radius: 5px;
                padding: 15px;
                overflow-x: auto;
                font-size: 9pt;
            }}
            pre code {{
                background-color: transparent;
                padding: 0;
            }}
            table {{
                border-collapse: collapse;
                width: 100%;
                margin: 20px 0;
            }}
            th, td {{
                border: 1px solid #ddd;
                padding: 10px;
                text-align: left;
            }}
            th {{
                background-color: #3498db;
                color: white;
            }}
            tr:nth-child(even) {{
                background-color: #f2f2f2;
            }}
            blockquote {{
                border-left: 4px solid #3498db;
                padding-left: 15px;
                margin-left: 0;
                font-style: italic;
                color: #555;
            }}
            ul, ol {{
                margin-left: 20px;
            }}
            li {{
                margin: 5px 0;
            }}
            .checkmark {{
                color: #27ae60;
                font-weight: bold;
            }}
            hr {{
                border: none;
                border-top: 2px solid #ecf0f1;
                margin: 30px 0;
            }}
        </style>
    </head>
    <body>
    {content}
    </body>
    </html>
    """
    
    # Convert markdown to HTML
    md = markdown.Markdown(extensions=['extra', 'codehilite', 'toc', 'tables'])
    html_content = md.convert(markdown_content)
    
    # Replace checkmarks
    html_content = html_content.replace('✅', '<span class="checkmark">✅</span>')
    html_content = html_content.replace('✓', '<span class="checkmark">✓</span>')
    
    return html_template.format(content=html_content)

def generate_pdf(markdown_file):
    """Generate PDF from markdown file"""
    import weasyprint
    
    # Read markdown file
    markdown_path = Path(markdown_file)
    if not markdown_path.exists():
        print(f"Error: File not found - {markdown_file}")
        return False
    
    print(f"Reading {markdown_path.name}...")
    markdown_content = markdown_path.read_text(encoding='utf-8')
    
    # Convert to HTML
    print("Converting markdown to HTML...")
    html_content = markdown_to_html(markdown_content)
    
    # Generate PDF
    pdf_path = markdown_path.with_suffix('.pdf')
    print(f"Generating PDF: {pdf_path.name}...")
    
    try:
        weasyprint.HTML(string=html_content).write_pdf(pdf_path)
        pdf_size = pdf_path.stat().st_size
        print(f"✅ PDF generated successfully: {pdf_path}")
        print(f"File size: {pdf_size / 1024:.1f} KB")
        return True
    except Exception as e:
        print(f"❌ Error generating PDF: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_pdf_python.py <report_file.md>")
        print("Example: python3 generate_pdf_python.py REPORT_2024-11-17_specification-complete.md")
        sys.exit(1)
    
    if not check_dependencies():
        sys.exit(1)
    
    markdown_file = sys.argv[1]
    success = generate_pdf(markdown_file)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
