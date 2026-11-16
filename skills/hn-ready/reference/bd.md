# Work tracking with bd

Contributors track their work with bd ([beads](https://github.com/steveyegge/beads)), an issue
tracker built for coding agents. Nearly everyone contributes through an agent now, and bd gives
the agent and the maintainer the same list of open work.

## Set it up in the repo

1. Install bd if it's missing:
   `curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash`
   or `brew install beads`.
2. In the repo, run `bd init --non-interactive --role maintainer -p NAME`. It does four things:
   - It makes its own commit ("bd init: initialize beads issue tracking").
   - It points `core.hooksPath` at `.beads/hooks`, so bd's git hooks run on every commit.
   - It writes `AGENTS.md`, `CLAUDE.md` and `.claude/settings.json`, which runs `bd prime` at
     session start. Read them, keep bd's marked section, and add the project's own rules.
   - It keeps issues in a local Dolt database. `bd dolt push` publishes them to `refs/dolt/data`
     on the git remote; it's outward, so it needs the same yes as the push.
     `.beads/issues.jsonl` is only an export, for people browsing on GitHub.
3. File the project's real open work as issues, so a newcomer finds something to pick up.

## What CONTRIBUTING.md says

- bd is required: every change starts as a bd issue, and the commit and the PR name its id.
- The steps:
  1. Install bd, with the line above.
  2. In a clone with push access, run `bd bootstrap` to get the issues, then `bd ready`.
  3. Run `bd update ID --claim` before starting. For new work, run
     `bd create "Title" -t task -p 2`. Run `bd close ID` when it's done.
  4. From a fork, run `bd init --contributor` instead. It keeps the contributor's planning
     issues out of the upstream repo; the PR names the issue and says what was done.
