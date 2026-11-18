#!/usr/bin/env bash
# Install playwright-core next to these scripts (about 10 MB, no browser download), so colab.cjs can drive
# the browser that launch-browser.sh started. Run once per install of the skill.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
if ! command -v npm > /dev/null 2>&1; then
	echo "npm not found: install Node.js 18 or newer first" >&2
	exit 1
fi
npm install --prefix "$here" --no-save --no-package-lock --no-audit --no-fund playwright-core@1.62.1 > /dev/null
node -e "require('$here/node_modules/playwright-core'); console.log('playwright-core ready in $here/node_modules')"
