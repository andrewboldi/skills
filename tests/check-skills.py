#!/usr/bin/env python3
"""Checks every skill in skills/ the way an agent will read it.

- SKILL.md starts with a frontmatter block that has a name and a description.
- The name is the folder's name, in lowercase letters, digits and hyphens.
- The description says when to use the skill ("Use when ..."), and the frontmatter fits in the
  1024 characters agents allow.
- .claude-plugin/marketplace.json has one plugin per skill, with the skill's own name, and nothing
  else.
"""
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
problems = []
skills = sorted(p for p in (root / "skills").iterdir() if p.is_dir())

for d in skills:
    f = d / "SKILL.md"
    if not f.is_file():
        problems.append(f"{d.name}: no SKILL.md")
        continue
    m = re.match(r"---\n(.*?)\n---\n", f.read_text(encoding="utf-8"), re.S)
    if not m:
        problems.append(f"{d.name}: SKILL.md doesn't start with a frontmatter block")
        continue
    front = m.group(1)
    fields = {k: v.strip().strip("\"'") for k, v in re.findall(r"^([\w-]+):[ \t]*(.*)$", front, re.M)}
    name, description = fields.get("name", ""), fields.get("description", "")
    if name != d.name:
        problems.append(f"{d.name}: its name is {name!r}, not the folder's name")
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
        problems.append(f"{d.name}: the name may only use lowercase letters, digits and hyphens")
    if not description.startswith("Use when"):
        problems.append(f"{d.name}: the description should start with 'Use when'")
    if len(front) > 1024:
        problems.append(f"{d.name}: the frontmatter has {len(front)} characters; the limit is 1024")

market = json.loads((root / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8"))
plugins = {p["name"]: p for p in market["plugins"]}
for d in skills:
    p = plugins.pop(d.name, None)
    if p is None:
        problems.append(f"{d.name}: not listed in .claude-plugin/marketplace.json")
    elif p.get("skills") != [f"./skills/{d.name}"]:
        problems.append(f"{d.name}: its plugin should list exactly ./skills/{d.name}")
for name in plugins:
    problems.append(f"marketplace.json lists {name}, which has no folder in skills/")

for p in problems:
    print("FAIL", p)
print(f"{len(skills)} skills checked, {len(problems)} problems")
sys.exit(1 if problems else 0)
