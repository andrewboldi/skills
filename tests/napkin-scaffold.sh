#!/usr/bin/env bash
# writing-napkin-books: new_book.sh scaffolds a book from the template, and the template's Python
# tools compile. The LaTeX build itself is stood in for here (stand-in latexmk and pdfinfo), so this
# needs no TeX Live; building the template for real in CI is bd issue skills-crz.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
skill=$here/skills/writing-napkin-books
pass=0 fail=0
check() {
	if [ "$2" = "$3" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3"
	fi
}
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/bin"
printf '#!/bin/sh\nmkdir -p build && : > build/main.pdf\n' > "$D/bin/latexmk"
printf '#!/bin/sh\necho "Pages: 1"\n' > "$D/bin/pdfinfo"
chmod +x "$D/bin/latexmk" "$D/bin/pdfinfo"

PATH="$D/bin:$PATH" bash "$skill/scripts/new_book.sh" "$D/book" "Quantum Error Correction & Friends" "QEC Guide" > "$D/out" 2>&1
check "new_book.sh succeeds" 0 $?
check "the title is filled in, escaped for LaTeX" yes \
	"$(grep -qF 'Quantum Error Correction \& Friends' "$D/book/bookmeta.tex" && echo yes || echo no)"
check "no placeholder is left in bookmeta.tex" 0 "$(grep -cE 'BOOK TITLE|SHORT TITLE|BOOK DATE|BOOKSTAMP' "$D/book/bookmeta.tex")"
check "the output file name comes from the short title" yes \
	"$(grep -q 'QEC_Guide' "$D/book/tools/book.env" && echo yes || echo no)"
check "the book gets its own git repository" yes "$([ -d "$D/book/.git" ] && echo yes || echo no)"

python3 -m py_compile "$skill"/template/tools/*.py "$skill"/template/figures/src/*.py 2> "$D/compile"
check "the template's Python tools compile" "" "$(cat "$D/compile")"

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
