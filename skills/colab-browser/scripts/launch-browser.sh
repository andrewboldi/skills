#!/usr/bin/env bash
# Start (or find) a Chromium-family browser that an agent can drive over the DevTools protocol (CDP),
# with its own profile, so the user signs in to Google once and the session is kept for later runs.
#
#   bash launch-browser.sh                 start it (or report the one already running) and open Colab
#   bash launch-browser.sh --dry-run       print the browser, profile and port it would use, start nothing
#   bash launch-browser.sh --port 9333 --profile DIR --url URL
#
# Environment: COLAB_CDP_PORT (default 9222), COLAB_BROWSER (binary), COLAB_BROWSER_PROFILE (profile dir).
# The DevTools port listens on 127.0.0.1 only, but any program on this machine can drive the browser
# (and its signed-in Google session) through it. Close the window when the work is done.
set -eu

port="${COLAB_CDP_PORT:-9222}"
profile="${COLAB_BROWSER_PROFILE:-}"
url="https://colab.research.google.com/"
dry=0
while [ $# -gt 0 ]; do
	case "$1" in
		--port) port="$2"; shift 2 ;;
		--profile) profile="$2"; shift 2 ;;
		--url) url="$2"; shift 2 ;;
		--dry-run) dry=1; shift ;;
		-h | --help) sed -n '2,12p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

cdp_up() { curl -fsS --max-time 2 "http://127.0.0.1:$port/json/version" > /dev/null 2>&1; }

if [ "$dry" = 0 ] && cdp_up; then
	echo "already running: http://127.0.0.1:$port (reusing it; the user may already be signed in)"
	exit 0
fi

browser="${COLAB_BROWSER:-}"
if [ -z "$browser" ]; then
	for b in google-chrome google-chrome-stable chromium chromium-browser \
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		"/Applications/Chromium.app/Contents/MacOS/Chromium"; do
		if command -v "$b" > /dev/null 2>&1; then browser=$(command -v "$b"); break; fi
		if [ -x "$b" ]; then browser=$b; break; fi
	done
fi
if [ -z "$browser" ]; then
	echo "no Chrome or Chromium found; install one, or set COLAB_BROWSER to its binary" >&2
	exit 1
fi

# Chrome only opens the DevTools port with a non-default profile, and a snap-packaged Chromium can only
# write inside ~/snap/chromium, so the default profile goes where the browser can use it.
if [ -z "$profile" ]; then
	case "$browser" in
		/snap/*) profile="$HOME/snap/chromium/common/colab-agent-profile" ;;
		*) profile="$HOME/.cache/colab-agent-profile" ;;
	esac
fi

if [ "$dry" = 1 ]; then
	printf 'browser: %s\nprofile: %s\nport:    %s\nurl:     %s\n' "$browser" "$profile" "$port" "$url"
	exit 0
fi

mkdir -p "$profile"
nohup "$browser" --remote-debugging-port="$port" --user-data-dir="$profile" \
	--no-first-run --no-default-browser-check "$url" > /dev/null 2>&1 &

for _ in $(seq 1 30); do
	if cdp_up; then
		echo "started: http://127.0.0.1:$port (profile $profile)"
		echo "ask the user to sign in to Google in that window if Colab shows a Sign in button"
		exit 0
	fi
	sleep 1
done
echo "the browser started but its DevTools port $port did not answer within 30 s" >&2
exit 1
