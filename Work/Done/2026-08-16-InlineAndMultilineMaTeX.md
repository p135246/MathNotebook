# Inline And Multiline MaTeX

*[ LLM Generated ]*

> Type: feature
<!-- Status is the folder: Active/ Backlog/ Done/ Dropped/. Move the file to change it. -->

## Spec

**MaTeX rendered display formulas only, and the typed-LaTeX conversion knew four environments.**
Requested by Pavel 2026-08-16 out of the Infrageometry research-notebook build, where inline
mathematics had to be MaTeX-rendered generator-side because the paclet had no inline form, and
`gather`/`multline` sources had nowhere to go: "We need to support inline and displayed forms",
plus typed-LaTeX-in-the-cell conversion "handling multiline environments".

Measured before the change, at 0.1.23:

- `toMaTeXCell` had one converting clause, keyed `"DisplayFormula" | "DisplayFormulaNumbered"`;
  a prose cell with typeset islands passed through whole, islands untouched.
- `laTeXToMaTeXCell` took every cell whole, so `Let $x^2$ be...` rendered as one display image of
  the entire sentence.
- `$displayDelimiters` ended at `align`; `\begin{gather}a\\b\end{gather}` fell through to the
  bare-fragment branch and MaTeX errored on a display environment in math mode.
- `MaTeX["\begin{multlined}a\\b\end{multlined}"]` answers `$Failed` even wrapped: `multlined`
  lives in mathtools, absent from MaTeX's `BasePreamble`.
- `rescaleMaTeXCells` selected by `maTeXCellQ` on whole cells, so no slider could ever have
  reached an island.

## What was built

One inline builder beside the display one, `inlineMaTeXCell[ tex, size ]` — `"DisplayStyle" ->
False`, style `"InlineFormula"`, the same `SourceTeX`/`MaTeX` tagging, so `maTeXCellQ`, the
re-render and the trip back to LaTeX treat both forms through one predicate. On it:

- `toMaTeXCell` gained a `TextData` clause converting island by island (stored source, else
  `boxesToTeX`), skipping anything holding a `ButtonBox` so citations survive.
- `fromMaTeXCell` and `maTeXToLaTeXCell` gained the reverse clauses: islands back to native
  typeset islands, or re-wearing their dollars in typed text, adjacent strings merged.
- `laTeXToMaTeXCell` branches on `mixedLaTeXQ`: one display formula or a bare fragment renders
  whole exactly as before; prose renders piecewise through `laTeXMixedMaTeXCells`, the MaTeX twin
  of `convertLaTeXCell` — display spans to display cells remembering the span as typed, chunks to
  prose cells with inline islands.
- `$displayDelimiters` generalized: the fourth field is now the math-mode inner environment
  (`aligned`, `gathered`, `multlined`, `alignedat`) or `None`; covers `gather`, `multline`,
  `alignat`, `flalign`, starred and not. The closing brace of each opener keeps prefixes apart —
  `\begin{align}` cannot take the head of `\begin{alignat}`. `displaySource`, `displaySpanCell`
  and `displayBodyBoxes` follow the field; `stripGridArgument` takes the alignat column count off
  before the native grid.
- `ensureMaTeX[]` replaces the bare `Needs["MaTeX`"]` at every rendering entry: it appends
  `\usepackage{mathtools}` to MaTeX's user `"Preamble"` once and only when absent, so `multlined`
  compiles and an author's own preamble survives.
- `rescaleMaTeXCells` selects by `maTeXContentQ` (cell or island) and `resizedMaTeXCell` re-renders
  islands inside prose, so both sliders reach inline mathematics.

## Verified

Kernel-side at 0.1.24, 2026-08-16: the mixed cell `Let $x^2$ and \(y_i\) obey $$\int f = 0$$ and
also \begin{align}a&=b\\c&=d\end{align} always.` converts to Text / DisplayFormula / Text /
DisplayFormulaNumbered / Text with two inline islands and four MaTeX images; `ConvertMaTeXToLaTeX`
returns the typed spans verbatim (`\( \)` comes back as `$ $`, the one documented paraphrase);
`ConvertFromMaTeX` returns native islands and native display boxes with sources preserved;
`gather` and `multline` render whole-cell with the mathtools preamble; `resizedMaTeXCell[ 20 ]`
re-renders islands. Six pure tests added to `Tests/MaTeX.wlt` (environment normalization, grid
boxes, island reverse trips); the rendering path itself stays untested by the suite, which runs
without a TeX distribution by design.
