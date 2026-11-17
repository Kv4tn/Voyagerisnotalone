#!/usr/bin/env python3
"""Minimal Markdown -> HTML converter for development reports (stdlib only).

Supports: # headings, paragraphs, - and 1. lists, ``` code blocks, | tables,
**bold**, `code`, ![alt](img), [text](url), --- rules.

Usage: python3 md_to_html.py report.md report.html
"""
import html
import re
import sys
from pathlib import Path

CSS = """
@page { size: A4; margin: 18mm 16mm; }
body { font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif; font-size: 10.5pt;
       line-height: 1.5; color: #1b2433; margin: 0; }
h1 { font-size: 20pt; color: #0b1324; border-bottom: 3px solid #e0a040; padding-bottom: 6px; }
h2 { font-size: 14pt; color: #0b1324; border-bottom: 1px solid #5fb3c4; padding-bottom: 3px;
     margin-top: 22px; page-break-after: avoid; }
h3 { font-size: 11.5pt; color: #2a4d5c; margin-top: 16px; page-break-after: avoid; }
code { font-family: Menlo, monospace; font-size: 9pt; background: #eef3f6; padding: 1px 4px;
       border-radius: 3px; }
pre { background: #0b1324; color: #d9eaf0; padding: 10px 12px; border-radius: 4px;
      font-size: 8.5pt; white-space: pre-wrap; page-break-inside: avoid; }
pre code { background: none; padding: 0; color: inherit; }
table { border-collapse: collapse; width: 100%; margin: 10px 0; font-size: 9.5pt;
        page-break-inside: avoid; }
th { background: #0b1324; color: #fff; text-align: left; padding: 5px 7px; }
td { border-bottom: 1px solid #d5dde3; padding: 5px 7px; vertical-align: top; }
img { max-width: 100%; border: 1px solid #5fb3c4; margin: 6px 0; image-rendering: pixelated; }
hr { border: none; border-top: 1px solid #d5dde3; margin: 18px 0; }
li { margin: 2px 0; }
.meta { color: #5a6878; }
"""


def inline(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r'<img alt="\1" src="\2" width="480" height="270">', out)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', out)
    return out


def convert(md: str) -> str:
    lines = md.splitlines()
    parts: list[str] = []
    para: list[str] = []
    list_tag = ""
    i = 0

    def flush_para() -> None:
        if para:
            parts.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def close_list() -> None:
        nonlocal list_tag
        if list_tag:
            parts.append(f"</{list_tag}>")
            list_tag = ""

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("```"):
            flush_para(); close_list()
            code: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            parts.append("<pre><code>" + html.escape("\n".join(code)) + "</code></pre>")
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            flush_para(); close_list()
            header = [c.strip() for c in stripped.strip("|").split("|")]
            rows: list[list[str]] = []
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            parts.append("<table><tr>" + "".join(f"<th>{inline(c)}</th>" for c in header) + "</tr>")
            for row in rows:
                parts.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>")
            parts.append("</table>")
            continue

        heading = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if heading:
            flush_para(); close_list()
            level = len(heading.group(1))
            parts.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
        elif stripped == "---":
            flush_para(); close_list()
            parts.append("<hr>")
        elif re.match(r"^[-*]\s+", stripped) or re.match(r"^\d+\.\s+", stripped):
            flush_para()
            tag = "ul" if re.match(r"^[-*]\s+", stripped) else "ol"
            if list_tag != tag:
                close_list()
                parts.append(f"<{tag}>")
                list_tag = tag
            item = re.sub(r"^([-*]|\d+\.)\s+", "", stripped)
            parts.append(f"<li>{inline(item)}</li>")
        elif not stripped:
            flush_para(); close_list()
        else:
            close_list()
            para.append(stripped)
        i += 1

    flush_para(); close_list()
    return "\n".join(parts)


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    source = Path(sys.argv[1])
    body = convert(source.read_text(encoding="utf-8"))
    title = source.stem
    page = (f'<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8"><title>{title}</title>'
            f"<style>{CSS}</style></head><body>{body}</body></html>")
    Path(sys.argv[2]).write_text(page, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
