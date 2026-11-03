#!/bin/bash
# Regression checks for the book. Run from anywhere:  bash tools/check.sh
# Exit status is non-zero if a hard check (FAIL) fails; soft findings are printed as NOTE.
# When a new kind of mistake slips through, add a check for it here.
set -u
G="$(cd "$(dirname "$0")/.." && pwd)"
cd "$G" || exit 2
source tools/book.env
fail=0
note() { echo "NOTE: $*"; }
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
python3 -I - "$LOG" <<'EOF'
import re, sys
log = open(sys.argv[1], encoding="utf-8", errors="replace").read()
big = [float(m.group(1)) for m in re.finditer(r"Overfull \\hbox \(([0-9.]+)pt too wide", log) if float(m.group(1)) > 1.0]
print(f"  {len(big)} overfull hbox(es) > 1pt" + (f": {big[:8]}" if big else ""))
EOF

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
hits = re.findall(r".{0,30}(?:TODO|FIXME|XXX|\?\?|FILL IN).{0,30}", t)
for h in hits[:12]: print("  ", repr(h))
print(f"  {len(hits)} placeholder(s)")
sys.exit(1 if hits else 0)
EOF
then echo "  ok"; else bad "placeholder text in the PDF (\\fillin markers, ?? from missing labels, TODO)"; fi

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

echo "== 9. layout summary"
python3 -I - <<'EOF'
t = open("build/main.txt", encoding="utf-8").read().split("\f")[:-1]
sparse = []
for i, p in enumerate(t, 1):
    lines = [l.strip() for l in p.split("\n") if l.strip()]
    c = sum(len(l) for l in lines)
    if lines and c < 700 and i > 4 and not lines[0].startswith("Contents") and c > 40:   # part pages hold only a numeral and a title
        sparse.append((i, c))
print(f"  {len(t)} pages; sparse (<700 characters, not part pages): {sparse}")
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

[ $fail -eq 0 ] && echo "ALL HARD CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
