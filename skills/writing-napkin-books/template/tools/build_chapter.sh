#!/bin/bash
# Build one chapter on its own, for drafting and checking:
#
#   bash tools/build_chapter.sh chapters/ch03_name.tex [--png]
#
# The test document is preamble + the chapter + its bibliography, built in build/chap/ (several chapters can be
# built at the same time; each has its own files). The chapter number comes from the file name: chNN_... is
# chapter NN; a prefix listed in LETTER_PREFIXES of tools/book.env (for example "cc:C") makes ccNN_... chapter CNN.
# Labels defined in other chapters stay unresolved here (they print as ??); citations must resolve.
# With --png, every page is also rendered to build/chap/t_<name>-<page>.png (70 dpi) for looking at the figures.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source tools/book.env
src=${1:?usage: build_chapter.sh chapters/<file>.tex [--png]}
name=$(basename "$src" .tex)
out=build/chap
mkdir -p "$out"
setup=""
if [[ "$name" =~ ^([a-z]+)([0-9]{2})_ ]]; then
  prefix=${BASH_REMATCH[1]}
  n=$((10#${BASH_REMATCH[2]}))
  for pair in $LETTER_PREFIXES; do
    [ "${pair%%:*}" = "$prefix" ] && setup="\\letterpartbegin{${pair#*:}}"
  done
  [ "$n" -ge 1 ] && setup="$setup\\setcounter{chapter}{$((n-1))}"
fi
printf '%s\n' '\input{preamble}' '\begin{document}' '\mainmatter' \
  '\renewcommand{\thesection}{\thechapter.\arabic{section}}' "$setup" \
  "\\input{chapters/$name}" '\printbibliography' '\end{document}' > "$out/t_$name.tex"
nice -n 10 latexmk -interaction=nonstopmode -halt-on-error -outdir="$out" "$out/t_$name.tex" > "$out/t_$name.latexmk.txt" 2>&1
status=$?
python3 -I tools/log_summary.py "$out/t_$name.log" "$status"
if [ "$status" -ne 0 ]; then echo "(see $out/t_$name.latexmk.txt and $out/t_$name.log)"; fi
if [ "${2:-}" = "--png" ] && [ -f "$out/t_$name.pdf" ]; then
  rm -f "$out"/t_"$name"-*.png
  pdftoppm -r 70 -png "$out/t_$name.pdf" "$out/t_$name"
  ls "$out"/t_"$name"-*.png | wc -l | xargs echo "png pages written:"
fi
exit $status
