---
name: hn-ready
description: Use when the user asks to make a project HN-ready, to get it ready for Show HN or a Hacker News launch, to publish and publicize a repo, or to make a tool look and install like a polished product on GitHub, for a new repo or an existing one. Also use after a launch, when HN or GitHub feedback comes in.
---

# Making a project HN-ready

HN-ready means a stranger who clicks the GitHub link understands the tool in ten seconds,
installs it with one paste, and it works.

## Gates

- **Outward actions need the user's yes.** Outward means anything that leaves this machine:
  creating the repo, pushing, setting the description and topics, releases, PRs (upstream
  ones too), comments on issues and PRs, and anything on HN.
  - When the user picks an item, that's the yes for the commits and pushes it needs, and for
    the outward actions the item names.
  - Anything the item doesn't name needs its own yes.
- **The user writes every HN post, comment and reply in their own words.** Hand over the
  title, the submit link, facts and talking points, never drafted comment text. HN moderators
  don't want LLM-written comments.
- **Nothing is added without the user's pick.** Features, fixes and ideas found along the way
  go into a numbered list first.

## Process

1. Audit the project against the checklist. Present the gaps as a numbered list. For each one,
   give what's missing, what you'd do (naming any outward action), and your recommendation.
   Then stop and wait for the user's pick.
2. For each item the user picks, read its reference file, do it, and verify it the way the
   file says.
3. Report what's done, with evidence (renders, frames, CI runs), and what's left.

## Checklist

`<skill dir>` below is the folder this SKILL.md is in. The `reference/` and `scripts/` paths are
inside it.

| Area | Ready when | Read |
|---|---|---|
| Scope | A tool for people, not a personal setup: no personal paths or tweaks. Runs on Linux and macOS, or the README says which. Supports the popular alternatives, not one vendor, and has a documented extension point | |
| Install | One pasted command installs everything, the toolchain and dependencies too, on a machine that has only curl. Running it again updates. Has `--uninstall`. Tested in fresh containers and on macOS | `reference/installer.md` |
| README | Follows the recipe, about 80 lines | `reference/readme.md` |
| Logo | Hand-written SVG, rendered on light and dark backgrounds at display size, with arrows checked by geometry | `reference/logo.md` |
| Demo | A real recording, 20–30 s, every frame looked at | `reference/demo.md` |
| Docs | `docs/` has caveats, how it works and install by hand. `CONTRIBUTING.md` covers the tests and how to extend. `LICENSE` | `reference/readme.md` |
| Work tracking | Contributors must track their work with bd (beads), since nearly everyone contributes through a coding agent. bd is set up in the repo, and `CONTRIBUTING.md` and `AGENTS.md` say every change starts as a bd issue | `reference/bd.md` |
| CI | Tests run on every push and the badge reads "passing". Before launch, run `bash <skill dir>/scripts/check-readme.sh README.md` in the project. It's a check for you, not a file for the project | |
| GitHub | The About text says what it does and names the supported tools. Topics cover the domain and each tool | |
| Privacy | Nothing personal in the files, the git history, test fixtures or GIF frames | below |
| Launch kit | Title, submit link, talking points and timing, in a launch folder outside the repo | `reference/show-hn.md` |
| After launch | Feedback becomes numbered proposals, then credited commits | `reference/after-launch.md` |

## Privacy sweep, before the first push

- Search every commit, not just the current files:
  `git log -p --all | grep -nE '/home/|/Users/|[0-9a-f]{8}-([0-9a-f]{4}-){3}|\bsk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}'`.
  Read each hit.
- Anonymize test fixtures taken from the user's machine. The raw file never goes in.
- GIF frames must show no account names, no notices from the user's own settings, and no
  unrelated projects.

## Mistakes that already happened

| What happened | Do instead |
|---|---|
| A README listed what the tool needed ("Needs Linux with systemd…") | One install command; the installer installs what's needed |
| The same questions kept coming up in the HN thread | Restructure the README so it answers them, e.g. with a section on what the tool adds to the one people already use. Never add an FAQ heading |
| A logo's arrowhead pointed backwards for two weeks before anyone noticed | Check direction by geometry, in a zoomed render |
| A demo GIF showed a notice from the author's own settings | Record from a clean environment and look at every frame |
| A title named one vendor's product when the tool supported several | Name the category in the title; list the tools in the README |
| A post sat at 1 point two hours after posting | Normal. HN's second-chance pool can put a post on the front page days later |
| Container tests broke on a partial upgrade (`pacman -Sy pkg`) | Full-upgrade rolling distros in test setup. The installer never runs `-Sy` |
| The author's own machine still ran an older private copy | Install the published version and update it after every push once CI is green |
