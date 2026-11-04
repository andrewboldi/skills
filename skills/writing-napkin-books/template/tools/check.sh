#!/bin/bash
# Regression checks for the book. Run from anywhere:  bash tools/check.sh
# Exit status is non-zero if a hard check (FAIL) fails; soft findings are printed as NOTE.
# When a new kind of mistake slips through, add a check for it here.
set -u
G="$(cd "$(dirname "$0")/.." && pwd)"
cd "$G" || exit 2
source tools/book.env
fail=0
notes=0
note() { echo "NOTE: $*"; notes=$((notes+1)); }
bad()  { echo "FAIL: $*"; fail=1; }

echo "== 1. build"
if ! latexmk -interaction=nonstopmode -halt-on-error main.tex > build.log 2>&1; then
  bad "latexmk failed (see $G/build.log)"; exit 1
fi
LOG=build/main.log

echo "== 2. unresolved citations / references, multiply defined labels"
if python3 -I - "$LOG" <<'EOF'
import re, sys
log = open(sys.argv[1], encoding="utf-8", errors="replace").read()
# LaTeX quotes the key as `key' or 'key' depending on the kernel version; biblatex reports missing entries separately.
hits = re.findall(r"(Citation [`'][^']*' [^\n]*undefined|Reference [`'][^']*' [^\n]*undefined|There were undefined references"
                  r"|Label\(s\) may have changed|Label [`'][^']*' multiply defined"
                  r"|The following entry could not be found\s+in the database:\s+\S+)", log)
for h in hits[:10]: print("  ", h)
sys.exit(1 if hits else 0)
EOF
then echo "  ok"; else bad "undefined citations/references, labels defined twice, or labels that changed (rerun latexmk)"; fi

echo "== 3. overfull boxes wider than 1pt"
if python3 -I - "$LOG" <<'EOF'
import re, sys
log = open(sys.argv[1], encoding="utf-8", errors="replace").read()
big = [(float(m.group(1)), m.group(2).strip()[:70]) for m in
       re.finditer(r"Overfull \\hbox \(([0-9.]+)pt too wide\)[^\n]*\n([^\n]*)", log) if float(m.group(1)) > 1.0]
print(f"  {len(big)} overfull hbox(es) > 1pt")
for w, t in big[:8]: print(f"   {w:6.1f}pt  {t}")
sys.exit(1 if big else 0)
EOF
then echo "  ok"; else bad "lines stick out into the margin (rephrase, \\allowbreak, or use tabularx)"; fi

echo "== 4. spelling (SPELLING=$SPELLING)"
if [ "$SPELLING" = "american" ]; then
  out=$(python3 -I tools/americanize.py "$G" | tail -1)
  echo "  $out"
  [ "$out" = "changed lines: 0" ] || note "British spellings or day-month dates found; run: python3 -I tools/americanize.py . --write"
else
  echo "  skipped"
fi

echo "== 5. placeholders in the PDF text"
pdftotext -layout build/main.pdf build/main.txt
if python3 -I - <<'EOF'
import re, sys
t = open("build/main.txt", encoding="utf-8").read()
hits = re.findall(r".{0,40}(?:TODO|FIXME|XXX|\?\?|FILL IN).{0,50}", t)
for h in hits[:40]: print("  ", " ".join(h.split()))
print(f"  {len(hits)} placeholder(s); find their sources with: grep -rn 'fillin' bookmeta.tex chapters figures")
sys.exit(1 if hits else 0)
EOF
then echo "  ok"; else bad "placeholder text in the PDF (\\fillin markers, ?? from missing labels, TODO)"; fi

echo "== 5b. the book claims only checks that were done"
if python3 -I - <<'EOF'
import glob, re, sys
t = " ".join(open("build/main.txt", encoding="utf-8").read().split())
t = re.sub(r"\[FILL IN:[^\]]*\]", " ", t)          # placeholders are reported by check 5
claims = []
for m in re.finditer(r"fact-check|independent(?:ly)? check|independent reader", t, flags=re.I):
    before = t[max(0, m.start() - 50):m.start()]
    if re.search(r"\b(?:no|not|never|without|none|nobody)\b", before.split(".")[-1], flags=re.I):
        continue                                 # "no independent reader has checked the text" is an honest disclosure
    claims.append(t[max(0, m.start() - 40):m.end() + 40])
reports = [f for f in glob.glob("provenance/factcheck/*.md")]
if claims and not reports:
    for c in claims[:5]: print("  ", c)
    print("  the book mentions fact-checks, but provenance/factcheck/ holds no report")
    sys.exit(1)
print(f"  {len(claims)} mention(s) of checks, {len(reports)} report(s) in provenance/factcheck/")
EOF
then echo "  ok"; else bad "describe only the checks that were actually done (or add the reports)"; fi

echo "== 6. reference requests left in the sources"
if python3 -I - <<'EOF'
import glob, re, sys
hits = []
for f in sorted(glob.glob("chapters/*.tex") + glob.glob("figures/*.tex") + ["main.tex"]):
    for i, line in enumerate(open(f, encoding="utf-8"), 1):
        if re.search(r"NEED REF|\\needref\b", line):
            hits.append(f"{f}:{i}: {line.strip()[:90]}")
for h in hits[:12]: print("  ", h)
sys.exit(1 if hits else 0)
EOF
then echo "  ok"; else bad "NEED REF markers remain: find a verified source or cut the claim"; fi

echo "== 7. generated files are reproducible"
tmp=$(mktemp -d)
python3 -I tools/build_meta.py tools/data/candidates.tsv tools/data/venues.tsv tools/data/arxiv_meta.json "$tmp" > /dev/null
for f in papers.tex refs_auto.bib; do
  cmp -s "$tmp/$f" "$G/$f" && echo "  $f identical" || bad "$f differs from what build_meta.py generates (rerun tools/add_arxiv.py or build_meta.py; never edit it by hand)"
done
rm -rf "$tmp"

echo "== 8. labels, inputs and orphan figures"
if python3 -I - "$LABEL_TYPES" <<'EOF'
import collections, glob, os, re, sys
types = sys.argv[1]
srcs = sorted(glob.glob("chapters/*.tex") + glob.glob("figures/*.tex") + ["main.tex"])
def code(f):  # the file without comments
    return "\n".join(re.sub(r"(?<!\\)%.*", "", l) for l in open(f, encoding="utf-8"))
bad, seen = [], collections.defaultdict(list)
inputs = set()
for f in srcs:
    c = code(f)
    for lab in re.findall(r"\\label\{([^}]+)\}", c):
        seen[lab].append(f)
        if not re.match(rf"({types}):", lab):
            bad.append(f"{f}: label {lab} does not start with one of {types}:")
    for inp in re.findall(r"\\input\{([^}]+)\}", c):
        inputs.add(inp)
        if not (os.path.exists(inp) or os.path.exists(inp + ".tex")):
            bad.append(f"{f}: \\input{{{inp}}} has no file")
bad += [f"label {lab} defined in {fs}" for lab, fs in seen.items() if len(fs) > 1]
orphans = [f for f in glob.glob("figures/*.tex") + glob.glob("chapters/*.tex") if f[:-4] not in inputs and f not in inputs]
print(f"  {len(seen)} labels, {len(inputs)} inputs, {len(bad)} problem(s)")
for b in bad[:12]: print("  ", b)
if orphans: print("NOTE: chapter or figure files that nothing \\inputs (include or delete them):", ", ".join(sorted(orphans)))
sys.exit(1 if bad else 0)
EOF
then echo "  ok"; else bad "label or input problems"; fi

echo "== 9. layout: pages that end early (pushed boxes or floats) and stub chapter endings"
python3 -I - <<'EOF'
import re, statistics, subprocess
out = subprocess.run(["pdftotext", "-bbox", "build/main.pdf", "-"], capture_output=True, text=True).stdout
pages = []
for pg in re.findall(r"<page [^>]*>(.*?)</page>", out, flags=re.S):
    words = [(float(a), float(b), w) for a, b, w in
             re.findall(r'<word xMin="[\d.]+" yMin="([\d.]+)" xMax="[\d.]+" yMax="([\d.]+)">([^<]*)</word>', pg)]
    pages.append(words)
def big(words):            # a chapter or part heading: a word at least 20pt tall in the top half
    return any(y1 - y0 > 20 and y0 < 400 for y0, y1, w in words)
bottoms = [max(y1 for y0, y1, w in p) for p in pages if p]
foot = statistics.median(bottoms) if bottoms else 0              # the running foot (page number) line
body_end = [max([y1 for y0, y1, w in p if y1 < foot - 6] or [0]) for p in pages]
full = sorted(body_end)[int(0.9 * (len(body_end) - 1))] if body_end else 0
gaps, stubs = [], []
for i, p in enumerate(pages):
    if not p or i < 2 or i == len(pages) - 1 or big(p) and len(p) < 25:
        continue                                                 # title page and verso, last page, part pages
    nxt_new = big(pages[i + 1])
    tops = [y0 for y0, y1, w in p if y1 < foot - 6]
    top = min(tops) if tops else 0
    if nxt_new and body_end[i] - top < 0.15 * (full - 80):
        stubs.append(i + 1)
    elif not nxt_new and full - body_end[i] > 0.25 * (full - 80):
        gaps.append(i + 1)
print(f"  {len(pages)} pages")
print(f"  pages ending more than a quarter early, not before a new chapter: {gaps or 'none'}")
print(f"  chapter-ending pages less than 15% full: {stubs or 'none'}")
print("  (look at these pages; fix locally, see the skill's style reference, Layout repair)")
EOF

echo "== 10. the listing of the papers matches the length of the book"
python3 -I - <<'EOF'
import json, os, subprocess, sys
if not os.path.exists("build/papers_order.json"):
    print("  no build/papers_order.json yet (run tools/build_volume.sh once papers are downloaded)")
    sys.exit(0)
meta = json.load(open("build/papers_order.json", encoding="utf-8"))
n = int([l for l in subprocess.run(["pdfinfo", "build/main.pdf"], capture_output=True, text=True).stdout.splitlines() if l.startswith("Pages:")][0].split()[1])
ok = meta["guide_pages"] == n
print(f"  listing made for {meta['guide_pages']} pages, book has {n}" + ("" if ok else "  -> run tools/build_volume.sh"))
m = len(meta["papers"])
if m:   # the table must be in the PDF, not only in papers_listing.tex
    text = " ".join(open("build/main.txt", encoding="utf-8").read().split())
    if f"in {m} papers; the first starts on page" not in text and f"in {m} paper; the first starts on page" not in text:
        print(f"  the PDF does not contain the listing of the {m} papers (stale build?)")
        ok = False
sys.exit(0 if ok else 1)
EOF
[ $? -eq 0 ] || note "the page numbers in the listing of the papers are stale (run tools/build_volume.sh)"

echo "== 11. prices (state them only with a source and a date)"
python3 -I - <<'EOF'
import glob, re
hits = []
for f in sorted(glob.glob("chapters/*.tex")):
    for i, line in enumerate(open(f, encoding="utf-8"), 1):
        if line.lstrip().startswith("%"): continue
        if re.search(r"\\\$\s?\d|(?:USD|EUR|GBP)\s?\d|\d\s?(?:USD|dollars|euros)\b|[€£]\s?\d", line):
            hits.append(f"{f}:{i}")
print("  " + (f"NOTE: possible prices at {hits[:10]}" if hits else "none found"))
EOF

echo "== 12. listings reproduce their saved output (figures/src/<name>.py with <name>.out)"
if python3 -I - <<'EOF'
import glob, os, subprocess, sys
bad, n = [], 0
for out in sorted(glob.glob("figures/src/*.out")):
    py = out[:-4] + ".py"
    if not os.path.exists(py):
        continue
    n += 1
    try:
        got = subprocess.run([sys.executable, "-I", os.path.basename(py)], cwd=os.path.dirname(py),
                             capture_output=True, text=True, timeout=120).stdout
    except subprocess.TimeoutExpired:
        bad.append(f"{py}: timed out"); continue
    if got != open(out, encoding="utf-8").read():
        bad.append(f"{py}: output differs from {os.path.basename(out)}")
print(f"  {n} listing(s) rerun, {len(bad)} problem(s)")
for b in bad: print("  ", b)
sys.exit(1 if bad else 0)
EOF
then echo "  ok"; else bad "a quoted listing output is not what the script prints now (rerun it, update the .out and the text)"; fi

[ $fail -eq 0 ] && echo "ALL HARD CHECKS PASSED ($notes note(s) above)" || echo "SOME CHECKS FAILED ($notes note(s) above)"
exit $fail
