---
name: writing-napkin-books
description: Use when the user asks for a Napkin-style book on a topic (in the style of Evan Chen's An Infinitely Large Napkin, or like the VLA reading guide made with this skill), or asks to continue, extend or rebuild a book scaffolded from this skill's template. Not for ordinary study guides, notes, cheat sheets, summaries or single LaTeX documents unless the user asks for the Napkin style.
---

# Writing Napkin-style books

## Overview

A Napkin-style book teaches a field in one PDF. It can be a **reading guide** (tiered cards for the key papers, the course
of developments, reading paths), a **crash course** written from zero (worked examples, original figures, things to
build), or both, optionally followed by the cited arXiv papers joined into one linked volume. `template/` gives the
look (KOMA `scrbook` after the Napkin: maroon links, crimson numerals, blue, rust and green boxes) and the tools. The
method gives the content: writer agents draft against a writer's guide, *separate* agents fact-check against primary
sources, and the compiler (you) integrates, runs `tools/check.sh` and looks at every page.

**Core principle:** every claim has a source the reader could open, every number was recomputed, every figure was
looked at, and the book and the final message say plainly what was and was not checked.

Not for: ordinary study guides, notes, cheat sheets or summaries (unless the user asks for the Napkin style), a
single paper or article (use the template's `preamble.tex` alone), slide decks, fiction.

## Quick start

```bash
bash <skill dir>/scripts/new_book.sh ~/books/qec "Quantum Error Correction: A Reading Guide" "QEC Reading Guide"
cd ~/books/qec && bash tools/check.sh      # check 5 lists the red \fillin markers still to be written
```

The scaffold builds a 17-page example: a crash-course chapter that uses each of the seven callout boxes once
(`ch01_template_tour`), a reading-guide chapter with cards (`ch02_reading_example`), the front matter, glossary,
bibliography and papers part. Copy their shape, then replace them (`git mv`, overwrite, grep for their labels).

## Workflow

Details, agent prompts and gates are in `reference/workflow.md`; read it before phase 3. If the project has an issue
tracker, open one issue per phase and one per chapter.

1. **Intake.** Audience and what they already know; book type; parts and page budget; any deep-dive part; papers
   appended or not; spelling. Ask only what you cannot default, and state the defaults you chose.
2. **Scaffold.** Check free disk space; `new_book.sh`; edit `bookmeta.tex`, `tools/book.env` and
   `tools/data/groups.tsv`; commit; offer a private remote.
3. **Corpus** (reading guides). Candidates from surveys, `tools/search_arxiv.py` and citation counts
   (`tools/fetch_s2.py`); tiers A/B/C; `tools/add_arxiv.py`; `tools/crossref.py` or the publisher's page before any
   entry in `refs_manual.bib`; `tools/fetch_papers.py`; quote-backed reading notes (`briefs/notes_brief.md`).
4. **Architecture.** Parts, a chapter map with labels and page budgets, the dependency chart, reading paths. Fill in
   `briefs/writers_guide.md`. Write the exemplar chapter yourself and get it right before any writer starts.
5. **Drafting.** One writer agent per chapter, a few at a time, each given the writer's guide. Writers build with
   `tools/build_chapter.sh`, commit only their own files, and save a report in `provenance/writers/`.
6. **Independent fact-check.** One checker per block of 2-3 chapters with `briefs/factcheck_brief.md`, never the
   writer. Apply every fix and log each item as APPLIED, ALREADY FIXED or DECLINED (with the reason).
7. **Integration.** Glossary, cross-references, the citations writers asked for, preface (method, caveats, dates),
   README, provenance index. No `\fillin` or `NEED REF` left, and the text claims only checks that were done.
8. **Build and QA.** `tools/check.sh` passes and its NOTEs are read; look at every page (`tools/contact_sheets.sh`)
   and every figure at 120 dpi; fix layout locally.
9. **Combined volume** (optional). `tools/build_volume.sh`, then `tools/verify_volume.py`.
10. **Deliver.** Commit (push if there is a remote) and send the final message (`reference/workflow.md`, section 10).

## Rules that keep the book trustworthy

- Bibliographic data comes from the arXiv API, Crossref, or publisher and library pages, never from memory.
  `papers.tex` and `refs_auto.bib` are generated; never edit them.
- Paper results are the authors' numbers, attributed and located (page, table, version). Every computed number is
  recomputed with code, every plotted curve is computed from the formula in the text, and every quoted program
  output comes from a saved run (`figures/src/<name>.out`, rerun by `check.sh`).
- Fact-checkers are agents other than the writers. They get the brief and the text; writers' reports only help them
  find claims and are never evidence.
- Writer and checker agents edit only their own files, commit with path-limited commits, never delete files and
  never push.
- Time-sensitive facts say "as of <date>"; no prices without a source and date; the spelling is checked.
- Fix a bad page break locally (`\enlargethispage`, a local `\Needspace` before one box, a shorter sentence, moving a
  float). Never lower a global spacing setting for it: every page after it moves.
- Append papers only with `tools/build_volume.sh` (pdfunite plus the pikepdf repair). `\includepdf` loses each
  paper's internal links and is very slow for thousands of pages.
- Use the template. Do not write a new class or restyle it; the look is the point.
- When a new kind of mistake gets through, add a check for it to `tools/check.sh`.

## Common mistakes

| Mistake | Fix |
|---|---|
| Writers start before the exemplar and the guide exist | Write and polish the exemplar chapter first; writers copy its shape |
| The front matter claims fact-checks that did not happen | Fill those sentences in last; `check.sh` check 5b fails without reports |
| A figure gets an arrow, a sign or a polarity backwards | Render it and look; checkers render figures too (brief item 8) |
| Plot data or program output cannot be regenerated | Scripts and their output live in `figures/src/` |
| Two chapters define the same label | `<type>:<chapter slug>-<name>`; `check.sh` check 8 fails on duplicates |
| A writer's work is lost when the session ends | The guide says to save a full draft early and commit after every round |
| The final message hides gaps | List what was not verified, and why, next to what was |

More, with causes and fixes: `reference/workflow.md`, section "Pitfalls".

## Files

- `scripts/new_book.sh`: scaffold a book (run it with `bash`).
- `template/`: the book skeleton. It holds `preamble.tex` (the look), `kit.tex` (boxes, units, plots, listings and
  lettered parts), `bookmeta.tex`, `tools/` (see `template/README.md`), `briefs/` and `provenance/`.
- `reference/workflow.md`: phase details, how to brief and run agents, gates, the final message, pitfalls.
- `reference/style.md`: the voice, the boxes and cards, tiers and reading paths, figures, layout repair.
