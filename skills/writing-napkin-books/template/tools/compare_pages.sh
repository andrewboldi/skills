#!/bin/bash
# Check that the book's pages inside the combined PDF look exactly like the standalone book.
#   bash tools/compare_pages.sh <book.pdf> <combined.pdf> [page ...]
# Renders each page of both files at 50 dpi and counts the differing pixels (0 means identical). Without page
# numbers it compares the first, second, middle and last page of the book; pages beyond the book are skipped.
set -u
g=$1; c=$2; shift 2
n=$(pdfinfo "$g" | awk '/^Pages:/{print $2}')
pages=${*:-1 2 $(( (n + 1) / 2 )) $n}
tmp=$(mktemp -d)
for p in $pages; do
  if [ "$p" -lt 1 ] || [ "$p" -gt "$n" ]; then echo "page $p: skipped (the book has $n pages)"; continue; fi
  pdftoppm -r 50 -png -f "$p" -l "$p" "$g" "$tmp/g" 2>/dev/null
  pdftoppm -r 50 -png -f "$p" -l "$p" "$c" "$tmp/c" 2>/dev/null
  a=$(ls "$tmp"/g-*.png | head -1); b=$(ls "$tmp"/c-*.png | head -1)
  d=$(compare -metric AE "$a" "$b" /dev/null 2>&1 | head -1)
  echo "page $p: differing pixels = $d"
  rm -f "$tmp"/g-*.png "$tmp"/c-*.png
done
rm -rf "$tmp"
