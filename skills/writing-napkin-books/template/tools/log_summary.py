#!/usr/bin/env python3
"""Summarize a LaTeX log in a few lines: pages, errors, undefined citations and references, overfull boxes, floats.

usage: python3 -I log_summary.py <file.log> [latexmk-exit-status]

Used by build_chapter.sh. References to labels in other chapters are expected to be undefined when a chapter is built
on its own, so they are listed as information; undefined citations are always a problem.
"""
import re
import sys

log = open(sys.argv[1], encoding="utf-8", errors="replace").read()
status = int(sys.argv[2]) if len(sys.argv) > 2 else 0

m = re.search(r"Output written on [^\n]*\((\d+) pages?", log)
print(f"pages: {m.group(1) if m else 'no output'}   (latexmk exit status {status})")

errs = re.findall(r"^! ([^\n]*)\n(?:[^\n]*\n)?(l\.\d+[^\n]*)?", log, flags=re.M)
for e, where in errs[:6]:
    print(f"ERROR: {e}  {where}".rstrip())

def undefined_citations(log):
    # LaTeX quotes the key as `key' or 'key' depending on the kernel version; biblatex reports a missing entry in
    # its own warning, wrapped over "(biblatex)" continuation lines, which are joined first.
    joined = re.sub(r"\n\(biblatex\)\s+", " ", log)
    return sorted(set(re.findall(r"Citation [`']([^']*)' on page \d+ undefined", log))
                  | set(re.findall(r"The following entry could not be found in the database: (\S+)", joined)))


# Self-test: the warning forms that must be recognized (add one whenever a new form slips through).
for sample in ("LaTeX Warning: Citation 'k' on page 1 undefined on input line 2.",
               "LaTeX Warning: Citation `k' on page 1 undefined on input line 2.",
               "Package biblatex Warning: The following entry could not be found\n"
               "(biblatex)                in the database:\n(biblatex)                k\n"):
    assert undefined_citations(sample) == ["k"], "log_summary.py no longer recognizes: " + sample
cites = undefined_citations(log)
if cites:
    print("UNDEFINED CITATIONS:", ", ".join(cites))
refs = sorted(set(re.findall(r"Reference [`']([^']*)' on page \d+ undefined", log)))
if refs:
    print("undefined references (fine if the label lives in another chapter):", ", ".join(refs[:25]))
if "multiply defined" in log:
    print("WARNING: some labels are multiply defined")

big = []
for mm in re.finditer(r"Overfull \\hbox \(([0-9.]+)pt too wide\)[^\n]*\n([^\n]*)", log):
    if float(mm.group(1)) > 1.0:
        big.append((float(mm.group(1)), mm.group(2).strip()[:90]))
print(f"overfull hboxes wider than 1pt: {len(big)}")
for w, txt in big[:8]:
    print(f"   {w:6.1f}pt  {txt}")

for mm in re.finditer(r"(Float too large for page by [0-9.]+pt[^\n]*)", log):
    print("WARNING:", mm.group(1))
warn = []
for mm in re.finditer(r"^((?:Package|Class) (\w+) Warning: [^\n]*)", log, flags=re.M):
    if mm.group(2) not in ("hyperref", "microtype", "xcolor", "biblatex", "bookmark") and mm.group(1) not in warn:
        warn.append(mm.group(1))
for w in warn[:6]:
    print("warning:", w[:160])
