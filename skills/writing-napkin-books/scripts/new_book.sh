#!/bin/bash
# Create a new book from the template:
#
#   bash scripts/new_book.sh <target-dir> "<Title>" "<Short title>" [File_Name]
#
# Copies template/ into <target-dir> (which must be new or empty), fills in the title, the short title (running
# head and cover), today's date, the version stamp and the output file name (tools/book.env), runs `git init` unless
# the target is already inside a git repository, and runs a first build. The red \fillin markers stay until they
# are replaced; tools/check.sh fails while any remain.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
usage='usage: new_book.sh <target-dir> "<Title>" "<Short title>" [File_Name]'
dest=${1:?$usage}
title=${2:?$usage}
short=${3:?$usage}
fname=${4:-$(printf '%s' "$short" | tr -cs 'A-Za-z0-9' '_' | sed 's/^_*//; s/_*$//')}

if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
  echo "$dest exists and is not empty; choose a new directory"; exit 1
fi
mkdir -p "$dest"
free_kb=$(df -Pk "$dest" | awk 'NR==2 {print $4}')
if [ "$free_kb" -lt 2097152 ]; then
  echo "less than 2 GB free on the disk of $dest; free space before building a book"; exit 1
fi
for tool in latexmk pdflatex biber pdftoppm pdftotext pdfinfo; do
  command -v "$tool" >/dev/null || echo "WARNING: $tool not found (install TeX Live and poppler-utils)"
done

cp -R "$here/template/." "$dest/"
python3 -I - "$dest" "$title" "$short" "$fname" <<'EOF'
import datetime, re, sys
dest, title, short, fname = sys.argv[1:5]
def tex(s):
    return re.sub(r"([&%#_$])", r"\\\1", s)
today = datetime.date.today()
date_us = today.strftime("%B ") + str(today.day) + today.strftime(", %Y")
p = f"{dest}/bookmeta.tex"
s = open(p, encoding="utf-8").read()
for a, b in (("BOOK TITLE", tex(title)), ("SHORT TITLE", tex(short)), ("BOOK DATE", date_us),
             ("BOOKSTAMP", today.strftime("%Y%m%d"))):
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
p = f"{dest}/tools/book.env"
s = open(p, encoding="utf-8").read().replace("BOOK_FILE_NAME", fname)
open(p, "w", encoding="utf-8").write(s)
print(f"title: {title}\nshort title: {short}\ndate: {date_us}\noutput: {fname}.pdf")
EOF

if git -C "$dest" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "inside an existing git repository: not running git init"
else
  git -C "$dest" init -q && echo "git init: $dest (nothing committed yet)"
fi

cd "$dest"
if latexmk -interaction=nonstopmode -halt-on-error main.tex > build.log 2>&1; then
  echo "first build ok: $dest/build/main.pdf ($(pdfinfo build/main.pdf | awk '/^Pages:/{print $2}') pages)"
  echo "next: bash tools/check.sh   (it lists the \\fillin markers that remain)"
else
  echo "first build FAILED; see $dest/build.log"; exit 1
fi
