#!/usr/bin/env bash
# colab-browser's scripts, without a browser or a Google account: argument handling, the profile
# choice, and the connect-button rule that decides whether a runtime is attached.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
s=$here/skills/colab-browser/scripts
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

node --check "$s/colab.cjs"
check "colab.cjs parses" 0 $?
node "$s/colab.cjs" help > "$D/help"
check "colab.cjs help exits 0" 0 $?
check "help lists the commands" 4 "$(grep -cE '^  node colab.cjs (status|outputs|stop|watch)' "$D/help")"

rule() { node -e 'const c = require(process.argv[1]); console.log(c.isDisconnected(process.argv[2]))' "$s/colab.cjs" "$1"; }
check "Reconnect means no runtime" true "$(rule 'Reconnect L4 arrow_drop_down')"
check "Connect means no runtime" true "$(rule 'Connect arrow_drop_down')"
check "RAM and disk meters mean attached" false "$(rule 'RAM Disk arrow_drop_down')"
check "the runtime menu means attached" false "$(rule 'more_horiz arrow_drop_down')"
check "Connected is not Connect" false "$(rule 'Connected to Python 3 backend')"

flags=$(node -e 'const c = require(process.argv[1]); console.log(JSON.stringify(c.parseFlags(["--idle-min", "5", "--poll-s", "30"])))' "$s/colab.cjs")
check "watch flags" '{"idleMin":5,"quietMin":15,"pollS":30}' "$flags"

out=$(HOME=$D COLAB_BROWSER=/snap/bin/chromium bash "$s/launch-browser.sh" --dry-run | sed -n 2p)
check "a snap browser keeps its profile inside ~/snap" "profile: $D/snap/chromium/common/colab-agent-profile" "$out"
out=$(HOME=$D COLAB_BROWSER=/usr/bin/google-chrome bash "$s/launch-browser.sh" --dry-run --port 9333 | sed -n 2,3p | tr '\n' ' ')
check "other browsers use ~/.cache, and --port is honoured" "profile: $D/.cache/colab-agent-profile port:    9333 " "$out"
bash "$s/launch-browser.sh" --bogus > /dev/null 2>&1
check "an unknown option exits 2" 2 $?

echo "colab-browser scripts: $pass passed, $fail failed"
[ "$fail" = 0 ]
