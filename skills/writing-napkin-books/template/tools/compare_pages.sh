#!/bin/bash
# Check that the book pages inside the combined PDF look exactly like the standalone book.
#   bash tools/compare_pages.sh <book.pdf> <combined.pdf> [page ...]
# Renders each page of both files at 50 dpi and counts the differing pixels (0 means identical).
set -u
g=$1; c=$2; shift 2
pages=${@:-1 2 20 60 100 120}
tmp=$(mktemp -d)
for p in $pages; do
  pdftoppm -r 50 -png -f "$p" -l "$p" "$g" "$tmp/g" 2>/dev/null
  pdftoppm -r 50 -png -f "$p" -l "$p" "$c" "$tmp/c" 2>/dev/null
  a=$(ls "$tmp"/g-*.png | head -1); b=$(ls "$tmp"/c-*.png | head -1)
  n=$(compare -metric AE "$a" "$b" /dev/null 2>&1 | head -1)
  echo "page $p: differing pixels = $n"
  /bin/rm -f "$tmp"/g-*.png "$tmp"/c-*.png
done
/bin/rm -rf "$tmp"
