# Workflow in detail

The phases of SKILL.md with commands, agent prompts and acceptance gates. Launch every agent with the model and
thinking level given here and in SKILL.md ("Models and thinking levels"). "Compiler" means you, the main session:
you own the shared files (`preamble.tex`, `kit.tex`, `bookmeta.tex`, `main.tex`, bibliographies, glossary, preface),
dispatch the agents, integrate and push.

## 1. Intake

Settle these, asking only what you cannot default (one short message), and state the defaults you chose:

| Question | Default if unstated |
|---|---|
| Who reads it, and what do they already know? | Technically literate, new to the field |
| Reading guide, crash course or both? | Both: a crash-course part for the background, reading-guide parts for the literature |
| Scope and size | 8-16 chapters, about 6-10 pages each; cards for the 40-80 most important papers |
| A deep-dive part on one sub-area? | Only if asked |
| Append the cited papers in a combined PDF? | Yes when the corpus is on arXiv (169 papers made a 1.9 GB, 4,300-page volume) |
| Spelling and date style | American (`SPELLING="american"` in `tools/book.env`) |
| Where it lives | A new git repository; a private remote only if the user agrees |

## 2. Scaffold

```bash
df -h .                                    # stop and tell the user if under 2 GB free
bash <skill dir>/scripts/new_book.sh <dir> "<Title>" "<Short title>" [File_Name]
```
Then edit `bookmeta.tex` (subtitle, keywords, `\connectionname`), `tools/book.env` (`LETTER_PREFIXES` if a lettered
part is planned), `tools/data/groups.tsv` (how the appended papers are grouped), replace the parts in `main.tex`, and
make the first commit. If the project uses an issue tracker, create one issue per phase and one per chapter.

## 3. Corpus (reading guides)

1. **Candidates.** Start from the field's most-cited surveys and textbooks, your own knowledge, and searches:
   `python3 -I tools/search_arxiv.py <outdir> 50 <name> 'all:"surface code" AND all:"decoder"' ...`. Get citation
   counts as a rough signal: `python3 -I tools/fetch_s2.py <candidates.tsv> <outdir>`.
2. **Tiers.** A = essential (read it if you read only a handful), B = important (an idea later work builds on), C =
   context (background or a notable variant). Criteria: influence, pivot (did it change what others did?), clarity,
   recency. Tiers are judgments; the preface says so.
3. **Register.** Write rows `key<TAB>arxiv_id<TAB>tier<TAB>section_code<TAB>Short name` and run
   `python3 -I tools/add_arxiv.py rows.tsv`. Read the printed titles: a wrong id is the commonest error. Venues go in
   `tools/data/venues.tsv` only when confirmed (arXiv comment or journal-ref, proceedings page, Crossref); rerun
   `python3 -I tools/build_meta.py tools/data/candidates.tsv tools/data/venues.tsv tools/data/arxiv_meta.json .`
   after editing it.
4. **Other sources.** Books, journal-only papers, documentation, blog posts: check with `tools/crossref.py DOI` or,
   without a DOI, the publisher's page and its BibTeX export (record the URL; never fill in a DOI from memory), then
   add to `refs_manual.bib` (`@online` with `urldate` for web pages).
5. **PDFs.** Download a paper before its card is written, so that the card can be checked against the text:
   ```bash
   python3 -I tools/make_cited_keys.py . > tools/data/cited_keys.json   # after a build: the cited papers
   # or, for papers registered but not yet cited, write the list by hand:
   #   {"arxiv": {"vaswani2017attention": "1706.03762"}, "manual": []}  -> tools/data/cited_keys.json
   python3 -I tools/fetch_papers.py tools/data/cited_keys.json papers
   python3 -I tools/pdfgrep.py vaswani2017attention 'multi-head' 'BLEU'   # matches with their page numbers
   ```
   `fetch_papers.py` is polite (one request at a time, back-off), resumable (`papers/manifest.tsv`) and stops under
   3 GB free.
6. **Reading notes.** Reading agents (`model: sonnet`, `effort: medium`), 5-10 sources each, with
   `briefs/notes_brief.md`. Their notes go to
   `provenance/notes/`; chapter writers build on them, and fact-checkers use them only to find passages.

## 4. Architecture

* **Parts.** A reading guide that worked: Orientation (what the field is, the background primer); the course of
  developments (chronological, one chapter per era); technical threads (cross-cutting design choices); a deep-dive
  part if asked; reference (open problems, resources, glossary); the papers. A crash-course part slots in after the
  orientation as a lettered part (chapters C1, C2, ...) so that adding it never renumbers the other chapters.
* **Chapter map.** One row per chapter: file, `\label`, title, page budget, the minimum content, worked-example
  numbers, the figures wanted, and whether it is math-heavy or safety-critical (its writer then runs at
  `effort: high`). It goes into section 3-4 of `briefs/writers_guide.md`.
* **Front matter.** The preface states what the book gives, how the list was chosen and checked (with dates), and
  its caveats. "Advice for the reader" has prerequisites, the part map, the dependency chart
  (`figures/fig_chapterdeps.tex`), the tier legend, reading paths (a short path and a 8-12 row core path in teaching
  order), conventions.
* **The exemplar.** Write one chapter yourself, in full, to the guide, build it, look at every page, and fix it until
  it is what you want every chapter to be. Writers copy its shape; time spent here is saved many times over.

## 5. Drafting with writer agents

Dispatch writers in parallel (`model: sonnet`, `effort: medium`; `effort: high` for math-heavy or safety-critical
chapters), at most about 4-6 at once (each runs LaTeX builds; more contend for CPU and memory), in the background,
each on its own chapter. A writer prompt contains, in order:

1. "You are the writer of chapter <N>, <title>, of <book>, in `<repo path>`."
2. "Read `briefs/writers_guide.md` whole, then the exemplar `chapters/<file>`, before writing."
3. The chapter's row and content list (also in the guide, but repeat it: it is the task).
4. Where the sources are: the notes files, the paper keys to use, `tools/pdfgrep.py`.
5. Environment facts: the shell and its traps, what is installed, the attribution trailer for commits, "never delete
   files", "no background jobs", "save a full draft early".
6. "Your final message is your report (section 12); also save it as `provenance/writers/<chapter>.md`."

Gate for each chapter: `build_chapter.sh` exit 0, no undefined citations, no overfull box over 1 pt, within the page
budget, every figure looked at, every number recomputed (logged in the report), committed. When a writer's session
ends early, check what is on disk and committed, then resume it (send it a message) or start a new writer on the
same file with "continue the draft in place".

## 6. Independent fact-check

* Group chapters into blocks of about 100 checkable claims (2-3 chapters). One checker per block (`model: opus`,
  `effort: high`), with
  `briefs/factcheck_brief.md` and the block's files. Checkers are not the writers and get no summary of your own
  views of the text.
* Read every report. For each non-confirmed item, apply the fix (the writer, a fixer agent given the report and the
  chapter at `model: sonnet`, `effort: medium`, or you) and log the item in `provenance/factcheck/<block>_applied.md` as APPLIED, ALREADY FIXED (the text
  no longer makes the claim) or DECLINED (with the reason). Rebuild and recheck the chapter afterwards.
* For a crash course, consider one more agent (`model: sonnet`, `effort: low`) that reads as the target reader
  (given only the prerequisites) and
  lists every term used before it is defined and every step it could not follow.
* What checkers caught that writers had missed, in practice: figures with arrows, current directions or battery
  polarity reversed; a safety checklist in the wrong order; an emergency stop that restarted on release; a statement
  that held for one sign only; worked examples with a wrong count; claims sourced to the wrong table. Budget for a
  real fix round.

## 7. Integration (compiler)

* Glossary: merge the writers' proposed entries (yourself, or an agent at `model: sonnet`, `effort: low`),
  alphabetical, one line each, with the chapter where it is explained.
* Cross-references: add the ones writers asked for (forward and backward), check that `\cref` targets exist.
* Citations: place the references the writers asked for (`NEED REF` lines), each checked before it is added.
* Preface and title verso: the dates of verification, the method, the caveats, the counts (`\npapers` is generated).
* `README.md` and `provenance/README.md`: what each file is, which checks were done, and their limits.
* `python3 -I tools/americanize.py . --write` if the spelling check fails (then reread the diff).
* Say only what was done: the title verso, the preface and `provenance/README.md` describe the checks that actually
  happened (`check.sh` check 5b fails if the book mentions fact-checks and `provenance/factcheck/` is empty).
* Replace the template's example chapters, and grep for their labels (`ch:tour`, `ch:reading`, `part:start`,
  `part:literature`, `fig_decay`) in `main.tex`, `chapters/` and `figures/`.

## 8. Build and QA

```bash
bash tools/check.sh                                   # all hard checks must pass
bash tools/contact_sheets.sh build/main.pdf build/qa  # then open every sheet
pdftoppm -r 120 -f N -l N -png build/main.pdf build/qa/zoom   # suspicious pages, then crop and look
```
Look for: headings stranded at a page bottom, boxes split badly, near-empty pages (check 9 lists them), figures far
from their text, overlapping labels, `??`, red `\fillin` text. Check 9 lists pages that end early and stub chapter
endings; the sheets show the rest. If you delegate the sweep (`model: sonnet`, `effort: medium`), still look
yourself at every page it flags and at a sample of the others. Fix locally (see `style.md`, "Layout repair"). Rerun `check.sh` after every change;
a passing run is the gate, not the change. Its last line counts the NOTEs; read them before delivering.

## 9. Combined volume

```bash
bash tools/build_volume.sh          # rebuilds until the book's page count settles, joins, repairs, copies the book
python3 -I tools/verify_volume.py <BOOK_NAME>_with_papers.pdf build/papers_order.json
bash tools/compare_pages.sh <BOOK_NAME>.pdf <BOOK_NAME>_with_papers.pdf   # first, second, middle, last page
```
`verify_volume.py` prints where sample links land; read them. A few papers' PDFs print syntax warnings in pdfunite;
they are harmless if the verifier passes. Keep the combined PDF out of git (it is in `.gitignore`).

## 10. Deliver

Commit, and push if the repository has a remote (only the compiler pushes). The final message, in this order:

1. What the book is now: parts and chapter count, pages, papers carded and appended, figures.
2. Where the files are: the book PDF, the combined PDF, the sources, the briefs and provenance.
3. How it was checked: which blocks had an independent fact-check, the headline errors they caught (they show the
   checks were real), what `check.sh` verifies.
4. What was **not** verified, item by item, and why (sources that could not be reached, numbers taken from memory
   and hedged, figures whose generators were lost).
5. Known layout leftovers (sparse pages, small label clashes) and optional next steps.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The whole book repaginates after a "small" preamble change | A global spacing setting (`\Needspace` in `\calloutstart`, section skips) was lowered to fix one page | Revert; fix the page locally |
| `??` in the PDF | A label from another chapter in a one-chapter build (fine), or a typo in a full build | `check.sh` checks 2 and 5 on the full build |
| A cited key shows in bold instead of a label | The key is not in either `.bib` file | `check.sh` check 2 (matches both log quote styles and biblatex's message) |
| `arXiv returned nothing` or a wrong title from `add_arxiv.py` | Wrong or placeholder id | Fix the id; titles are printed for this reason |
| HTTP 429 or 503 from arXiv | Too many requests | Built-in back-off; one process at a time; do not parallelize fetches |
| A web page answers 403 or 404 to curl but works in a browser | Bot filtering | Verify through another route (search result, archive, the PDF itself) and say so in the provenance |
| The abstract and the PDF disagree | Versions or rounding | Quote both in the notes; the text says which it follows |
| `pdfunite` output has no bookmarks and dead links | Known pdfunite behavior | `tools/build_volume.py` repairs it; never ship the raw union |
| Page numbers in the papers listing are off | The listing changes the book's length | `build_volume.sh` loops until stable; `check.sh` check 10 notes staleness |
| `.git/index.lock` errors | Parallel writers committing | Wait and retry; path-limited commits only |
| In zsh, `$FILES` is passed as one argument; `echo =====` fails; `${PIPESTATUS[0]}` is empty | zsh does not split words, expands `=word`, and calls it `pipestatus` | Use arrays or `bash -c '...'`; quote separators and globs |
| `pdfgrep.py` misses a phrase that is in the paper | pdftotext dropped a line-end hyphen or scrambled a table | Loosen the pattern (`800-?800`), then confirm on the page with `pdftotext -layout -f N -l N` |
| Disk fills during downloads | Large corpora (about 10 MB per paper) | `df -h` before; `fetch_papers.py` stops under 3 GB free |
| Orphaned chapter or figure files | A chapter or figure was cut but its file kept | `check.sh` check 8 lists them; include it, or `git rm` it (the compiler, not a writer) |
| Contact sheets skip pages | `pdftoppm` pads page numbers by document length | `tools/contact_sheets.sh` sorts with `sort -V` |
