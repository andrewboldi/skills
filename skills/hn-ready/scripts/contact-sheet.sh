#!/usr/bin/env bash
# contact-sheet.sh GIF OUT.png [SECONDS]
# Takes one frame every SECONDS (default 2) of a GIF and tiles them at half size, six to a sheet
# with the time under each, so every part of a demo can be looked at. Writes OUT-0.png,
# OUT-1.png, ... and keeps the frames at full size in OUT-frames/ for a closer look.
set -euo pipefail
[[ $# -ge 2 ]] || { sed -n '2,5p' "$0" >&2; exit 2; }
gif=$1 out=${2%.png} every=${3:-2}
[[ -f $gif ]] || { echo "no such file: $gif" >&2; exit 1; }
full=$out-frames half=$(mktemp -d)
trap 'rm -rf "$half"' EXIT
mkdir -p "$full"
rm -f "$full"/f*.png "$out"-[0-9]*.png
ffmpeg -loglevel error -i "$gif" -vf "fps=1/$every" "$full/f%03d.png"
ffmpeg -loglevel error -i "$gif" -vf "fps=1/$every,scale=iw/2:-1" "$half/f%03d.png"

args=()
i=0
for f in "$half"/f*.png; do
	args+=(-label "$((i * every))s" "$f")
	i=$((i + 1))
done
((i > 0)) || { echo "no frames extracted from $gif" >&2; exit 1; }
montage "${args[@]}" -tile 2x3 -geometry +6+6 -pointsize 16 -background '#444' -fill white \
	"$out-%d.png"
echo "$i frames, one every ${every}s:" "$out"-[0-9]*.png
echo "full-size frames: $full/"
