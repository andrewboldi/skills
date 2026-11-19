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
check "help lists the commands" 10 "$(grep -cE '^  node colab.cjs (status|outputs|stop|watch|allowed|logclick|consent|popups|cli-signin|cli-drivemount)' "$D/help")"
COLAB_PERMISSIONS="$D/none.json" node "$s/colab.cjs" cli-drivemount sess > "$D/dm" 2>&1
check "cli-drivemount without a grant refuses before doing anything" "3 1" "$? $(grep -c '^NOT ALLOWED drive-desktop-oauth colab-cli' "$D/dm")"

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

# The Colab CLI's sign-in screens, as the automation browser shows them.
ms() { node -e 'const c = require(process.argv[1]); const s = JSON.parse(process.argv[2]); const r = c.matchCliSignin(s, process.argv[3] || undefined); console.log(r.ok ? r.action + (r.code ? ":" + r.code : "") : "no")' "$s/colab.cjs" "$@"; }
chooser='"text": "Sign in with Google Choose an account to continue to Google Auth Library User user@example.com Use another account"'
check "a one-account chooser for the CLI: choose it" tile "$(ms "{$chooser, \"tiles\": [\"user@example.com\"]}")"
check "a two-account chooser: no" no "$(ms "{$chooser, \"tiles\": [\"user@example.com\", \"other@example.com\"]}")"
check "the chooser must offer the grant's account" no "$(ms "{$chooser, \"tiles\": [\"other@example.com\"]}" user@example.com)"
check "another app's chooser: no" no "$(ms '{"text": "Choose an account to continue to Photo Sync", "tiles": ["user@example.com"]}')"
check "signing back in to the CLI's app: Continue" button "$(ms '{"text": "You'"'"'re signing back in to Google Auth Library user@example.com Cancel Continue", "count": 1}')"
check "the CLI's access screen: Continue" button "$(ms '{"text": "Google Auth Library wants access to your Google Account user@example.com Cancel Continue", "count": 1, "unchecked": 0}' user@example.com)"
check "unticked access boxes: no" no "$(ms '{"text": "Google Auth Library wants access to your Google Account Cancel Continue", "count": 1, "unchecked": 2}')"
check "a password page: no" no "$(ms '{"text": "Google Auth Library Enter your password", "count": 1}')"
check "the Drive-for-desktop screen is not the CLI's" no "$(ms '{"text": "You'"'"'re signing back in to Google Drive for desktop Cancel Continue", "count": 1}')"
check "the code page gives the code" "code:4/0AbCdEfGhIjKlMnOpQrStUvWxYz012" "$(ms '{"url": "https://sdk.cloud.google.com/applicationdefaultauthcode.html?state=x", "text": "Enter the following authorization code 4/0AbCdEfGhIjKlMnOpQrStUvWxYz012 Copy"}')"
check "a code page with no code: no" no "$(ms '{"url": "https://sdk.cloud.google.com/applicationdefaultauthcode.html", "text": "Something went wrong"}')"

# colab_job.py, run locally with a stand-in google.colab.runtime that records the release.
python3 -m py_compile "$s/colab_job.py"
check "colab_job.py compiles" 0 $?
mkdir -p "$D/py/google/colab"
: > "$D/py/google/__init__.py"
: > "$D/py/google/colab/__init__.py"
printf 'import os\ndef unassign():\n    open(os.environ["JOB_DIR"] + "/RELEASED", "w").write("x")\n' > "$D/py/google/colab/runtime.py"
printf 'import os\ndef flush_and_unmount():\n    open(os.environ["JOB_DIR"] + "/FLUSHED", "w").write("x")\n' > "$D/py/google/colab/drive.py"
job() { rm -rf "$D/jd"; env PYTHONPATH="$D/py" JOB_DIR="$D/jd" JOB_CWD="$D" DRIVE_DIR="$D/drive" GRACE_MIN=0 "$@" python3 "$s/colab_job.py" > "$D/job.out" 2>&1; }
job JOB_CMD='echo hello from the job'
check "a job that succeeds is DONE" DONE "$(cat "$D/jd/STATUS")"
check "the job's output time is recorded for the watch" 1 "$(ls "$D/jd/output" 2> /dev/null | wc -l | tr -d ' ')"
check "its output is in the log" 1 "$(grep -c '^hello from the job$' "$D/jd/log.txt")"
check "and it releases the runtime" 1 "$(ls "$D/jd/RELEASED" 2> /dev/null | wc -l | tr -d ' ')"
job JOB_CMD='exit 3'
check "a job that fails says FAILED rc=N" "FAILED rc=3" "$(cat "$D/jd/STATUS")"
check "and still releases the runtime" 1 "$(ls "$D/jd/RELEASED" 2> /dev/null | wc -l | tr -d ' ')"
check "no Drive mounted: nothing to flush" 0 "$(ls "$D/jd/FLUSHED" 2> /dev/null | wc -l | tr -d ' ')"
mkdir -p "$D/drive/MyDrive"
job JOB_CMD='true'
check "with Drive mounted, the runner flushes it" 1 "$(ls "$D/jd/FLUSHED" 2> /dev/null | wc -l | tr -d ' ')"
check "and still releases the runtime after" 1 "$(ls "$D/jd/RELEASED" 2> /dev/null | wc -l | tr -d ' ')"
rm -rf "$D/drive"
job JOB_CMD='true' KEEP_RUNTIME=1
check "KEEP_RUNTIME=1 keeps the runtime" 0 "$(ls "$D/jd/RELEASED" 2> /dev/null | wc -l | tr -d ' ')"
# The deadline must stop the whole job, not just the shell: a pipeline and a ';' list both outlive a SIGTERM to sh.
for cmd in 'sleep 1; sleep 307' 'sleep 307 | cat'; do
	t0=$(date +%s)
	job JOB_CMD="$cmd" MAX_HOURS=0.0003 HEARTBEAT_S=1
	check "the deadline ends '$cmd' within seconds" yes "$([ $(($(date +%s) - t0)) -lt 40 ] && echo yes || echo no)"
	check "and says so in STATUS" "FAILED deadline 0.0003 h" "$(cat "$D/jd/STATUS")"
	check "and leaves no process behind" 0 "$(pgrep -f '^sleep 307' | wc -l | tr -d ' ')"
	check "and releases the runtime" 1 "$(ls "$D/jd/RELEASED" 2> /dev/null | wc -l | tr -d ' ')"
done
job JOB_CMD='true' JOB_CWD="$D/missing"
check "a job that cannot start is FAILED" FAILED "$(cat "$D/jd/STATUS")"
check "with the reason in its log" 1 "$(grep -c '^\[error\] FileNotFoundError' "$D/jd/log.txt")"
check "and still releases the runtime" 1 "$(ls "$D/jd/RELEASED" 2> /dev/null | wc -l | tr -d ' ')"

# cli-watch.sh against a fake colab: sessions from a file, the job probe from a file, stops logged.
F=$D/fake
mkdir -p "$F"
cat > "$F/colab" << 'EOF2'
#!/usr/bin/env bash
F=$(dirname "$0")
case "$1" in
sessions) cat "$F/sessions" ;;
ssh) [ -f "$F/probe" ] && cat "$F/probe" || exit 1 ;;
stop) echo "$3" >> "$F/stops"; [ -f "$F/stopfails" ] || sed -i.bak "/^\[$3\] /d" "$F/sessions" ;;
esac
EOF2
chmod +x "$F/colab"
w() { COLAB_BIN="$F/colab" COLAB_WATCH_STATE="$F/state" bash "$s/cli-watch.sh" "$@" --poll-s 0; }
fresh() { rm -f "$F/state" "$F/stops" "$F/stopfails" "$F/probe"; printf '[?] gpu-a100-x | Hardware: A100\n[job] m-s-1 | Hardware: CPU\n' > "$F/sessions"; }
fresh; echo 'DONE|30|30' > "$F/probe"
check "a finished job is reported" "FINISHED job DONE" "$(w job)"
check "and only once: the next watch waits for GONE" "GONE job" "$(sed -i.bak '/^\[job\]/d' "$F/sessions"; w job)"
printf '[job] m-s-2 | Hardware: CPU\n' >> "$F/sessions"
check "a new session reusing the name is reported again" "FINISHED job DONE" "$(w job)"
fresh; echo 'FAILED rc=1|30|30' > "$F/probe"
check "a failed job is reported with its status" "FINISHED job FAILED rc=1" "$(w job)"
fresh; echo 'RUNNING|1000|30' > "$F/probe"
check "a job silent for --quiet-min is QUIET, though its runner beats" "QUIET job 16" "$(w job --quiet-min 15)"
fresh; echo 'RUNNING|30|1000' > "$F/probe"
check "a runner whose heartbeat stopped is NO_HEARTBEAT" "NO_HEARTBEAT job 16" "$(w job --dead-min 10)"
fresh; echo 'NOJOB|0|0' > "$F/probe"
check "a session with no job is stopped once idle" "IDLE_STOPPED job" "$(w job --idle-min 0)"
check "only the named session was stopped" job "$(cat "$F/stops")"
fresh; echo 'NOJOB|0|0' > "$F/probe"; touch "$F/stopfails"
check "a failed stop is reported" "STOP_FAILED job" "$(w job --idle-min 0)"
fresh
check "no ssh contact three times is reported" "NO_CONTACT job" "$(w job)"
fresh
check "a session that is not listed is GONE" "GONE other" "$(w other)"
bash "$s/cli-watch.sh" --help > /dev/null
check "cli-watch.sh --help exits 0" 0 $?
bash "$s/cli-watch.sh" job --bogus > /dev/null 2>&1
check "cli-watch.sh: an unknown option exits 2" 2 $?

echo "colab-browser scripts: $pass passed, $fail failed"
[ "$fail" = 0 ]
