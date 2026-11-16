#!/usr/bin/env bash
# check-readme.sh [README.md]
# Checks what a visitor would see broken in a README:
#   - every shields.io badge renders, and doesn't say "not found", "failing", "no status" ...
#   - every relative link and image points at a file in the repo, and every #anchor at a heading
#   - external links answer (warnings only: some sites refuse scripts)
#   - how many fenced code blocks there are (the recipe has one: the install line)
# Exits 1 if a badge, a relative link or an anchor is broken.
set -uo pipefail
readme=${1:-README.md}
[[ -f $readme ]] || { echo "no such file: $readme" >&2; exit 2; }
dir=$(dirname "$readme")
bad=0

echo "== badges"
while read -r url; do
	url=${url//&amp;/\&} # bash 5.2 reads a bare & in the replacement as the matched text
	text=$(curl -fsS --max-time 20 "$url" 2> /dev/null | grep -oE 'aria-label="[^"]*"' | head -1)
	text=${text#aria-label=\"}
	text=${text%\"}
	if [[ -z $text || $text =~ not\ found|invalid|inaccessible|failing|no\ status|unknown|error|no\ releases ]]; then
		echo "BROKEN  ${text:-no answer}  $url"
		bad=1
	else
		echo "ok      $text"
	fi
done < <(grep -oE 'https://img\.shields\.io/[^")[:space:]]+' "$readme" | sort -u)

# GitHub's heading anchors: lowercase, punctuation dropped, spaces to hyphens
anchors=$(grep -E '^#{1,6} ' "$readme" | sed -E 's/^#+ +//' | tr '[:upper:]' '[:lower:]' |
	sed -E 's/[^a-z0-9 _-]//g; s/ /-/g')

echo "== links"
while read -r link; do
	case $link in
	mailto:*) ;;
	http://* | https://*)
		[[ $link == https://img.shields.io/* ]] && continue
		code=$(curl -sS -o /dev/null -L --max-time 20 -w '%{http_code}' "$link" 2> /dev/null)
		[[ $code == 2* ]] || echo "warn    $code  $link"
		;;
	\#*)
		grep -qxF "${link#\#}" <<< "$anchors" || { echo "BROKEN  no heading for $link"; bad=1; }
		;;
	*)
		[[ -e $dir/${link%%#*} ]] || { echo "BROKEN  missing file: $link"; bad=1; }
		;;
	esac
done < <(grep -oE '(href|src)="[^"]+"|\]\([^)[:space:]]+\)' "$readme" |
	sed -E 's/^(href|src)="//; s/"$//; s/^\]\(//; s/\)$//; s/&amp;/\&/g' | sort -u)
echo "checked; warnings are only external links that didn't answer 2xx"

echo "== code blocks"
fences=$(grep -cE '^ {0,3}```' "$readme")
echo "$((fences / 2)) fenced code block(s); the recipe has exactly one, the install line"

exit "$bad"
