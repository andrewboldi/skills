# Style: voice, boxes, cards, figures, layout

The template fixes the look; this file is about using it well. The exemplars in the template
(`chapters/ch01_template_tour.tex`, `chapters/ch02_reading_example.tex`) show every element.

## The look (what the template already does)

Latin Modern 11pt on letter paper, KOMA `scrbook`, bold sans-serif headings, maroon links and contents, crimson chapter
numerals and section signs (`§2.1`), running heads with a rule (short title and version on even pages), tcolorbox
boxes after the Napkin's theorem boxes, one box counter per section (`Example 2.1.3`), biblatex `alphabetic` labels
(`[BBC+23]`) with back-references. Do not change these; change the content.

| Box | Looks | Use for |
|---|---|---|
| `insightbox` "Key idea" | blue rounded box | the one to three formulas or facts to remember from a section |
| `workedbox` "Example" | rust box | a worked example with real numbers, every step shown |
| `cautionbox` "Caution" | crimson bar | a safety rule or a costly mistake |
| `buildbox` "Build it" | green bar | something to build, run, measure or try, with its expected result |
| `connectionbox` (named in `bookmeta.tex`) | green bar | a link to the book's main application or a neighboring field, with `\cref` forward |
| `checkbox` "Check yourself" | green bar | three short questions, answers in `\footnotesize` |
| `readingbox` "Reading advice" | green bar | what to read next and what for; `[Further reading]` ends a chapter |
| `papercard` / `webcard` | blue, rust or green by tier | one paper or source (cards are not callouts) |

`papercard{key}{Display name}` takes its metadata from `papers.tex`; `webcard[Kind]{key}{Display name}{Full
title}{meta line}{tier}` is for sources with an entry in `refs_manual.bib` (Kind, the heading word, defaults to
Paper). Keep a Key idea box short (it never breaks across pages, so a long one leaves a gap).

## The voice of a crash course

* Second person, plain and concrete; short paragraphs; *why* before *how*.
* No term before its definition. Define in italics at first use, in plain words, with its unit.
* Every formula gets a worked example with numbers; every number gets a unit (say once that a quantity is
  dimensionless); round to 2-3 significant figures; write the step that produces each rounded number
  ($5\times e^{-1}=5\times0.368$, not $5\times0.37$, when the result is 1.84).
* Analogies are welcome; say where they break.
* Open each chapter with 100-150 words on why it matters and 3-5 "By the end you should be able to" bullets; end it
  with "Check yourself" and "Further reading" (reorder the boxes of the last section if the page breaks demand it);
  say in one sentence what was left out.
* Practical advice is conservative and labeled when it comes from experience rather than a source ("in practice").

## Paper cards and the reading guide

* **Card fields:** `\cl{Idea.}` (what the paper does, in plain words), `\cl{Results.}` (the authors' headline numbers,
  attributed and specific: which benchmark, which baseline, how many trials), `\cl{Why it matters.}` (what changed
  because of it), `\cl{Limits.}` (the authors' own limits first, then the compiler's reading, labeled as such).
* **Tiers:** A essential (three stars, blue box), B important (two stars, rust box), C context (one star, green bar).
  A field of 60 cards might have 12-15 A cards.
* **Narrative around the cards:** each chapter opens with a paragraph on what changed in that period or thread, and
  the text between cards says how one idea led to the next. Cards are not a list; the story is the point.
* **Reading paths** in "Advice for the reader": a short path (an hour or two) and a core path table of 8-12 rows in
  teaching order, each "Read it for" one line.
* **Dependency chart** (`figures/fig_chapterdeps.tex`): one node per chapter, solid arrows for "read first", dotted
  for optional, thick borders for the short path; nodes link to the chapters.
* **Honesty markers:** "the authors report"; "as of <date>" for anything that changes (leaderboards, versions,
  product claims); blog posts and model cards labeled as such; contradictions between sources stated, with the one
  followed.

## Figures

* Original drawings in TikZ, pgfplots (`bookplot` style) or circuitikz (`ckt` style), one float per file in
  `figures/`, captions ending "Original drawing.". The palette names: `navy`, `teal`, `amber`, `rose`, `slate`,
  `mist`, `sand`, `maroon`, `crimson`.
* Curves are computed from the formula in the text with the example's numbers; data from scripts keep their script
  and seed in `figures/src/`.
* Fonts `\sffamily\scriptsize`; width at most `\textwidth`; height at most about 7 cm.
* Look at each one rendered at 120 dpi. Labels must not touch lines or each other; arrows must point the right way.

## Layout repair (local fixes only)

| Problem | Local fix |
|---|---|
| A box or heading is pushed to the next page and leaves a gap | Shorten a sentence on the page, or `\enlargethispage{2\baselineskip}` before the break |
| A chapter's last page holds two lines | Trim the chapter slightly, or `\enlargethispage` on the page before |
| A figure floats far from its text | Move the `\input` earlier, or shrink the figure's height |
| An overfull line from a URL or a long word | `\url{}` (xurl breaks anywhere), `\hyphenation{}` in the preamble, or rephrase |
| A table is too wide | `tabularx` with `X` columns, `\small`, or abbreviations defined in the caption |
| A long box splits across pages | Fine if each part has several lines; otherwise move text around it |
| A box holding a long listing splits after two lines, or leaves a big gap | Put a local `\Needspace{30\baselineskip}` (the box's height) right before the box or its section heading, or split the listing at a natural break (`\lstinputlisting[firstline=..,lastline=..]`) into two boxes |
| A Key idea box is pushed to the next page | Shorten it, or move it a paragraph earlier |

Raising `\Needspace` *locally*, before one box, is fine. Never lower `\Needspace` in `\calloutstart`, the section
`\Needspace` or the heading skips in `preamble.tex` to fix one page: every later box moves and the whole book
repaginates, creating new bad pages elsewhere. `tools/check.sh` check 9 lists pages that end more than a quarter
early and stub chapter endings, but only the visual pass sees everything.
