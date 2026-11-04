"""Normalize British spellings to American in the book's .tex sources.
usage: americanize.py ROOT [--write]
Protects: comment lines, ``...'' verbatim quotes, \\cite-like args, \\begin{papercard}/{webcard} lines, URLs, macro names."""
import re, sys, glob, os, difflib
root = sys.argv[1]; write = "--write" in sys.argv
M = {}
def add(br, am):
    M[br] = am; M[br[0].upper() + br[1:]] = am[0].upper() + am[1:]
for br, am in {
 "analyse":"analyze","analysed":"analyzed","anonymised":"anonymized","behaviour":"behavior","behaviours":"behaviors","behavioural":"behavioral",
 "centre":"center","centred":"centered","colour":"color","colours":"colors","componentised":"componentized","customised":"customized",
 "discretisation":"discretization","discretise":"discretize","discretised":"discretized","favour":"favor","favours":"favors","flavours":"flavors",
 "generalise":"generalize","generalises":"generalizes","initialised":"initialized","initialising":"initializing","reinitialise":"reinitialize",
 "internalising":"internalizing","judgement":"judgment","labelled":"labeled","relabelling":"relabeling","licence":"license","licences":"licenses",
 "localisation":"localization","maximises":"maximizes","millimetres":"millimeters","minimise":"minimize","modelling":"modeling","motorised":"motorized",
 "neighbouring":"neighboring","normalisation":"normalization","normalise":"normalize","normalised":"normalized","normalises":"normalizes",
 "optimisations":"optimizations","organise":"organize","organised":"organized","organises":"organizes","parallelisation":"parallelization",
 "popularised":"popularized","programme":"program","programmes":"programs","quantisation":"quantization","quantises":"quantizes",
 "randomised":"randomized","robotised":"robotized","sceptical":"skeptical","serialised":"serialized","specialised":"specialized",
 "standardise":"standardize","standardised":"standardized","standardises":"standardizes","summarise":"summarize","summarising":"summarizing",
 "synchronised":"synchronized","synthesise":"synthesize","tokenised":"tokenized","tokenising":"tokenizing","verbalises":"verbalizes","voxelise":"voxelize",
 "aluminium":"aluminum","analogue":"analog","analogues":"analogs","artefact":"artifact","artefacts":"artifacts","cancelled":"canceled","catalogue":"catalog",
 "centimetre":"centimeter","centimetres":"centimeters","fibre":"fiber","fibres":"fibers","grey":"gray","kilometre":"kilometer","kilometres":"kilometers",
 "levelling":"leveling","litre":"liter","litres":"liters","manoeuvre":"maneuver","manoeuvres":"maneuvers","metre":"meter","metres":"meters","micrometre":"micrometer",
 "micrometres":"micrometers","sulphur":"sulfur","travelling":"traveling","tyre":"tire","tyres":"tires","whilst":"while","ageing":"aging","defence":"defense",
}.items():
    add(br, am)
word_re = re.compile(r"(?<![\\\w])(" + "|".join(sorted(map(re.escape, M), key=len, reverse=True)) + r")(?![\w])")
prot_re = re.compile(r"(``.*?''|\\(?:cite|citep|citet|cref|Cref|ref|label|input|url|href|includegraphics|colorlet|definecolor|csdef|pfield|papercard|webcard)\*?(?:\[[^\]]*\])?\{[^}]*\})")

MON = r"(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)"
date_re = re.compile(r"(?<![\d.])(\d{1,2})(~|\\ | )" + MON + r"(?![A-Za-z])(?:(~|\\ | )(\d{4}))?")
def conv_dates(line):
    if line.lstrip().startswith("%"): return line
    def rep(m):
        day, sep1, mon, sep2, year = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        if not (1 <= int(day) <= 31): return m.group(0)
        s = f"{mon}{sep1}{day}"
        if year: s += f", {year}"
        return s
    return date_re.sub(rep, line)

def conv(line):
    if line.lstrip().startswith("%"): return line
    if line.lstrip().startswith(("\\begin{papercard}", "\\begin{webcard}")): return line
    cm = re.search(r"(?<!\\)%", line)          # a trailing comment is left as it is
    if cm:
        return conv(line[:cm.start()]) + line[cm.start():]
    out, pos = [], 0
    for m in prot_re.finditer(line):
        out.append(word_re.sub(lambda x: M[x.group(1)], line[pos:m.start()])); out.append(m.group(0)); pos = m.end()
    out.append(word_re.sub(lambda x: M[x.group(1)], line[pos:]))
    return "".join(out)
files = sorted(glob.glob(os.path.join(root, "chapters/*.tex")) + glob.glob(os.path.join(root, "figures/*.tex")) + [os.path.join(root, "main.tex")])
nchg = 0
for f in files:
    old = open(f, encoding="utf-8").read().split("\n")
    new = [conv_dates(conv(l)) for l in old]
    for i, (a, b) in enumerate(zip(old, new), 1):
        if a != b:
            nchg += 1
            # print only the changed words, with a little context
            sa = re.findall(r"\S+", a); sb = re.findall(r"\S+", b)
            ch = [(x, y) for x, y in zip(sa, sb) if x != y]
            print(f"{os.path.relpath(f, root)}:{i}: " + "; ".join(f"{x}->{y}" for x, y in ch))
    if write and old != new:
        open(f, "w", encoding="utf-8").write("\n".join(new))
bib = os.path.join(root, "refs_manual.bib")
if os.path.exists(bib):
    oldb = open(bib, encoding="utf-8").read().split("\n")
    newb = [conv_dates(l) if re.match(r"\s*(note|howpublished)\s*=", l) else l for l in oldb]
    for i, (a, b) in enumerate(zip(oldb, newb), 1):
        if a != b:
            nchg += 1
            print(f"refs_manual.bib:{i}: {a.strip()} -> {b.strip()}")
    if write and oldb != newb:
        open(bib, "w", encoding="utf-8").write("\n".join(newb))
print("changed lines:", nchg)
