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
check "help lists the commands" 8 "$(grep -cE '^  node colab.cjs (status|outputs|stop|watch|allowed|logclick|consent|popups)' "$D/help")"

rule() { node -e 'const c = require(process.argv[1]); console.log(c.isDisconnected(process.argv[2]))' "$s/colab.cjs" "$1"; }
check "Reconnect means no runtime" true "$(rule 'Reconnect L4 arrow_drop_down')"
check "Connect means no runtime" true "$(rule 'Connect arrow_drop_down')"
check "RAM and disk meters mean attached" false "$(rule 'RAM Disk arrow_drop_down')"
check "the runtime menu means attached" false "$(rule 'more_horiz arrow_drop_down')"
check "Connected is not Connect" false "$(rule 'Connected to Python 3 backend')"

flags=$(node -e 'const c = require(process.argv[1]); console.log(JSON.stringify(c.parseFlags(["--idle-min", "5", "--poll-s", "30"])))' "$s/colab.cjs")
check "watch flags" '{"idleMin":5,"quietMin":15,"pollS":30,"only":[],"ignore":[]}' "$flags"
flags=$(node -e 'const c = require(process.argv[1]); console.log(JSON.stringify(c.parseFlags(["--only", "train, eval.ipynb", "--ignore", "scratch"])))' "$s/colab.cjs")
check "--only and --ignore take comma lists" '{"idleMin":10,"quietMin":15,"pollS":120,"only":["train","eval.ipynb"],"ignore":["scratch"]}' "$flags"

out=$(HOME=$D COLAB_BROWSER=/snap/bin/chromium bash "$s/launch-browser.sh" --dry-run | sed -n 2p)
check "a snap browser keeps its profile inside ~/snap" "profile: $D/snap/chromium/common/colab-agent-profile" "$out"
out=$(HOME=$D COLAB_BROWSER=/usr/bin/google-chrome bash "$s/launch-browser.sh" --dry-run --port 9333 | sed -n 2,3p | tr '\n' ' ')
check "other browsers use ~/.cache, and --port is honoured" "profile: $D/.cache/colab-agent-profile port:    9333 " "$out"
bash "$s/launch-browser.sh" --bogus > /dev/null 2>&1
check "an unknown option exits 2" 2 $?

# Standing grants: allowed needs no browser.
cat > "$D/perm.json" << 'EOF2'
{"grants": [
  {"kinds": ["drive-mount", "colab-secret:HF_TOKEN"], "notebooks": ["train.ipynb"], "account": "user@example.com",
   "granted": "2026-01-31", "user_words": ["you may click it"]},
  {"kinds": ["drive-desktop-oauth"], "notebooks": ["*"], "granted": "2026-02-01", "user_words": ["agents may click continue"]}
]}
EOF2
allowed() { COLAB_PERMISSIONS="$D/perm.json" node "$s/colab.cjs" allowed "$@" > /dev/null; echo $?; }
check "a granted kind and notebook is allowed" 0 "$(allowed drive-mount train)"
check "the notebook matches with or without .ipynb" 0 "$(allowed drive-mount train.ipynb)"
check "another notebook is not" 3 "$(allowed drive-mount evaluate)"
check "an ungranted kind is not" 3 "$(allowed drive-desktop-oauth-x train)"
check "the grant's account must match" 3 "$(allowed colab-secret:HF_TOKEN train --account other@example.com)"
check "the right account is allowed" 0 "$(allowed colab-secret:HF_TOKEN train --account user@example.com)"
check "a * grant covers any notebook" 0 "$(allowed drive-desktop-oauth anything)"
COLAB_PERMISSIONS="$D/missing.json" node "$s/colab.cjs" allowed drive-mount train > /dev/null
check "no permissions file means not allowed" 3 $?

COLAB_CLICKS_LOG="$D/clicks.log" node "$s/colab.cjs" logclick drive-mount train.ipynb 'clicked "Connect to Google Drive"' > /dev/null
check "logclick appends one timestamped line" 1 "$(grep -cE '^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z drive-mount train clicked "Connect to Google Drive"$' "$D/clicks.log")"

# The consent-screen matcher, on screens described as text plus the count of the target button.
mc() { node -e 'const c = require(process.argv[1]); const r = c.matchConsent(process.argv[2], {text: process.argv[3], count: Number(process.argv[4])}, process.argv[5] || undefined); console.log(r.ok ? "ok" : "no")' "$s/colab.cjs" "$@"; }
mount='Permit this notebook to access your Google Drive files? No thanks Connect to Google Drive'
oauth="Sign in - Google Accounts You're signing back in to Google Drive for desktop user@example.com Cancel Continue"
check "the Drive dialog matches drive-mount" ok "$(mc drive-mount "$mount" 1)"
check "the Drive dialog is not the desktop sign-in" no "$(mc drive-desktop-oauth "$mount" 1)"
check "the desktop sign-in screen matches" ok "$(mc drive-desktop-oauth "$oauth" 1 user@example.com)"
check "a different account on screen is refused" no "$(mc drive-desktop-oauth "$oauth" 1 other@example.com)"
check "an account chooser is never covered" no "$(mc drive-desktop-oauth "Choose an account $oauth" 1)"
check "a password page is never covered" no "$(mc drive-desktop-oauth "$oauth Enter your password" 1)"
check "no target button: no click" no "$(mc drive-mount "$mount" 0)"
check "two target buttons: no click" no "$(mc drive-mount "$mount" 2)"
check "a secret-access dialog matches its secret" ok "$(mc colab-secret:HF_TOKEN 'Notebook does not have access to secret HF_TOKEN Grant access' 1)"
check "and not another secret" no "$(mc colab-secret:OTHER_KEY 'Notebook does not have access to secret HF_TOKEN Grant access' 1)"
check "an unknown kind is refused" no "$(mc licence 'Agree and access repository' 1)"
oauth2="Sign in - Google Accounts Google Drive for desktop wants access to your Google Account user@example.com Google Drive for desktop already has some access Cancel Continue"
check "the second desktop screen matches" ok "$(mc drive-desktop-oauth "$oauth2" 1 user@example.com)"
check "another app's access screen is refused" no "$(mc drive-desktop-oauth "Sign in - Google Accounts Photo Sync wants access to your Google Account user@example.com Cancel Continue" 1 user@example.com)"
mcu() { node -e 'const c = require(process.argv[1]); const r = c.matchConsent(process.argv[2], {text: process.argv[3], count: 1, unchecked: Number(process.argv[4])}); console.log(r.ok ? "ok" : "no")' "$s/colab.cjs" "$@"; }
check "a screen with unticked access boxes is refused" no "$(mcu drive-desktop-oauth "$oauth2" 2)"
check "a screen with every box ticked matches" ok "$(mcu drive-desktop-oauth "$oauth2" 0)"

# Which tabs a watch may stop: --only ones, else the permissions file's notebooks; others are only reported.
pol() { node -e 'const c = require(process.argv[1]); const perms = JSON.parse(require("fs").readFileSync(process.argv[2], "utf8")); console.log(c.tabPolicy(process.argv[3], c.parseFlags(JSON.parse(process.argv[4])), perms))' "$s/colab.cjs" "$D/perm.json" "$@"; }
check "a granted notebook is managed by default" manage "$(pol 'train.ipynb' '[]')"
check "another project's notebook is only reported" warn "$(pol 'survey.ipynb' '[]')"
check "a * grant does not make every tab managed" warn "$(pol 'anything.ipynb' '[]')"
check "--only manages the listed tab" manage "$(pol 'eval.ipynb' '["--only","eval"]')"
check "--only skips the rest" ignore "$(pol 'train.ipynb' '["--only","eval"]')"
check "--ignore wins over the permissions file" ignore "$(pol 'train.ipynb' '["--ignore","train"]')"

echo "colab-browser scripts: $pass passed, $fail failed"
[ "$fail" = 0 ]
