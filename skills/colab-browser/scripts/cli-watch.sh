#!/usr/bin/env bash
# Watch Colab CLI sessions that run colab_job.py. Polls, then prints ONE event line and exits: run it in the
# background and start it again after each event.
#
#   bash cli-watch.sh NAME[,NAME...] [--idle-min 10] [--quiet-min 15] [--dead-min 10] [--poll-s 120]
#                     [--job-dir /content/job]
#
#   FINISHED NAME STATUS   the job ended (DONE, FAILED rc=N, FAILED deadline or INTERRUPTED): download the results,
#                          then
#                          create JOB_DIR/COLLECTED or run colab stop. Reported once; the next watch waits
#                          for GONE
#   GONE NAME              the session no longer exists: released by the job, stopped, or reclaimed by Colab
#   QUIET NAME MINUTES     the job printed nothing for --quiet-min minutes: look before stopping anything
#   NO_HEARTBEAT NAME MIN  the runner's heartbeat stopped for --dead-min minutes: the runner or the kernel is
#                          dead or stuck, so the job's deadline and release may not happen. Look now
#   IDLE_STOPPED NAME      the session ran no job for --idle-min minutes: the watch stopped it
#   STOP_FAILED NAME       stopping that idle session failed: stop it now
#   NO_CONTACT NAME        ssh to the session failed 3 polls in a row: check it by hand
#
# Only the sessions named are ever stopped. Sessions started elsewhere (shown as [?] by colab sessions, such as
# notebooks open in a browser) are never touched.
# Environment: COLAB_BIN (default colab), COLAB_SSH_KEY (default ~/.config/colab-browser/ssh_ed25519),
# COLAB_WATCH_STATE (default: a file in $TMPDIR).
set -u
usage() { sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; }
[ $# -ge 1 ] || { usage; exit 2; }
case "$1" in -h | --help | help) usage; exit 0 ;; -*) usage >&2; exit 2 ;; esac
names=$1; shift
idle=10 quiet=15 dead=10 poll=120 jobdir=/content/job
while [ $# -gt 0 ]; do
	case "$1" in
	--idle-min) idle=$2; shift 2 ;;
	--quiet-min) quiet=$2; shift 2 ;;
	--dead-min) dead=$2; shift 2 ;;
	--poll-s) poll=$2; shift 2 ;;
	--job-dir) jobdir=$2; shift 2 ;;
	*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
colab=${COLAB_BIN:-colab}
key=${COLAB_SSH_KEY:-$HOME/.config/colab-browser/ssh_ed25519}
state=${COLAB_WATCH_STATE:-${TMPDIR:-/tmp}/colab-cli-watch.state}
export BROWSER=true # never let the CLI open the user's browser
touch "$state"

getv() { awk -v k="$1" '$1 == k { v = $2 } END { print v }' "$state"; }
setv() { grep -v "^$1 " "$state" > "$state.tmp"; echo "$1 $2" >> "$state.tmp"; mv -f "$state.tmp" "$state"; }

# Prints "STATUS|OUTPUT_AGE|HEARTBEAT_AGE": the job's STATUS file (or NOJOB), the seconds since the job last
# printed, and the seconds since the runner's last heartbeat. Prints nothing if ssh fails.
probe() {
	"$colab" ssh -s "$1" --identity "$key" -- \
		"cd '$jobdir' 2>/dev/null || { echo 'NOJOB|0|0'; exit 0; }; n=\$(date +%s); age() { echo \$(( n - \$(stat -c %Y \"\$1\" 2>/dev/null || echo \$n) )); }; echo \"\$(cat STATUS 2>/dev/null || echo NOJOB)|\$(age output)|\$(age heartbeat)\"" \
		< /dev/null 2> /dev/null | tr -d '\r' | grep '|' | tail -1
}

IFS=, read -r -a list <<< "$names"
while :; do
	now=$(date +%s)
	listed=$("$colab" sessions 2> /dev/null)
	for n in "${list[@]}"; do
		if ! grep -q "^\[$n\] " <<< "$listed"; then
			# Forget this name, so a new session with the same name starts fresh.
			grep -vE "^(fail|seen|done):$n " "$state" > "$state.tmp"; mv -f "$state.tmp" "$state"
			echo "GONE $n"
			exit 0
		fi
		r=$(probe "$n")
		if [ -z "$r" ]; then
			f=$(($(getv "fail:$n") + 1))
			setv "fail:$n" "$f"
			[ "$f" -ge 3 ] && { setv "fail:$n" 0; echo "NO_CONTACT $n"; exit 0; }
			continue
		fi
		setv "fail:$n" 0
		IFS='|' read -r st out hb <<< "$r"
		case "$st" in
		RUNNING)
			setv "seen:$n" ""
			setv "done:$n" ""
			if [ "$hb" -gt $((dead * 60)) ]; then
				echo "NO_HEARTBEAT $n $((hb / 60))"
				exit 0
			fi
			if [ "$out" -gt $((quiet * 60)) ]; then
				echo "QUIET $n $((out / 60))"
				exit 0
			fi
			;;
		NOJOB)
			first=$(getv "seen:$n")
			[ -n "$first" ] || { first=$now; setv "seen:$n" "$now"; }
			if [ $((now - first)) -ge $((idle * 60)) ]; then
				setv "seen:$n" ""
				"$colab" stop -s "$n" > /dev/null 2>&1
				if "$colab" sessions 2> /dev/null | grep -q "^\[$n\] "; then echo "STOP_FAILED $n"; else echo "IDLE_STOPPED $n"; fi
				exit 0
			fi
			;;
		*)
			# Reported once; after that the watch waits for the job to release the session (GONE).
			[ "$(getv "done:$n")" = "${st// /_}" ] && continue
			setv "done:$n" "${st// /_}"
			echo "FINISHED $n $st"
			exit 0
			;;
		esac
	done
	sleep "$poll"
done
