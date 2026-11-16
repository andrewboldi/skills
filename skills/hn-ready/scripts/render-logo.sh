#!/usr/bin/env bash
# render-logo.sh SVG OUT.png [DISPLAY_PX]
# Renders a logo into one PNG to look at. The top row is on white, the bottom row on GitHub's
# dark background (#0d1117). The left column is a 512 px render, for checking shapes. The right
# column is the README's display size (default 132 px), shown at its real size.
set -euo pipefail
[[ $# -ge 2 ]] || { sed -n '2,5p' "$0" >&2; exit 2; }
svg=$1 out=$2 px=${3:-132}
[[ -f $svg ]] || { echo "no such file: $svg" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# render WIDTH FILE: the SVG as a transparent PNG, WIDTH pixels wide
render() {
	if command -v rsvg-convert > /dev/null; then
		rsvg-convert -w "$1" -o "$2" "$svg"
	elif command -v inkscape > /dev/null; then
		inkscape "$svg" --export-type=png --export-filename="$2" -w "$1" > /dev/null 2>&1
	else
		magick -background none -density 384 "$svg" -resize "$1x" "$2"
	fi
}

render 512 "$tmp/big.png"
render "$px" "$tmp/small.png"
for bg in white '#0d1117'; do
	n=${bg/\#/}
	magick -size 560x560 "xc:$bg" "$tmp/big.png" -gravity center -composite "$tmp/big-$n.png"
	magick -size 560x560 "xc:$bg" "$tmp/small.png" -gravity center -composite "$tmp/small-$n.png"
done
magick \( "$tmp/big-white.png" "$tmp/small-white.png" +append \) \
	\( "$tmp/big-0d1117.png" "$tmp/small-0d1117.png" +append \) -append "$out"
echo "$out: top row on white, bottom on #0d1117; left 512 px, right ${px} px (README size)"
