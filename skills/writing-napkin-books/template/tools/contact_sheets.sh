#!/bin/bash
# Render every page of a PDF small and tile them 12 to a sheet, for a visual pass over the whole book
# (sparse pages, stranded headings, split boxes, figures far from their text, overlapping labels).
#
#   bash tools/contact_sheets.sh build/main.pdf build/qa [dpi]
#
# Writes <outdir>/p-*.png (one per page) and <outdir>/sheet<N>.png (6 x 2 pages each); look at every sheet, then
# render suspicious pages at 120 dpi with pdftoppm -r 120 -f N -l N and crop them.
set -euo pipefail
pdf=${1:?usage: contact_sheets.sh <file.pdf> <outdir> [dpi]}
out=${2:?usage: contact_sheets.sh <file.pdf> <outdir> [dpi]}
dpi=${3:-40}
mkdir -p "$out"
rm -f "$out"/p-*.png "$out"/sheet*.png
pdftoppm -r "$dpi" -png "$pdf" "$out/p"
mapfile -t pages < <(ls "$out"/p-*.png | sort -V)
for ((s = 0; s * 12 < ${#pages[@]}; s++)); do
  montage "${pages[@]:s*12:12}" -tile 6x2 -geometry +3+3 "$out/sheet$s.png"
done
ls "$out"/sheet*.png
