# Caveats

- **Only Claude Code is tested end to end.** The installer puts the skills where Codex, opencode,
  Gemini CLI, Cursor, Copilot and pi look for them, but nobody has run a real session in those
  agents yet. Reports are welcome (bd issue `skills-isx`).
- **A skill tells your agent what to do, including what to run.** These skills are Markdown and
  short scripts. Read one before you install it, as you would any script.
- **hn-ready uses tools it doesn't install by itself:**
  - asciinema and agg for the demo GIF. The skill says how to install them.
  - ffmpeg and ImageMagick to check the frames.
  - Inkscape, rsvg-convert or ImageMagick to render the logo.

  Your agent installs them when a step needs them, or asks you to.
- **hn-ready's posting times are a snapshot** of Show HN posts from October 2024 to October 2026.
  Timing is worth only about half a percentage point anyway.
- **writing-napkin-books needs TeX Live and poppler-utils to build a book:** `latexmk`,
  `pdflatex`, `biber`, `pdftoppm`, `pdftotext` and `pdfinfo`. It also needs a few GB of free
  disk. `new_book.sh` warns about anything missing.
  - CI checks that a book scaffolds, but doesn't build the LaTeX yet (bd issue `skills-crz`).
- **The installer only copies files.** It changes no agent settings. `--uninstall` removes only
  the copies it made, which are marked by a `.installed-by-andrewboldi-skills` file.
