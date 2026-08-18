# Editable MaTeX

*[ LLM Generated ]*

> Type: defect
<!-- Status is the folder: Active/ Backlog/ Done/ Dropped/. Move the file to change it. -->

## Spec

**A converted MaTeX cell is a picture, so the mathematics in it can no longer be typed.** `maTeXCell`
writes `Cell[ BoxData[ ToBoxes @ MaTeX`MaTeX[ … ] ], style, … ]` — a `GraphicsBox`, which the front end
lets an author select and resize and not edit. The TeX is not lost: it rides in the cell's
`"SourceTeX"` tagging rule, and `ConvertMaTeXToLaTeX` gives it back. But recovering it means replacing
the cell from a palette button, reading the text, retyping, and converting again, so in practice the
conversion is one-way and the author stops using it. Pavel's report, 2026-08-01, pointing at
[the TikZ tutorial](https://www.wolframcloud.com/obj/nikm/Published/TikZ.nb).

**The front end already ships the box that solves this, and the tutorial's `init.m` hook is the other
half of it.** Measured in 15.0.0: `InputAssistant`TeXAssistant[ "\\frac{a}{b}" ]` — what Ctrl+4 makes —
answers

```wl
TemplateBox[
  <| "boxes" -> FormBox[ FractionBox[ StyleBox["a","TI"], StyleBox["b","TI"] ], TraditionalForm ],
     "errors" -> { }, "input" -> "\\frac{a}{b}", "state" -> "Boxes" |>,
  "TeXAssistantTemplate" ]
```

so the box **carries the TeX beside the typeset result**, and clicking it is the front end's own
business: `Core.nb` declares the style `Deployed -> True` with
`DisplayFunction -> DynamicBox[ InputAssistant`InputAssistantBoxes[ 1, "TeXAssistant", Dynamic[#input],
Dynamic[#boxes], Dynamic[#errors], Dynamic[#state] ] ]` and `InterpretationFunction -> Slot["boxes"]`,
and `InputAssistant.mx` carries `doEnterTeXAssistant`, `AssistantInputField` and the string
`TeXStringToBoxes` — which is exactly the symbol the tutorial's hook overrides. So an edit re-renders
through **MaTeX** rather than through the built-in parser precisely when `$useMaTeXQ` is `True`, and
that hook is already what `OpenMaTeXPreferences` writes (`$maTeXPreferences` in `MaTeX.wl`, shipped
with `$useMaTeXQ = False`).

**The wrapper is display-transparent, and that is a measurement rather than a hope.** One
`DisplayFormula` cell holding `\mathcal{K}(G) = K_k(G)`, rendered as a whole notebook at 144 dpi under
`Background -> White` + `LightDark -> "Light"`: bare graphic **{183, 40} px, 1083 ink**, the same
graphic inside the template **{183, 40} px, 1083 ink**. And it survives a file: `Export` then
`NotebookOpen`/`NotebookGet` returns **one** `TeXAssistantTemplate` with all four slots and
`"input"` byte-intact — this box does *not* split the way a `ButtonBox` in a `TextData` does.

**Two states, and only one of them may be written.** `"Boxes"` renders. `"Input"` written from the
kernel falls through `InputAssistantBoxes`' own `Which` to `pleaseUpgradeBoxes` and draws the panel
*"Displaying this output requires a more recent version"* — which looks like a version problem and is
not one. The input state is the front end's to enter on a click; the paclet writes `"Boxes"`.

**Decided with Pavel, 2026-08-01.** (1) Use the front end's `TeXAssistantTemplate` rather than
declaring a MathNotebook template of our own in the six sheets. (2) The box's `"input"` slot is
**authoritative** for export and re-render, with `"SourceTeX"` kept as a mirror refreshed from it — so
TeX edited in the notebook reaches the `.tex`, the `thebibliography` side of the repo's
who-owns-the-entries split rather than the `.bib` side. (3) Generated notebooks should route their
mathematics through MaTeX (see the second half below). (4) Work item first, then T1.

### The other half of the report: the wide inline mathematics

**"The elements in the cells are far away from each other" is the front end's typesetting, not the
content, and no box surgery fixes it.** Measured at 216 dpi in an `InlineFormula` cell, width in px:

| boxes | px |
|---|---|
| `RowBox[{ K, RowBox[{ "(", G, ")" }] }]` (plain letters) | 101 |
| `RowBox[{ 𝒦, RowBox[{ "(", G, ")" }] }]` | 107 |
| the literal **string** `"𝒦(G)"` | 107 |
| `RowBox[{ 𝒦, "(", G, ")" }]` (flat, no group) | 97 |
| `StyleBox[ …, AutoSpacing -> False ]` | 107 |
| the file's own form (`SpanMaxSize -> 1` parens, `"TI"` styling) | 112 |

A bare string measures the same as a nested `RowBox`, so the gap is not the flat/ungrouped parentheses
the file happens to carry: the front end reads `𝒦` followed by `(G)` as a **product** and sets a thin
space, and the script glyph adds side bearing on top. LaTeX does neither. Rendered side by side, the
built-in TeX assistant on `\mathcal{K}(G) = K_k(G)` draws `K (G) = K_k (G)` — losing the `\mathcal` as
well — where MaTeX on the same string draws `𝒦(G) = K_k(G)` tight. That is the whole of the second
screenshot: the loose one is native typesetting, the tight one is LaTeX.

Two things found beside it, neither this item's to fix. `texToBoxes[ "K_k(G)" ]` answers
`TemplateBox[{ "k", "G" }, "BesselK"]` and `texToBoxes[ "T_k(G)" ]` answers `ChebyshevT` — a **fourth**
failure mode of the expression path, alongside "not one expression", "malformed" and the `E`/`I` letters:
a subscripted letter that names a special function. It renders plausibly and means something else, so
no display test catches it. And a probe fault to skip: `ToString[ boxes, InputForm ]` printed the
equals sign of `G = (V, E)` as `""`, which reads as a dropped operator — it is a private-use named
character the terminal draws as nothing, the trap this repo already records for `\[ExponentialE]`. The
render showed the `=` was there all along.

## Tasks

### To do

- [ ] T2 — the hook, which is what makes an *edit* render as MaTeX rather than reverting to native
      boxes. Decide between shipping `$useMaTeXQ = True` in `$maTeXPreferences`, a palette toggle that
      writes it, and setting it from the paclet's own loader; the preamble the hook uses should be the
      paclet's. Note the cost: the override is global to the front end, so it changes Ctrl+4 in every
      notebook the author opens, not only a MathNotebook paper.

- [ ] T3 — inline mathematics, as a **choice and not a default** (Pavel, 2026-08-01: "not all the math
      should be in MaTeX — there is the choice, and then there is the conversion in the palette").
      Native typeset boxes stay what a notebook holds; MaTeX is what an author converts *to*, on a
      selection, from the palette — the model the two existing buttons already have. What is missing is
      the inline grain: `ConvertLaTeXToMaTeX` is keyed on whole cells, so a `$…$` island inside a
      paragraph cannot be converted at all, which is exactly the mathematics in a generated Definition
      cell. The deliverable is that inline converter and its two palette buttons; the generator (the
      plugin's `research-notebook` skill) then needs no change, and a notebook opened on a machine with
      no LaTeX still shows the mathematics it was written with.

      **Corrected 2026-08-18 (S2): the inline converter now exists** — it arrived on `main` in 0.1.24
      while this item sat on a diverged clone. `laTeXToMaTeXCell` branches on `mixedLaTeXQ` into
      `laTeXMixedMaTeXCells`, whose `maTeXPartCell` sends each prose chunk through `splitInlineMaTeX`,
      so a `$…$` or `\( … \)` island becomes an `inlineMaTeXCell`. The four palette buttons already
      route through those entry points, so what is actually left of T3 is narrower than written: decide
      whether the inline grain wants **its own** two buttons, and fix the button descriptions (T5).

- [ ] T4 — the two findings above: a `Tests/Conversion.wlt` assertion that a subscripted
      special-function name is routed to `presentationBoxes` rather than parsed, and the CLAUDE.md
      lines for both.

- [ ] T5 — **two palette descriptions are now false**, and one contradicts this item's own T1.
      `math → MaTeX` still says *"The result is an image rather than editable math, so render last"* —
      T1 made it editable, which was the point. `LaTeX → MaTeX` still says it takes *"each cell whole"*
      — 0.1.24 stopped doing that for prose cells. Both live in `Scripts/BuildPalette.wls`; regenerate
      the palette after, and note that `Tests/Palette.wlt` reads labels and structure, not prose, so
      neither string is asserted. This is the staleness `CLAUDE.md` warns about under the tutorial
      bullet, one directory over.

- [ ] T6 — the release call: `PacletInfo.wl` still reads **0.1.24**, which is the published version,
      while `main` now also carries T1. Either bump and publish, or leave it and accept that installed
      0.1.24 and the repo differ by T1 — the clone/install disagreement the wiki article flags. Not the
      merge's decision to make.

### Done

- [x] T1 (S1) — `maTeXCell` wraps its graphics in `maTeXBox`, the front end's `TeXAssistantTemplate`;
      the precedence is stated once in `storedSourceTeX`, so `mathTeX`, `displayTeXString`,
      `inlinePartToTeX`, `laTeXSourceText` and `resizedMaTeXCell` all inherit it, and `maTeXEditedQ`
      makes an edit invalidate the recorded typed source. Seven kernel tests and one front-end
      assertion, all four bites confirmed.

## Progress

### S1 — 2026-08-01

**Done: T1.** `maTeXBox` / `maTeXBoxTeX` in `MaTeX.wl`, box-preferring `storedSourceTeX` and
edit-invalidating `storedLaTeXSource` (with `maTeXEditedQ`) in `Conversion.wl`. Suite **416 passed, 0
failed** — `Tests/MaTeX.wlt` 15 → 22, `Tests/FrontEnd.wlt` 62 → 63.

**Four bites, each confirmed by reintroducing the defect** (file copied aside, restored from the copy,
byte-identity asserted afterwards — never `git checkout --`):

| bite | fails |
|---|---|
| `storedSourceTeX` ignores the box | **3** of `MaTeX.wlt` |
| `storedLaTeXSource` keeps the stale typed source | **1**, actual output the pre-edit `$$ x^2 $$` |
| `maTeXCell` writes the bare graphics again | **1** of `FrontEnd.wlt`, `{0, None}` against `{1, "x^2"}` |
| (baseline, unpatched) | 0 |

**One finding, and it cost the session its only red test.** `Tests/FrontEnd.wlt`'s `maTeXWidth` read
`GraphicsBox[ ___, ImageSize -> { w_, _ }, ___ ]` and answered **0** the moment the graphic moved into
the template, failing the ConversionUX T2 size test with `{28, False, False, True}` — a *size*
regression reported where nothing about the image had changed. Measured either way in one front end:
**the front end normalizes displayed boxes and only displayed boxes.** A graphic written as a cell's
content comes back with its options spliced up as its own arguments (`ImageSize` at position
`{1,1,1,1,4}`); the same graphic parked in a `TemplateBox`'s association slot comes back exactly as the
kernel wrote it, options still in a nested list (`{1,1,1,1,1,Key["boxes"],2,1}`). The width is present
and identical (91.4887) in both. The helper now reads the option wherever it stands, which is also what
makes it survive the unwrapping bite.

**Still open and not this task's:** T2 is what decides whether an *edit* comes back as MaTeX or as
native boxes, so until it lands the box is editable and the re-render is the built-in parser's unless
the author has turned `$useMaTeXQ` on himself.

### S2 — 2026-08-18 — the merge

**No task closed; this was integration.** The two clones had diverged with neither holding the other's
HEAD: this item's T1 (`63d6c28`) lived only in the author's Dropbox working copy, while `origin/main`
carried 0.1.24's inline islands and multiline display environments (`b99cde6`). Both were MaTeX work on
the same four files. Merged as `4f2495d`, and all three copies plus `origin/main` now sit on it.

The sides were **complementary rather than competing** — 0.1.24 added coverage (inline islands, the
`$displayDelimiters` fourth field, `ensureMaTeX` pulling in mathtools for `multlined`), T1 changed
representation (the assistant box, the `"input"` slot's precedence, the edit-invalidated
`"LaTeXSource"`). Only `MaTeX.wl` conflicted and both hunks were pure add/add.

**One integration no textual merge would have made:** `inlineMaTeXCell` now wraps its island in
`maTeXBox` too. 0.1.24 wrote that builder before the box existed, so without it a display formula was
editable and an inline island silently was not. It composes the other way as well — `maTeXBoxTeX` was
kept narrow *because* "a `Text` cell may hold several inline assistant boxes", which was hypothetical
when T1 was written and is the ordinary case now that islands are wrapped: each island is its own
`Cell`, so `storedSourceTeX` reads it per island and an edited island exports its edit.

**Suite 398 passed, 0 failed**, against a same-session baseline of **390** on `b99cde6` — the delta is
exactly T1's eight assertions (`MaTeX.wlt` 21 → 28, `FrontEnd.wlt` 62 → 63) and no other file moved.
The 416 recorded in S1 was a different environment and is not the comparison.

**A hazard worth recording:** git surgery inside the Dropbox folder races the sync daemon — a rebase
attempted there aborted mid-flight on `FrontEnd.wlt` and `MaTeX.wlt`, files the daemon had touched
underneath it. The merge was therefore done in the plugin's reference clone and handed back by
fast-forward. That clone is now formally read-only: the plugin's `CLAUDE.md` records this Dropbox copy
as the source of truth, where edits are made and from which pushes go.
