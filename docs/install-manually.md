# Install by hand

Three other ways to install, if you'd rather not run the install script.

## Copy a skill

```sh
git clone https://github.com/andrewboldi/skills
cp -R skills/skills/hn-ready ~/.claude/skills/
```

Each agent looks for skills in its own folder:

| Agent | Folder |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex, pi | `~/.agents/skills/` |
| opencode | `~/.config/opencode/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| Cursor | `~/.cursor/skills/` |
| GitHub Copilot | `~/.copilot/skills/` |

These are the folders the [skills CLI](https://github.com/vercel-labs/skills/blob/main/docs/agents.md)
uses. For one project only, copy the skill into that project's `.claude/skills/` (Claude Code)
or `.agents/skills/` (most other agents) instead.

To update, run `git pull` and copy again. If you work on the skills, link the folder instead of
copying it: `ln -s "$PWD/skills/skills/hn-ready" ~/.claude/skills/hn-ready`.

## Claude Code's plugin installer

```sh
claude plugin marketplace add andrewboldi/skills
claude plugin install hn-ready@andrewboldi-skills
claude plugin install writing-napkin-books@andrewboldi-skills
```

A plugin's skill takes the plugin's name as a prefix: `/hn-ready:hn-ready`. To update, run
`claude plugin marketplace update andrewboldi-skills`. To remove both, run
`claude plugin marketplace remove andrewboldi-skills`.

## The skills CLI

```sh
npx skills add andrewboldi/skills
```

It asks which skills to install and for which agents. Add `-g` to install for your user rather
than the current project. `bunx skills add andrewboldi/skills` works the same way.
