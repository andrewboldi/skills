#!/usr/bin/env bash
# install.sh against a throwaway home folder: which agents get the skills, re-runs, folders the
# installer didn't make, and --uninstall.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
MARK=.installed-by-andrewboldi-skills
pass=0 fail=0
check() {
	if [ "$2" = "$3" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3"
	fi
}
homes=()
newhome() {
	H=$(mktemp -d)
	homes+=("$H")
}
trap 'rm -rf "${homes[@]}"' EXIT
run() { env -i HOME="$H" PATH="$PATH" SKILLS_SOURCE="$here" bash "$here/install.sh" "$@" > "$H/out" 2>&1; }
names() { (cd "$1" 2> /dev/null && find . -mindepth 1 -maxdepth 1 -type d | sed 's|^\./||' | sort | tr '\n' ' '); }
has() { [ -e "$1" ] && echo yes || echo no; }
skills=$(names "$here/skills")

# Claude Code, Codex and pi are installed; Codex and pi share ~/.agents/skills
newhome
mkdir -p "$H/.claude" "$H/.codex" "$H/.pi"
run
check "install succeeds" 0 $?
check "Claude Code gets every skill" "$skills" "$(names "$H/.claude/skills")"
check "Codex and pi share ~/.agents/skills" "$skills" "$(names "$H/.agents/skills")"
check "absent agents get nothing" no "$(has "$H/.gemini")"
check "copies are marked" yes "$(has "$H/.claude/skills/hn-ready/$MARK")"
sums() { (cd "$1" && find . -type f ! -name "$MARK" -exec cksum {} + | sort); }
check "a copy is complete, byte for byte" "$(sums "$here/skills/hn-ready")" "$(sums "$H/.claude/skills/hn-ready")"

# a re-run replaces a stale copy
echo stale > "$H/.claude/skills/hn-ready/SKILL.md"
run
check "a re-run updates" "$(cat "$here/skills/hn-ready/SKILL.md")" "$(cat "$H/.claude/skills/hn-ready/SKILL.md")"

# folders the installer didn't make stay as they are: a folder and a symlink
mkdir -p "$H/.gemini/skills/hn-ready" "$H/.cursor/skills"
echo mine > "$H/.gemini/skills/hn-ready/SKILL.md"
ln -s "$here/skills/hn-ready" "$H/.cursor/skills/hn-ready"
run
check "someone else's folder is kept" mine "$(cat "$H/.gemini/skills/hn-ready/SKILL.md")"
check "a symlink is kept" "$here/skills/hn-ready" "$(readlink "$H/.cursor/skills/hn-ready")"
check "it says so" yes "$(grep -q 'left ~/.gemini/skills/hn-ready alone' "$H/out" && echo yes || echo no)"
check "the other skills still go there" yes "$(has "$H/.gemini/skills/writing-napkin-books/SKILL.md")"

# --uninstall removes its own copies and nothing else
run --uninstall
check "uninstall succeeds" 0 $?
check "copies are gone" "" "$(names "$H/.claude/skills")"
check "shared copies are gone" "" "$(names "$H/.agents/skills")"
check "someone else's folder survives" mine "$(cat "$H/.gemini/skills/hn-ready/SKILL.md")"
check "the symlink survives" "$here/skills/hn-ready" "$(readlink "$H/.cursor/skills/hn-ready")"
run --uninstall
check "a second uninstall has nothing to do" yes "$(grep -q 'nothing to remove' "$H/out" && echo yes || echo no)"

# no agent at all: Claude Code's folder and the shared ~/.agents/skills
newhome
run
check "no agent: Claude Code's folder" "$skills" "$(names "$H/.claude/skills")"
check "no agent: ~/.agents/skills" "$skills" "$(names "$H/.agents/skills")"

# a bad option stops with a message
run --bogus
check "a bad option fails" 1 $?

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
