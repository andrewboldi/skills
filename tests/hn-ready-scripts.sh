#!/usr/bin/env bash
# hn-ready's scripts that need nothing beyond Python and coreutils: the submit-link builder, and
# the README checker on a README with no network links.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
s=$here/skills/hn-ready/scripts
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

out=$(python3 "$s/submit-link.py" https://github.com/a/b "Show HN: B does one thing well")
check "submit-link: a good title passes" 0 $?
check "submit-link: the link is encoded" \
	"https://news.ycombinator.com/submitlink?u=https%3A%2F%2Fgithub.com%2Fa%2Fb&t=Show%20HN%3A%20B%20does%20one%20thing%20well" \
	"$(tail -1 <<< "$out")"
python3 "$s/submit-link.py" https://github.com/a/b "B is an amazing tool that does a great many wonderful things for every developer anywhere" > /dev/null 2> "$D/err"
check "submit-link: a long title without Show HN fails" 1 $?
check "submit-link: it says why" 2 "$(grep -c '^problem:' "$D/err")"

mkdir -p "$D/repo/docs"
touch "$D/repo/docs/caveats.md"
cat > "$D/repo/README.md" << 'EOF'
<a href="#install">Install</a> · <a href="docs/caveats.md">Caveats</a>

## Install

```sh
curl -fsSL https://example.invalid/install.sh | bash
```
EOF
bash "$s/check-readme.sh" "$D/repo/README.md" > "$D/out" 2>&1
check "check-readme: a good README passes" 0 $?
check "check-readme: counts one code block" yes "$(grep -q '^1 fenced code block' "$D/out" && echo yes || echo no)"
printf '%s\n' '<a href="#nowhere">x</a> <img src="assets/missing.svg">' >> "$D/repo/README.md"
bash "$s/check-readme.sh" "$D/repo/README.md" > "$D/out" 2>&1
check "check-readme: broken links fail" 1 $?
check "check-readme: names the missing anchor" yes "$(grep -q 'no heading for #nowhere' "$D/out" && echo yes || echo no)"
check "check-readme: names the missing file" yes "$(grep -q 'missing file: assets/missing.svg' "$D/out" && echo yes || echo no)"

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
