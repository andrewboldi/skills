#!/usr/bin/env bash
# Installs these skills for every coding agent on this machine. Re-run it to update.
#
#   curl -fsSL https://raw.githubusercontent.com/andrewboldi/skills/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/andrewboldi/skills/main/install.sh | bash -s -- --uninstall
#
# 1. Downloads the skills from GitHub. It needs only curl and tar.
# 2. Copies each skill into the skills folder of every agent it finds: Claude Code, Codex,
#    opencode, Gemini CLI, Cursor, GitHub Copilot and pi. If it finds none, it uses Claude Code's
#    folder and the shared ~/.agents/skills.
# 3. Marks each copy it makes. A re-run replaces only its own copies, and --uninstall removes
#    only them. It leaves alone a folder with the same name that it didn't make.
#
# SKILLS_SOURCE=/path/to/checkout installs from a local checkout instead (for testing).
# Runs with macOS's bash 3.2: no bash 4 features here.
set -euo pipefail

REPO=andrewboldi/skills
MARK=.installed-by-andrewboldi-skills

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
	printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
	exit 1
}
tilde() { printf '%s' "${1/#"$HOME"/\~}"; } # an unescaped ~ would expand back to $HOME

# One line per agent: its name, the folder that shows it's installed, and its skills folder.
# These are the global folders the skills CLI uses (github.com/vercel-labs/skills, docs/agents.md).
agents() {
	cat << EOF
Claude Code|$HOME/.claude|$HOME/.claude/skills
Codex|$HOME/.codex|$HOME/.agents/skills
pi|$HOME/.pi|$HOME/.agents/skills
opencode|$HOME/.config/opencode|$HOME/.config/opencode/skills
Gemini CLI|$HOME/.gemini|$HOME/.gemini/skills
Cursor|$HOME/.cursor|$HOME/.cursor/skills
GitHub Copilot|$HOME/.copilot|$HOME/.copilot/skills
EOF
}

# Sets SRC to a folder that has skills/ in it.
fetch() {
	if [ -n "${SKILLS_SOURCE:-}" ]; then
		SRC=$SKILLS_SOURCE
	else
		command -v curl > /dev/null || die "curl is needed to download the skills"
		command -v tar > /dev/null || die "tar is needed to unpack the skills"
		TMP=$(mktemp -d)
		trap 'rm -rf "$TMP"' EXIT
		curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar -xz -C "$TMP" ||
			die "couldn't download $REPO from GitHub; check your connection and run this again"
		SRC=$(echo "$TMP"/*)
	fi
	[ -d "$SRC/skills" ] || die "no skills/ folder in $SRC"
}

install_all() {
	fetch
	local found="" dirs="" name home dir skill dest
	while IFS='|' read -r name home dir; do
		[ -d "$home" ] || continue
		found="$found${found:+, }$name"
		dirs="$dirs$dir"$'\n'
	done < <(agents)
	if [ -z "$found" ]; then
		say "no coding agent found; installing for Claude Code and into ~/.agents/skills"
		dirs="$HOME/.claude/skills"$'\n'"$HOME/.agents/skills"$'\n'
	else
		say "found $found"
	fi

	local names=""
	for skill in "$SRC"/skills/*; do
		[ -f "$skill/SKILL.md" ] && names="$names${names:+, }$(basename "$skill")"
	done
	while read -r dir; do
		[ -n "$dir" ] || continue
		mkdir -p "$dir"
		for skill in "$SRC"/skills/*; do
			[ -f "$skill/SKILL.md" ] || continue
			dest=$dir/$(basename "$skill")
			if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -e "$dest/$MARK" ]; }; then
				warn "left $(tilde "$dest") alone: this script didn't install it"
				continue
			fi
			rm -rf "$dest"
			cp -R "$skill" "$dest"
			touch "$dest/$MARK"
		done
		say "$(tilde "$dir"): $names"
	done < <(printf '%s' "$dirs" | awk '!seen[$0]++')
	say "done. Start a new session of your agent to use them; run this again to update."
}

uninstall() {
	local removed=0 dir mark
	while read -r dir; do
		for mark in "$dir"/*/"$MARK"; do
			[ -e "$mark" ] || continue
			rm -rf "$(dirname "$mark")"
			say "removed $(tilde "$(dirname "$mark")")"
			removed=$((removed + 1))
		done
	done < <(agents | cut -d'|' -f3 | awk '!seen[$0]++')
	[ "$removed" -gt 0 ] || say "nothing to remove"
}

case "${1:-}" in
"") install_all ;;
--uninstall) uninstall ;;
*) die "unknown option: $1 (the only option is --uninstall)" ;;
esac
