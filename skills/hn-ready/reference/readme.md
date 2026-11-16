# README recipe

The README answers three questions: what it does, how to install it, and how it works.
Everything else goes in `docs/` or `CONTRIBUTING.md`. In the user's words: "I really hate long
readmes", "i hate it when people tell me it requires X", "exactly one code block to copy that
just works", and "it shouldn't be a personal story it should be a tool for people".

Worked example: `~/tmux-restore/README.md`, 79 lines with the install command on line 55. Read
it before writing a new one.

## Parts, in order

1. **Centered header.**
   ```html
   <p align="center">
     <img src="assets/logo.svg" alt="" width="132">
   </p>

   <h1 align="center">NAME</h1>

   <p align="center"><b>TAGLINE</b></p>

   <p align="center">
     <a href="https://github.com/OWNER/REPO/actions/workflows/test.yml"><img alt="tests" src="https://img.shields.io/github/actions/workflow/status/OWNER/REPO/test.yml?branch=main&label=tests&style=flat-square"></a>
     <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/github/license/OWNER/REPO?style=flat-square"></a>
     <a href="ECOSYSTEM_URL"><img alt="ECOSYSTEM" src="https://img.shields.io/badge/LABEL-MESSAGE-COLOR?style=flat-square&logo=LOGO&logoColor=white"></a>
   </p>

   <p align="center">
     <a href="#what-it-adds-to-INCUMBENT">What it adds</a> ·
     <a href="#install">Install</a> ·
     <a href="#how-it-works">How it works</a> ·
     <a href="docs/caveats.md">Caveats</a> ·
     <a href="CONTRIBUTING.md">Contributing</a>
   </p>
   ```
   - The logo's `alt` is empty because the h1 right below it names the tool.
   - The tagline is 12 words or fewer and leads with the benefit: "Reboot-proof tmux. Your coding
     agents pick up mid-conversation."
   - Use three badges: tests, license, and one for the ecosystem in the logo's accent color. Skip
     a stars badge while the count is small.
2. **Pitch**, 2–4 sentences. Open with one "Ever …?" question that names the pain, then switch to
   the third person: what it does, when, and for what. Name the supported tools once.
3. **Demo GIF**, right under the pitch: `<p align="center"><img src="assets/demo.gif" alt="ONE
   SENTENCE THAT TELLS THE STORY" width="820"></p>`.
4. **"What it adds to INCUMBENT"**, if a well-known tool already does part of the job. HN's first
   question is "how is this different from X?" Write bold-lead bullets of one or two lines each,
   with numbers ("every minute (continuum's default is 15)"), linking to docs for detail.
5. **One safety line**, if the tool stores or sends anything sensitive. Say where it goes and how
   to turn it off.
6. **Install**: exactly one fenced block, `curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash`.
   Then one or two sentences: what it installs, "Run it again to update", and a link for people
   who'd rather not run a script ("Install by hand", `docs/install-manually.md`). Then, for users
   of the incumbent: "**Already using X?** Keep it: …".
7. **How it works**: one paragraph, ending with a link to `docs/how-it-works.md`. Then the
   extension pointer: "Using another …? An adapter is one short file. Send it in
   (CONTRIBUTING.md), or keep it to yourself in `~/.config/NAME/…`."
8. **License**, in one line that credits what the tool is built on.

## Style

- Short sentences. Numbers instead of adjectives. No hype words, no emoji.
- Every claim has been measured. "A crash loses at most the last minute" only if it saves every
  minute.
- Call things what users see, not what the internals call them.

## What the top READMEs do

A survey of 15 top CLI READMEs (uv, fzf, starship, zoxide, mise, atuin, zellij, bat, lazygit,
tmux-resurrect and others) found:
- They use 3 badges at the median, in one `style=flat-square`.
- 12 of the 15 show a picture before the install section.
- The median first install command is on line 101, pushed down by sponsor lists and tables of
  contents. The best (uv, mise, atuin) lead with one script and link out.
- The worst have install matrices per distro: bat has 16 install sections, lazygit 23.
- None open with "Have you ever…?". The user wanted that opener anyway, so keep it to one line.

## Other files

- `docs/caveats.md`: honest limits.
- `docs/how-it-works.md`: the mechanism, the options and the files it writes.
- `docs/install-manually.md`: step-by-step, tested literally in a fresh container. An HN
  commenter asked for it within a day.
- Feature pages as needed, e.g. `docs/agents.md`.
- `CONTRIBUTING.md`:
  - How to run the tests, one line each with a comment.
  - The code rules (shellcheck, bash versions).
  - How to add an extension, with a complete example file.
  - How to keep an extension private.
- `LICENSE`: MIT.
- GitHub About and topics (ask first; they're outward):
  `gh repo edit OWNER/REPO --description "…" --add-topic a,b,c`.

Once launched, answer a question that comes up twice by restructuring the README, without adding
an FAQ heading.
