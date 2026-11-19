#!/usr/bin/env bash
# Run once per install of the skill:
# - the official Colab CLI (google-colab-cli), if `colab` is not on PATH;
# - an SSH key used only for `colab ssh` (cli-watch.sh reads jobs over it);
# - playwright-core next to these scripts (about 10 MB, no browser download), so colab.cjs can drive the
#   browser that launch-browser.sh started.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
if ! command -v colab > /dev/null 2>&1; then
	if command -v uv > /dev/null 2>&1; then uv tool install google-colab-cli; else pip install --user google-colab-cli; fi
fi
key=${COLAB_SSH_KEY:-$HOME/.config/colab-browser/ssh_ed25519}
if [ ! -f "$key" ]; then
	mkdir -p "$(dirname "$key")"
	ssh-keygen -q -t ed25519 -N '' -C colab-cli -f "$key"
	echo "made an SSH key for colab ssh: $key"
fi
if ! command -v npm > /dev/null 2>&1; then
	echo "npm not found: install Node.js 18 or newer first" >&2
	exit 1
fi
npm install --prefix "$here" --no-save --no-package-lock --no-audit --no-fund playwright-core@1.62.1 > /dev/null
node -e "require('$here/node_modules/playwright-core'); console.log('playwright-core ready in $here/node_modules')"
