#!/bin/bash
# Build the combined PDF: the book, then the cited arXiv papers, joined with pdfunite and repaired with pikepdf.
#
#   bash tools/build_volume.sh [papers-dir] [output.pdf]
#
# Defaults come from tools/book.env: papers in $PAPERS_DIR, output <BOOK_NAME>_with_papers.pdf in the book root.
# Needs the paper PDFs (python3 -I tools/make_cited_keys.py . > tools/data/cited_keys.json, then
# python3 -I tools/fetch_papers.py tools/data/cited_keys.json papers) and one earlier build of the book (so that biber
# has recorded the citations). The listing of the papers states the page on which each paper starts, and that
# depends on the length of the book, which includes the listing: the loop rebuilds the book until its page count
# no longer changes. Afterwards it copies the book alone to <BOOK_NAME>.pdf.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/book.env
PAPERS=${1:-$PAPERS_DIR}
OUT=${2:-${BOOK_NAME}_with_papers.pdf}

[ -f build/main.bcf ] || { echo "build the book once first: latexmk main.tex"; exit 1; }
python3 -I tools/make_cited_keys.py . > build/cited_keys.json
cp build/cited_keys.json tools/data/cited_keys.json
pages=${BOOK_PAGES:-$(pdfinfo build/main.pdf | awk '/^Pages:/{print $2}')}
for attempt in 1 2 3 4 5; do
  python3 -I tools/make_papers_listing.py --book-dir . --papers-dir "$PAPERS" --book-pages "$pages"
  latexmk -interaction=nonstopmode -halt-on-error main.tex > build/latexmk_out.txt 2>&1 || { tail -30 build/latexmk_out.txt; exit 1; }
  new=$(pdfinfo build/main.pdf | awk '/^Pages:/{print $2}')
  echo "book pages: assumed $pages, built $new"
  [ "$new" = "$pages" ] && break
  pages=$new
done
[ "$new" = "$pages" ] || { echo "the page count of the book did not settle"; exit 1; }
pdftotext build/main.pdf build/main.txt
python3 -I - <<'EOF'
import json, sys
m = len(json.load(open("build/papers_order.json", encoding="utf-8"))["papers"])
text = " ".join(open("build/main.txt", encoding="utf-8").read().split())
if m and f"in {m} paper" not in text:
    sys.exit(f"the book PDF does not contain the table of the {m} papers: latexmk did not rebuild after "
             "papers_listing.tex changed (is it \\input directly in chapters/papers_part.tex?)")
EOF
n=$(python3 -I -c "import json; print(len(json.load(open('build/papers_order.json'))['papers']))")
if [ "$n" -eq 0 ]; then
  echo "no arXiv papers are cited: nothing to append; the book alone is ${BOOK_NAME}.pdf"
else
  python3 -I tools/build_volume.py --guide build/main.pdf --order build/papers_order.json --papers-dir "$PAPERS" --out "$OUT"
fi
cp build/main.pdf "${BOOK_NAME}.pdf"    # the book alone (its papers table links into the combined file)
