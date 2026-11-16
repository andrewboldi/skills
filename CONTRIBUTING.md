# Contributing

Fixes, new skills, and reports from agents other than Claude Code are welcome.

## Track your work with bd

This repo tracks its work with [bd (beads)](https://github.com/steveyegge/beads), and that's
required. Every change starts as a bd issue, and the issue's id goes in the commit message and
the PR. Most contributions come through a coding agent, and bd gives the agent and the
maintainers the same list of open work.

1. Install bd:
   `curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash`
   or `brew install beads`.
2. With push access, run `bd bootstrap` in your clone to get the issues, then `bd ready` to see
   what's open.
3. Before you start, run `bd update ID --claim`. For new work, run
   `bd create "Title" -t task -p 2`. When it's done, run `bd close ID`.
4. From a fork, run `bd init --contributor` instead. It keeps your planning issues out of this
   repo. Say in the PR which issue it is and what you did.

Agents get the same rules from [AGENTS.md](AGENTS.md), and from `bd prime` at the start of each
Claude Code session.

## Run the tests

```sh
python3 tests/check-skills.py   # each SKILL.md as an agent reads it, and the plugin list
bash tests/install-test.sh      # install.sh against a throwaway home folder
bash tests/hn-ready-scripts.sh  # hn-ready's submit-link builder and README checker
bash tests/napkin-scaffold.sh   # writing-napkin-books scaffolds a book
```

CI runs them on Linux, and the installer test on macOS too. It also runs shellcheck and
`claude plugin validate .`.

Shell scripts pass `shellcheck -x -S warning`. `install.sh` also runs on macOS's bash 3.2, so it
uses no bash 4 features.

## How a skill is laid out

```
skills/NAME/
  SKILL.md      frontmatter (name = the folder's name, description = "Use when ..."), then the method
  reference/    detail that a step loads only when it needs it
  scripts/      tools, run as bash <skill dir>/scripts/x.sh, never by bare path
```

Keep `SKILL.md` short and move detail into `reference/`. Write for any project and any user,
with no paths or names from your own machine.

## Test a skill

The unit tests cover the scripts. The skill itself is tested with a rehearsal:

1. Make a small throwaway project with the problems the skill should catch.
2. Give a fresh agent only the user's request, e.g. "make this HN-ready", with the skill
   installed. Run it in a sandbox: no pushes, and nothing else that leaves the machine.
3. Read what it did. Each place it went wrong is a fix to the skill. Make the fix, then rehearse
   again.

Say in the PR what you rehearsed and what changed.

## Add a skill

1. Create `skills/NAME/` with a `SKILL.md`.
2. Add its plugin entry to `.claude-plugin/marketplace.json`, copying an existing entry.
3. Add a section to the README.

The installer and the tests find it by themselves.
