Needs[ "WolframInstitute`MathNotebook`" ]
AppendTo[ $ContextPath, "WolframInstitute`MathNotebook`PackageScope`" ]

(* The other test files are kernel-only and stub every chain read. This one is the opposite on
   purpose: both defects in ViewAndReferenceDefects passed their unit tests and still shipped
   broken, because "the call wrote an override cell" is not "the style changed size". Everything
   here is measured through a real front end and a real stylesheet chain, so the assertions are the
   reproductions Pavel reported rather than restatements of the code.

   The sheets are embedded with Get rather than named: a paclet stylesheet resolved by name has
   been seen to fall back to Default.nb in a headless run, so every measurement asserts the sheet
   really loaded before it is trusted. While a view override is installed, the private sheet's
   parent is an embedded notebook, and styles it does NOT override then fall through to Default.nb
   — harmless here because every style asserted is one the override writes. *)

$sheetDirectory = FileNameJoin[ { PacletObject[ "WolframInstitute/MathNotebook" ][ "Location" ],
  "FrontEnd", "StyleSheets", "MathNotebook" } ];

$templates = { "AMSArticle.nb", "ArXivArticle.nb", "RevTeXAPS.nb", "SpringerJournal.nb" };

resolvedSizes[ notebook_, styles_ ] := <|
  "Screen" -> AssociationMap[ CurrentValue[ notebook, { StyleDefinitions, #, FontSize } ] &, styles ],
  "Printout" -> AssociationMap[ CurrentValue[ notebook, { StyleDefinitions, { #, "Printout" }, FontSize } ] &, styles ]
|>

(* One front-end session measures every sheet; the tests below are pure comparisons on the result,
   so a front-end failure surfaces as a failed assertion rather than as a message storm. *)
viewMeasurements[ parent_ ] :=
  Module[ { notebook, prose, base, scaled, restored },
    notebook = CreateDocument[ { }, Visible -> False, StyleDefinitions -> parent ];
    prose = Complement[ Keys @ baseFontSizes[ parent ][ "Screen" ], $mathStyleNames ];
    base = resolvedSizes[ notebook, prose ];
    SetDocumentFontSize[ notebook, 20 ];
    scaled = resolvedSizes[ notebook, prose ];
    ResetDocumentView[ notebook ];
    restored = resolvedSizes[ notebook, prose ];
    NotebookClose[ notebook ];
    <| "Prose" -> prose, "Base" -> base, "Scaled" -> scaled, "Restored" -> restored |>
  ]

citationMeasurements[ parent_ ] :=
  Module[ { notebook, styles },
    notebook = NotebookPut @ Notebook[ {
      Cell[ "A section", "Section", CellTags -> "sec" ],
      Cell[ "A theorem", "Theorem", CellTags -> "thm" ],
      Cell[ "A definition", "Definition", CellTags -> "def" ],
      Cell[ "Ollivier, Ricci curvature", "Reference", CellTags -> "ollivier" ],
      Cell[ "Prose", "Text", CellTags -> "prose" ] },
      StyleDefinitions -> parent, Visible -> False ];
    styles = AssociationMap[
      Symbol[ "WolframInstitute`MathNotebook`Referencing`PackagePrivate`citationTargetStyle" ][ notebook, # ] &,
      { "sec", "thm", "def", "ollivier", "prose", "absent" } ];
    NotebookClose[ notebook ];
    styles
  ]

(* Inline Math Converter Defects, requirement 4: assert what a converted cell *displays*. The
   round trip reads back the stored "SourceTeX" rather than the boxes, so a cell that renders as a
   blank still exports byte-identically — display fidelity has to be measured on its own. Ink area
   is the measurement: a converted span carries less ink than the literal "$...$" it replaces (the
   two delimiters are gone) and more than an empty box. *)

inkOf[ image_ ] :=
  Total @ Flatten @ Unitize @ Subtract[ 255,
    ImageData[ ColorConvert[ image, "Grayscale" ], "Byte" ] ]

inkArea[ cell_ ] :=
  inkOf @ Rasterize[ cell, ImageResolution -> 72, LightDark -> "Light" ]

inlineInk[ text_String ] := <|
  "Converted" -> inkArea @ Cell[ TextData @ splitInlineMath[ text ], "Text" ],
  "Literal" -> inkArea @ Cell[ text, "Text" ],
  "Blank" -> inkArea @ Cell[ TextData @ { First @ StringSplit[ text, "$" ],
    Cell[ BoxData[ FormBox[ "", TraditionalForm ] ] ], Last @ StringSplit[ text, "$" ] }, "Text" ]
|>

(* T2: the same assertion one level up. A display environment glued into a paragraph is now split
   into its own cell, so what has to be shown is that the formula really renders and that the
   starred form really is unnumbered. The equation number is a CounterBox and a single rasterized
   cell has no document context to resolve one — both starred and unstarred measured 243 that way —
   so both halves render the whole notebook.

   LaTeXPaperImport T12: a whole-notebook render and a single-cell Rasterize are not on the same
   scale and must never be compared. So every number that appears on both sides of a comparison
   below comes from notebookInk, "Literal" included; the one cell raster left, "Formula", is only
   ever asked whether it is positive. notebookInk takes the notebook rather than the source text,
   so the unconverted paragraph goes through exactly the same measurement as the converted one.
   The appearance is the second half of "the same way", and it takes BOTH options: inkOf counts every
   pixel that is not white, so on a dark appearance an unpinned background counts the whole canvas as
   ink — and Background -> White alone then leaves the prose drawn in the dark appearance's light
   foreground, on white, so a Text cell measures exactly 0 and every comparison against it inverts.
   That is what it did here, silently, until ConversionUX T2; with LightDark -> "Light" beside it the
   paragraph reads 2440 and the two formulas 1268 and 1368, which is what this file always claimed.
   (WindowSize is not pinned because it cannot be — the export
   crops to the content, so the width follows the text and the ink is unaffected by the wrap.)

   "Formula" reads 0 when no DisplayFormula cell was produced at all, rather than measuring what
   FirstCase returned: rasterizing a bare Missing["NotFound"] draws the words and carries 653 ink,
   so "Formula > 0" was passing on a paragraph the converter had left entirely alone. *)

$displayParagraph = "The cone at $p$ is:\n\\begin{equation*}\n  x^2 + y^2 = z^2\n\\end{equation*}\nand that is all.";

notebookInk[ Notebook[ cells_, options___ ] ] :=
  Module[ { notebook, file },
    notebook = NotebookPut[ Notebook[ cells, options ], Visible -> False, Background -> White,
      LightDark -> "Light" ];
    file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookDisplayInk.png" } ], notebook, ImageResolution -> 72 ];
    NotebookClose[ notebook ];
    inkOf @ Import[ file ]
  ]

convertedParagraph[ text_String ] :=
  convertLaTeXNotebook @ Notebook[ { Cell[ text, "Text" ] } ]

displayInk[ text_String ] := <|
  "Starred" -> notebookInk @ convertedParagraph[ text ],
  "Unstarred" -> notebookInk @ convertedParagraph @ StringReplace[ text, "equation*" -> "equation" ],
  "Literal" -> notebookInk @ Notebook[ { Cell[ text, "Text" ] } ],
  "Formula" -> Replace[ FirstCase[ First @ convertedParagraph[ text ], Cell[ _, "DisplayFormula", ___ ] ],
    { cell_Cell :> inkArea[ cell ], _ -> 0 } ]
|>

(* T3: a letter that the kernel reads as a constant is a *display* defect and nothing else — the
   exporter reads the stored "SourceTeX", so a cell showing Euler's number still round-trips
   byte-identically. What has to be measured is the glyph. Every letter carries ink, and E and I
   carry exactly the ink of the italic letters rather than that of the two constants. *)

$letters = Join[ CharacterRange[ "a", "z" ], CharacterRange[ "A", "Z" ] ];

mathInk[ boxes_ ] :=
  inkArea @ Cell[ BoxData[ FormBox[ boxes, TraditionalForm ] ], "Text" ]

letterInk[ ] := <|
  "Minimum" -> Min @ Map[ mathInk @ texToBoxes[ # ] &, $letters ],
  "E" -> mathInk @ texToBoxes[ "E" ], "ItalicE" -> mathInk @ StyleBox[ "E", "TI" ],
  "ExponentialE" -> mathInk[ "\[ExponentialE]" ],
  "I" -> mathInk @ texToBoxes[ "I" ], "ItalicI" -> mathInk @ StyleBox[ "I", "TI" ],
  "ImaginaryI" -> mathInk[ "\[ImaginaryI]" ]
|>

(* FirstReadingDefects T1: the box path used to answer \[Null] for \varnothing — a character drawn
   as nothing, so a single-glyph island measured 0 ink — and inside a RowBox the character was
   dropped outright, so the compound measured exactly the ink of the two glyphs it kept. *)
glyphInk[ ] := <|
  "Varnothing" -> mathInk @ texToBoxes[ "\\varnothing" ],
  "EmptySet" -> mathInk[ "\[EmptySet]" ],
  "Compound" -> mathInk @ texToBoxes[ "U \\neq \\varnothing" ],
  "Relation" -> mathInk @ RowBox[ { StyleBox[ "U", "TI" ], "\[NotEqual]" } ]
|>

(* LaTeXPaperImport T3: an imported \ref has to render as the target's number. The front end
   resolves a CounterBox against the tagged cell with no kernel — and renders XXX when the tag is
   not there, which is the failure this measures. A whole document has to be rendered: a single
   rasterized cell has no document context and every counter in it reads 0. *)

$importedSource = "\\documentclass{article}\n\\newtheorem{defn}{Definition}[section]\n\\begin{document}\n\n\\section{First} \\label{sec:one}\n\n\\section{Second} \\label{sec:two}\n\n\\begin{defn} \\label{def:one}\nA body.\n\\end{defn}\n\nSee Section~\\ref{sec:two} and Definition~\\ref{def:one}.\n\n\\end{document}\n";

importedText[ source_String ] :=
  importedText @ latexToNotebook[ source ]

(* An imported notebook carries a StyleDefinitions of its own since T11 — chosen from the
   \documentclass — and a second one appended after it is ignored, so these tests replace it rather
   than append. Embedding the sheet is the only form that resolves reliably headless. *)
sheetDefinitions[ sheet_String ] :=
  With[ { file = FileNameJoin[ { $sheetDirectory, sheet } ] },
    If[ FileExistsQ[ file ], Get[ file ], sheet ] ]

withSheet[ Notebook[ cells_, options___ ], sheet_String ] :=
  Notebook[ cells, StyleDefinitions -> sheetDefinitions[ sheet ],
    Sequence @@ FilterRules[ { options }, Except[ StyleDefinitions ] ] ]

importedText[ imported_Notebook ] :=
  Module[ { notebook, file },
    notebook = NotebookPut[ withSheet[ imported, "AMSArticle.nb" ], Visible -> False ];
    file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookImported.pdf" } ], notebook ];
    NotebookClose[ notebook ];
    Import[ file, "Plaintext" ]
  ]

(* LaTeXPaperImport T4: a bibliography read out of a .bib has to reach the page. Its Reference cells
   emit nothing into the .tex, so nothing in the round trip can tell whether they render at all —
   only the rendered document can. The entry's label is its own [key] dingbat, written into the cell
   because a dingbat cannot read the tags of the cell it labels. *)

$bibliographySource = "\\documentclass{article}\n\\begin{document}\n\nProse citing \\cite{ehlers} and \\cite[Theorem~1.1]{andreka}.\n\n\\bibliography{refs}\n\n\\end{document}\n";

$bibliographyBib = "@article{ehlers,\n  title={The geometry of free fall},\n  author={Ehlers, J{\\\"u}rgen},\n  year={2012}\n}\n\n@article{andreka,\n  title={A logic road},\n  author={Andr{\\'e}ka, Hajnal},\n  year={2012}\n}\n";

(* LaTeXPaperImport T10: the other bibliography, and the same reason it needs the page. Here the
   entries do reach the .tex — they are the source — so the round trip says they survived, and says
   nothing at all about whether the block renders as a bibliography or as two paragraphs of prose
   with a stray marker in front of each. Only the rendered document separates those. *)

$entrySource = "\\documentclass{article}\n\\begin{document}\n\nProse citing \\cite{smith}.\n\n\\begin{thebibliography}{9}\n\\bibitem[Sm09]{smith} A.~Smith, \\emph{A title}, 2009.\n\\bibitem{jones} B.~Jones, \\emph{Another}, 2011.\n\\end{thebibliography}\n\n\\end{document}\n";

(* LaTeXPaperImport T5: what only the page can show is the numbering — a caption numbers itself from
   its own counter, and article counts figures straight through the document rather than per section,
   so a \ref at a figure has to read "2" and not "2.1" or the front end's XXX. The evaluated figure's
   graphic is put in kernel-side rather than by NotebookEvaluate: the front end's evaluator is the
   same kernel that is driving it, and asking for it from inside UsingFrontEnd hangs. *)

$figurePaper = "\\documentclass{article}\n\\begin{document}\n\n\\begin{figure}\n\\centering\n\\includegraphics{first.png}\n\\caption{The first picture.}\n\\label{fig:one}\n\\end{figure}\n\n\\begin{figure}\n\\centering\n\\includegraphics{second.png}\n\\caption{The second picture.}\n\\label{fig:two}\n\\end{figure}\n\nSee Figure~\\ref{fig:two}.\n\n\\end{document}\n";

(* The imported code is an Import of the file the paper shipped; a figure whose code has been
   evaluated carries its graphic in an Output cell beside it, which is what this stands in for. *)
evaluatedFigures[ source_String ] :=
  Replace[ latexToNotebook[ source ],
    Notebook[ cells_List, options___ ] :>
      Notebook[
        Flatten @ Replace[ cells,
          cell : Cell[ BoxData[ _String ], "Input", ___ ] :>
            { cell, Cell[ BoxData @ ToBoxes @ Graph[ { 1 -> 2, 2 -> 3 } ], "Output" ] }, { 1 } ],
        options ] ]

figureMeasurements[ source_String ] :=
  With[ { evaluated = evaluatedFigures[ source ] },
    <| "Graphics" -> Count[ evaluated, _GraphicsBox, Infinity ],
      "Exported" -> notebookToLaTeX[ evaluated ] === source,
      "Ink" -> notebookImageInk[ evaluated ] > notebookImageInk[ latexToNotebook[ source ] ],
      "Text" -> importedText[ latexToNotebook[ source ] ] |> ]

(* Only a real save can show this: the front end splits a ButtonBox[RowBox[...]] in a TextData into
   one button per run, so before the runs were merged back an imported paper round-tripped only as
   long as nobody wrote it to disk — the specimen's citations came back multiplied five and fifteen
   fold and its \eqref came back as \cite\ref\cite. *)
savedRoundTrip[ source_String ] :=
  Module[ { file, notebook, back },
    file = FileNameJoin[ { $TemporaryDirectory, "MathNotebookSaved.nb" } ];
    Export[ file, latexToNotebook[ source ], "NB" ];
    notebook = NotebookOpen[ file, Visible -> False ];
    back = NotebookGet[ notebook ];
    NotebookClose[ notebook ];
    <| "Buttons" -> Count[ back, _ButtonBox, Infinity ], "Exported" -> notebookToLaTeX[ back ] === source |>
  ]

$savedSource = "\\documentclass{article}\n\\begin{document}\n\n\\section{S} \\label{sec:a}\n\nSee \\cite{first, second} and Section~\\ref{sec:a} and~\\eqref{eq:a}.\n\n\\begin{equation}\\label{eq:a}\nx^2\n\\end{equation}\n\n\\end{document}\n";

(* ImportDisplayDefects T2: the same save for the styled runs the font commands become. A StyleBox
   with list content would come back split into one run per part with the math cell escaping the
   style — measured, and why a rich run is an inline Cell island instead — so what has to survive
   is the three plain StyleBoxes exactly as written, the island, and the export byte for byte. *)
savedFontRuns[ source_String ] :=
  Module[ { file, notebook, back },
    file = FileNameJoin[ { $TemporaryDirectory, "MathNotebookFontRuns.nb" } ];
    Export[ file, latexToNotebook[ source ], "NB" ];
    notebook = NotebookOpen[ file, Visible -> False ];
    back = NotebookGet[ notebook ];
    NotebookClose[ notebook ];
    <| "StyleBoxes" -> Cases[ back, _StyleBox, Infinity ],
      "Islands" -> Count[ back, Cell[ _TextData, ___, FontSlant -> "Italic", ___ ], Infinity ],
      "Exported" -> notebookToLaTeX[ back ] === source |>
  ]

$fontSavedSource = "\\documentclass{article}\n\\begin{document}\n\nThe \\textbf{light cone}, \\emph{here and now}, an \\textit{upright} word, a \\emph{pairing of degree $n$}.\n\n\\end{document}\n";

(* FirstReadingDefects T3: a compound \cite is one button per key, and each key has to NAVIGATE —
   the old single button's compound ButtonData resolved to no cell, so the click silently did
   nothing. NotebookFind resolves a key against the CellTags exactly as the Citation style's
   NotebookLocate does at click time, and the tag read back off the selection is the proof the right
   entry was reached. Through a real save, so the reopen-split fragments were merged and their
   ButtonNotes — the compound's bytes — survived to export the one command byte for byte. *)
splitCitationFinds[ source_String, bib_String ] :=
  Module[ { file, notebook, found, exported },
    file = FileNameJoin[ { $TemporaryDirectory, "MathNotebookSplitCitation.nb" } ];
    Export[ file, latexToNotebook[ source, bibliographyDatabase[ bib ] ], "NB" ];
    notebook = NotebookOpen[ file, Visible -> False ];
    found = Map[
      Replace[ NotebookFind[ notebook, #, All, CellTags ], {
          $Failed -> None,
          _ :> First @ Flatten @ { CurrentValue[ First @ SelectedCells[ notebook ], CellTags ] } } ] &,
      { "ehlers", "andreka" } ];
    exported = notebookToLaTeX[ NotebookGet[ notebook ] ] === source;
    NotebookClose[ notebook ];
    <| "Found" -> found, "Exported" -> exported |>
  ]

$splitCitationSource = "\\documentclass{article}\n\\begin{document}\n\nProse citing \\cite{ehlers, andreka}.\n\n\\bibliography{refs}\n\n\\end{document}\n";

(* LaTeXPaperImport T7: an environment body that spans cells has to number itself once. The name,
   the number and the QED square come from the style, so every cell of a three-cell theorem would
   carry all three and the next theorem would be 1.4 — and none of that is visible in the kernel or
   in a round trip, because both read the stored source. Only the rendered page shows it. *)

$bodyPaper = "\\documentclass{article}\n\\newtheorem{thm}{Theorem}[section]\n\\begin{document}\n\n\\section{First}\n\n\\begin{thm}\\label{Thm:a}\nA first claim, before the equation:\n\\begin{equation}\\label{Eq:a}\nx^2 + y^2 = z^2\n\\end{equation}\nand a second claim after it.\n\\end{thm}\n\n\\begin{proof}\nFirst step.\n\\begin{equation*}\na + b\n\\end{equation*}\nSecond step.\n\\end{proof}\n\n\\begin{thm}\\label{Thm:b}\nA later claim.\n\\end{thm}\n\nSee Theorem~\\ref{Thm:a}, Theorem~\\ref{Thm:b} and~\\eqref{Eq:a}.\n\n\\end{document}\n";

notebookImageInk[ imported_Notebook ] :=
  Module[ { notebook, file },
    notebook = NotebookPut[ withSheet[ imported, "AMSArticle.nb" ], Visible -> False,
      Background -> White, LightDark -> "Light" ];
    file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookFigureInk.png" } ], notebook,
      ImageResolution -> 72 ];
    NotebookClose[ notebook ];
    inkOf @ Import[ file ]
  ]

(* LaTeXPaperImport T8: LaTeX restarts every list, where the front end's ItemNumbered counter runs on
   until a Section resets it — so two lists in one section would read 1, 2, 3, 4 and the second one
   would be wrong. The reset is a CounterAssignments on the first item of each list, and nothing in
   the kernel or in the round trip can see whether it worked: both read the stored source. Reading the
   resolved counter off the live cells is exact where the rendered page is not — an item's dingbat is
   just "1.", which collides with everything in a PDF's plaintext. An \item[label] prints its label
   instead of the number and consumes no counter, which is why the third value is 0 and not 1. *)

$listPaper = "\\documentclass{article}\n\\begin{document}\n\n\\title{A Title}\n\\author{An Author}\n\\maketitle\n\n\\begin{abstract}\nAn abstract.\n\nA second paragraph of it.\n\\end{abstract}\n\n\\section{First}\n\n\\begin{enumerate}\n\\item First.\n\\item Second.\n\\end{enumerate}\n\nBetween the lists.\n\n\\begin{enumerate}\n\\item[(E)] Labelled.\n\\item Restarted.\n\\end{enumerate}\n\n\\end{document}\n";

listMeasurements[ source_String ] :=
  Module[ { notebook, counters },
    notebook = NotebookPut[ withSheet[ latexToNotebook[ source ], "AMSArticle.nb" ], Visible -> False ];
    counters = Map[ CurrentValue[ #, { "CounterValue", "ItemNumbered" } ] &,
      Cells[ notebook, CellStyle -> "ItemNumbered" ] ];
    NotebookClose[ notebook ];
    <| "Counters" -> counters, "Text" -> importedText @ latexToNotebook[ source ] |>
  ]

(* LaTeXPaperImport T9: the numbering. Every part of this is invisible to the kernel and to the round
   trip — both read the stored source, and the numbering is declared in the preamble, which is carried
   verbatim — so the only place it can be asserted is a live document. The counters are read off the
   cells rather than out of the page for the same reason T8 reads them: "1.1.1" collides with too much
   of a PDF's plaintext to count reliably, and a resolved counter is exact. The page is then read too,
   because the counter says nothing about which counters the dingbat actually prints.
   Four claims at once. A per-subsection definition restarts in the second subsection (1, 2, then 1).
   A lemma sharing the theorem counter numbers with the theorems and not with the definitions. A starred
   environment consumes nothing, so the lemma after the convention is 1.2 and not 1.3 — this is the one
   that was wrong on hodgepaper. And amsart numbers equations within the section, so the equation in the
   second section is (2.1) and not (2). *)

$numberingPaper = "\\documentclass{amsart}\n\\newtheorem{thm}{Theorem}[section]\n\\newtheorem{lem}[thm]{Lemma}\n\\newtheorem{defn}{Definition}[subsection]\n\\newtheorem*{conv}{Convention}\n\\begin{document}\n\n\\section{First}\n\n\\subsection{One}\n\n\\begin{defn}\\label{Def:a}\nA first definition.\n\\end{defn}\n\n\\begin{defn}\nA second definition.\n\\end{defn}\n\n\\begin{thm}\nA theorem.\n\\end{thm}\n\n\\begin{conv}\nA convention.\n\\end{conv}\n\n\\begin{lem}\\label{Lem:a}\nA lemma.\n\\end{lem}\n\n\\begin{equation}\\label{Eq:a}\nx^2\n\\end{equation}\n\n\\subsection{Two}\n\n\\begin{defn}\nA third definition.\n\\end{defn}\n\n\\section{Second}\n\n\\begin{equation}\\label{Eq:b}\ny^2\n\\end{equation}\n\n\\begin{enumerate}[label=(\\alph*)]\n\\item Lettered.\n\\item Also lettered.\n\\end{enumerate}\n\nSee Definition~\\ref{Def:a}, Lemma~\\ref{Lem:a}, \\eqref{Eq:a} and \\eqref{Eq:b}.\n\n\\end{document}\n";

numberingMeasurements[ source_String ] :=
  Module[ { notebook, counters },
    notebook = NotebookPut[ withSheet[ latexToNotebook[ source ], "AMSArticle.nb" ], Visible -> False ];
    counters = <|
      "Definition" -> Map[ CurrentValue[ #, { "CounterValue", "TheoremDefn" } ] &,
        Cells[ notebook, CellStyle -> "Definition" ] ],
      "Theorem" -> Map[ CurrentValue[ #, { "CounterValue", "Theorem" } ] &,
        Join[ Cells[ notebook, CellStyle -> "Theorem" ], Cells[ notebook, CellStyle -> "Lemma" ] ] ],
      "Equation" -> Map[ CurrentValue[ #, { "CounterValue", "DisplayFormulaNumbered" } ] &,
        Cells[ notebook, CellStyle -> "DisplayFormulaNumbered" ] ] |>;
    NotebookClose[ notebook ];
    <| "Counters" -> counters, "Text" -> importedText @ latexToNotebook[ source ] |>
  ]

(* LaTeXPaperImport T11: an imported paper has to open with its environments live, and the sheet is
   the only thing that decides whether it does. On Default.nb the twelve environment styles do not
   exist, so the definition prints no name and no number, the proof prints no name and no QED square,
   the headings print no number — and the reference to the definition reads "2.0", because its
   section counter increments and its theorem counter never does. That is a broken reference on the
   page and it is invisible everywhere else: the kernel, the round trip and the counter values are
   all identical under both sheets. The pair is measured, not just the good half, because the whole
   claim is that the sheet is what fixed it. *)

$plainPaper = "\\documentclass{article}\n\\newtheorem{defn}{Definition}[section]\n\\begin{document}\n\n\\section{First} \\label{sec:one}\n\n\\section{Second} \\label{sec:two}\n\n\\begin{defn} \\label{def:one}\nA body.\n\\end{defn}\n\n\\begin{proof}\nA proof.\n\\end{proof}\n\nSee Section~\\ref{sec:two} and Definition~\\ref{def:one}.\n\n\\end{document}\n";

(* A PDF's plaintext breaks a line wherever the layout does, so every comparison here is against the
   text with its whitespace taken out. *)
sheetText[ source_String, sheet_String ] :=
  Module[ { notebook, file },
    notebook = NotebookPut[ withSheet[ latexToNotebook[ source ], sheet ], Visible -> False ];
    file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookSheet.pdf" } ], notebook ];
    NotebookClose[ notebook ];
    StringDelete[ Import[ file, "Plaintext" ], WhitespaceCharacter ]
  ]

(* ConversionUX T2: a newly converted MaTeX cell has to come out at the size the document is showing
   mathematics at. Nothing kernel-side can see this — the cell round-trips through its stored
   "SourceTeX" whatever size the image was rendered at, and the size arithmetic on its own passes
   while ConvertToMaTeX goes on ignoring it, which is exactly how the bug shipped. What is measured
   is the image: the width of the rendered GraphicsBox, converted under an untouched document and
   under one whose math control is at twice the anchor. The third document converts first and moves
   the slider afterwards, so the two orders can be compared — they now build the cell through the
   same constructor and must land on the same image, where before the conversion always drew at 14.

   Guarded rather than assumed: MaTeX is optional and shells out to pdflatex and Ghostscript, so a
   machine without them gets no tests here rather than failing ones. The configuration written is
   the one InstallMaTeX writes, so a MaTeX that has never been configured still renders. *)

$maTeXAvailable = PacletObjectQ @ Quiet @ PacletObject[ "MaTeX" ] &&
  StringQ @ findExecutable[ "pdflatex" ] && StringQ @ findExecutable[ "gs" ];

If[ ! $maTeXAvailable,
  Print[ "MaTeX, pdflatex or Ghostscript is absent: the MaTeX conversion size tests are not run." ] ];

maTeXDocument[ parent_ ] :=
  NotebookPut[ Notebook[
    { Cell[ BoxData[ FormBox[ SuperscriptBox[ "x", "2" ], TraditionalForm ] ], "DisplayFormula" ] },
    StyleDefinitions -> parent, Visible -> False ] ]

(* EditableMaTeX T1: the size is read off the GraphicsBox wherever the option stands, not off a
   GraphicsBox whose options are its own arguments. The front end **normalizes displayed boxes and only
   displayed boxes**: a graphic written as a cell's content comes back with its options spliced up
   (ImageSize at depth 5), and the same graphic parked in a TemplateBox's association slot comes back
   exactly as the kernel wrote it, options still in a nested list (Key["boxes"], 2, 1). So the old
   pattern GraphicsBox[ ___, ImageSize -> { w_, _ }, ___ ] read 91.4887 before the wrapper and 0 after
   it — three tests reporting a size regression where nothing about the image had changed. *)
maTeXWidth[ notebook_NotebookObject ] :=
  FirstCase[ FirstCase[ NotebookGet[ notebook ], _GraphicsBox, Missing[ "NotFound" ], Infinity ],
    HoldPattern[ ImageSize -> { width_?NumericQ, _ } ] :> width, 0, Infinity ]

(* The LaTeX pair, end to end and through the front end, which is the only place the claim can be
   made: the pure cores say what the tagging rules hold, and only a real render says the image was
   drawn from them. A cell of typed source comes back as a DisplayFormula carrying a picture, and
   the trip back gives the author his own text, spaces and dollars included. *)
typedLaTeXDocument[ parent_ ] :=
  NotebookPut[ Notebook[ { Cell[ "$$ x^2 $$", "Text" ] }, StyleDefinitions -> parent, Visible -> False ] ]

firstCellShape[ notebook_NotebookObject ] :=
  Replace[ NotebookRead @ First @ Cells[ notebook ],
    { Cell[ content_, style_String, ___ ] :> { Replace[ content, { _String -> content, _ :> ! FreeQ[ content, GraphicsBox ] } ], style },
      other_ :> other } ]

maTeXMeasurements[ parent_ ] :=
  Module[ { size = 2 mathFontSizeAnchor[ parent ], base, scaled, rescaled, typed, measurements },
    Needs[ "MaTeX`" ];
    MaTeX`ConfigureMaTeX[ "pdfLaTeX" -> findExecutable[ "pdflatex" ], "Ghostscript" -> findExecutable[ "gs" ] ];
    base = maTeXDocument[ parent ];
    ConvertToMaTeX[ base ];
    scaled = maTeXDocument[ parent ];
    SetMathFontSize[ scaled, size ];
    ConvertToMaTeX[ scaled ];
    rescaled = maTeXDocument[ parent ];
    ConvertToMaTeX[ rescaled ];
    SetMathFontSize[ rescaled, size ];
    typed = typedLaTeXDocument[ parent ];
    ConvertLaTeXToMaTeX[ Cells[ typed ] ];
    measurements = <| "Size" -> maTeXFontSize[ scaled ], "Base" -> maTeXWidth[ base ],
      "Scaled" -> maTeXWidth[ scaled ], "Rescaled" -> maTeXWidth[ rescaled ],
      (* BasicFunctionality T4: the MaTeX round trip through the notebook overloads, which is what the
         palette's two MaTeX buttons reach and what no test drove. A rendered cell IS an image, so the
         detector is the GraphicsBox appearing and then going away again. *)
      "Rendered" -> Count[ NotebookGet[ base ], _GraphicsBox, Infinity ],
      (* EditableMaTeX T1: the picture has to reach the document inside the front end's TeX assistant
         box, with its TeX intact — a NotebookWrite is free to take a box apart, as it does a ButtonBox
         in a TextData, and a kernel test of the constructor cannot see that. *)
      "Editable" -> Count[ NotebookGet[ base ], TemplateBox[ _, "TeXAssistantTemplate", ___ ], Infinity ],
      "EditableTeX" -> FirstCase[ NotebookGet[ base ],
        TemplateBox[ slots_, "TeXAssistantTemplate", ___ ] :> Lookup[ Association @ slots, "input", None ],
        None, Infinity ],
      "Unrendered" -> ( ConvertFromMaTeX[ base ]; Count[ NotebookGet[ base ], _GraphicsBox, Infinity ] ),
      "TypedRendered" -> firstCellShape[ typed ],
      "TypedBack" -> ( ConvertMaTeXToLaTeX[ typed ]; firstCellShape[ typed ] ) |>;
    NotebookClose /@ { base, scaled, rescaled, typed };
    measurements
  ]

(* BasicFunctionality T2: with no document open, every selection-driven entry point did nothing and
   said nothing. InputNotebook[] answers $Failed there — a palette with no paper beside it, which is
   where a new author starts — and SelectedCells[$Failed] then stays unevaluated, so the guard
   written for an empty selection matched neither branch and the Replace handed back its own
   argument. No test in the repo had ever called one of these: they are front-end operations end to
   end, so the kernel-only files cannot reach them, and the failure raises no message, which leaves
   the dialog the author is supposed to see as the only detector.

   A headless UsingFrontEnd has no input notebook, so it reproduces the reported state exactly and
   for free — that is also why these were untestable before the notebook arguments existed, and why
   they now need nothing but a front end. TimeConstrained is not decoration: without the guard,
   TagSelectedCell and InsertCitation reach InputString first, and the run would block rather than
   fail. *)

dialogText[ result_ ] :=
  Replace[ result,
    dialog_NotebookObject :>
      With[ { text = FirstCase[ NotebookGet[ dialog ], s_String /; StringEndsQ[ s, "!" ], None, Infinity ] },
        NotebookClose[ dialog ]; text ] ]

$noDocumentCalls = <|
  "CopyCellReference" -> Hold @ CopyCellReference[],
  "TagSelectedCell" -> Hold @ TagSelectedCell[],
  "InsertCitation" -> Hold @ InsertCitation[],
  "InsertEnvironment" -> Hold @ InsertEnvironment[ "Theorem" ],
  (* the continuation form goes through the same guard, and needs its own entry: it takes Automatic
     where the twelve take a style string, so a wrapper accepting only _String would leave it
     unevaluated — the very shape the guard was written for *)
  "ContinueEnvironment" -> Hold @ InsertEnvironment[ Automatic ],
  "LabelReferences" -> Hold @ LabelReferences[],
  (* T5: the same hole in the seven entry points T2 did not touch, each of which handed $Failed to a
     notebook_NotebookObject overload — or to convertCells — and returned unevaluated with no
     message. Driven and measured that way before the guard went in. ConvertToMaTeX is safe to call
     here without MaTeX installed precisely because the guard now answers before the Needs. *)
  "SetDocumentFontSize" -> Hold @ SetDocumentFontSize[ 20 ],
  "SetMathFontSize" -> Hold @ SetMathFontSize[ 20 ],
  "ResetDocumentView" -> Hold @ ResetDocumentView[],
  "ConvertLaTeXCells" -> Hold @ ConvertLaTeXCells[],
  "ConvertMathCells" -> Hold @ ConvertMathCells[],
  "ConvertToMaTeX" -> Hold @ ConvertToMaTeX[],
  "ConvertFromMaTeX" -> Hold @ ConvertFromMaTeX[],
  (* The LaTeX pair goes through the same guard, and ConvertLaTeXToMaTeX reaches it before its own
     empty-selection dialog: with no document there is no selection to be empty. *)
  "ConvertLaTeXToMaTeX" -> Hold @ ConvertLaTeXToMaTeX[],
  "ConvertMaTeXToLaTeX" -> Hold @ ConvertMaTeXToLaTeX[]
|>;

noDocumentDialogs[ ] :=
  Map[ dialogText @ TimeConstrained[ ReleaseHold[ # ], 30, "TIMEOUT" ] &, $noDocumentCalls ]

(* The other half of the same task: the notebook-argument overloads that make the above possible,
   driven against a live document. The counters are read off the cells for the reason T8 and T9 read
   them there — a dingbat of "1." collides with too much of a page's plaintext — and Proof and
   DisplayFormulaNumbered are in the list because they must NOT consume the theorem counter. *)
referencingDrive[ parent_ ] :=
  Module[ { notebook, cells, inserted, measurements },
    notebook = NotebookPut @ Notebook[ {
      Cell[ "A section", "Section" ],
      Cell[ "A theorem", "Theorem" ],
      Cell[ "Smith, A title", "Reference", CellTags -> "Sm09" ] },
      StyleDefinitions -> parent, Visible -> False ];
    cells = Cells[ notebook ];
    measurements = <| "Unselected" -> dialogText @ CopyCellReference[ notebook ] |>;
    SelectionMove[ cells[[ 2 ]], All, Cell ];
    measurements[ "Copied" ] = dialogText @ CopyCellReference[ notebook ];
    (* The keys and not a button count: the clipboard round trip already splits the ButtonBox into one
       fragment per run (4 here, 6 for a three-counter chain), so a count measures the splitter rather
       than the copy. Every fragment carries the one key, which is what a click needs — and the key is
       the tag the copy generated, this cell having had none: T4's auto-tag from the older drive's side. *)
    measurements[ "Clipboard" ] = DeleteDuplicates @ Cases[ NotebookGet @ ClipboardNotebook[],
      HoldPattern[ ButtonData -> key_ ] :> key, Infinity ];
    TagSelectedCell[ notebook, "Thm:key" ];
    measurements[ "Tagged" ] = CurrentValue[ cells[[ 2 ]], CellTags ];
    LabelReferences[ notebook ];
    measurements[ "Dingbat" ] = FirstCase[ NotebookGet[ notebook ],
      Cell[ _, "Reference", ___, CellDingbat -> Cell[ TextData[ label_String ] ], ___ ] :> label, None, Infinity ];
    SelectionMove[ Last @ Cells[ notebook ], After, Cell ];
    Scan[ InsertEnvironment[ notebook, # ] &, { "Theorem", "Lemma", "Proof", "DisplayFormulaNumbered" } ];
    inserted = Cells[ notebook ];
    measurements[ "Styles" ] = Map[ First @ Flatten @ { CurrentValue[ #, CellStyle ] } &, inserted ];
    measurements[ "Counters" ] = Map[ CurrentValue[ #, { "CounterValue", "Theorem" } ] &,
      Select[ inserted,
        MemberQ[ { "Theorem", "Lemma", "Proof" }, First @ Flatten @ { CurrentValue[ #, CellStyle ] } ] & ] ];
    SelectionMove[ Last @ Cells[ notebook ], After, Cell ];
    InsertCitation[ notebook, "Thm:key" ];
    measurements[ "Citation" ] = FirstCase[ NotebookGet[ notebook ],
      ButtonBox[ boxes_, ___, ButtonData -> "Thm:key", ___ ] :> boxes, None, Infinity ];
    (* T3. The kernel tests cover the surgery; what only a real notebook can show is that the whole
       NotebookGet / rewrite / NotebookPut wrapper lands it — an entry appended to the bibliography
       this notebook already has rather than at the selection, which is sitting on the citation. *)
    InsertReference[ notebook, "Ol09" ];
    measurements[ "Entries" ] = Cases[ NotebookGet[ notebook ],
      Cell[ _, "Reference", options___ ] :> Lookup[ { options }, CellTags ], Infinity ];
    measurements[ "EntryDingbat" ] = FirstCase[ NotebookGet[ notebook ],
      Cell[ _, "Reference", options___ ] /; Lookup[ { options }, CellTags ] === "Ol09" :>
        Lookup[ { options }, CellDingbat ], None, Infinity ];
    NotebookClose[ notebook ];
    measurements
  ]

(* FirstReadingDefects T6: relabelling writes the bibliography's own cells and nothing else. What the
   whole-notebook rewrite it replaced cost is not only time — every CellObject in the document dies
   (measured 174/174 on the causal paper), so anything still holding one is left pointing at a cell
   that no longer exists, where SelectionMove answers Null and does nothing: GoBack's stale-cell state,
   reached without anything having been deleted. So the assertion is LIVENESS and not a timing, which
   would be flaky and would measure this machine. The cleared cell is compared against a Reference cell
   that never carried a label rather than against a hard-coded -24, so the claim is "indistinguishable
   from one that was never labelled" under whatever the sheet declares. *)
labelReferencesDrive[ parent_ ] :=
  Module[ { notebook, cells, measurements },
    notebook = NotebookPut @ Notebook[ {
      Cell[ "Prose citing something.", "Text" ],
      Cell[ "Smith, A title", "Reference", CellTags -> "Sm09" ],
      Cell[ "Jones, a tag since removed", "Reference",
        CellDingbat -> Cell[ TextData[ "[gone]" ] ], ParagraphIndent -> 0 ],
      Cell[ "Brown, never labelled", "Reference" ] },
      StyleDefinitions -> parent, Visible -> False ];
    cells = Cells[ notebook ];
    LabelReferences[ notebook ];
    measurements = <|
      "Survived" -> Map[ MatchQ[ ParentNotebook[ # ], _NotebookObject ] &, cells ],
      "Labelled" -> CurrentValue[ cells[[ 2 ]], CellDingbat ],
      "Indent" -> CurrentValue[ cells[[ 2 ]], ParagraphIndent ],
      "Cleared" -> Options[ cells[[ 3 ]], { CellDingbat, ParagraphIndent } ],
      "Fresh" -> Options[ cells[[ 4 ]], { CellDingbat, ParagraphIndent } ],
      (* Cleared by DELETING the option, not by storing the word Inherited in the cell — measured, and
         it is what makes the two routes leave byte-identical cells. HoldPattern because a bare
         Rule in a Cases pattern is read as a transformation and silently answers {}. *)
      "Stored" -> Cases[ Options @ cells[[ 3 ]],
        HoldPattern[ ( CellDingbat | ParagraphIndent ) -> _ ] ],
      "Prose" -> Cases[ Options @ cells[[ 1 ]], HoldPattern[ CellDingbat -> _ ] ] |>;
    NotebookClose[ notebook ];
    measurements
  ]

(* FirstReadingDefects T4: the copied reference, end to end on an imported paper — the one place the
   defect lived. Two things had to be measured rather than asserted from the code. The number is only
   real on a rendered page: a CounterBox in a single-cell Rasterize reads XXX and one keyed on a
   CellID that matches every cell reads the FIRST cell's counters, which is exactly the reported
   "Theorem 0.0". And the clipboard payload's shape decides the FACE: pasted into prose, a
   Cell[BoxData[...]] island measured 29 px tall against the prose's 19 — T5's wrong-font defect —
   and a bare ButtonBox pasted as its own boxes spelled out as text, so the payload is a TextData
   cell. The paste splits it into one button per run (mergedButtons' shape), so "navigates" is
   asserted as every fragment carrying a ButtonData the notebook can find a cell for. *)

$axiomPaper = "\\documentclass{article}\n\\newtheorem{axiom}{Axiom}[subsection]\n\\begin{document}\n\n\\section{One}\n\n\\subsection{A}\n\n\\subsection{B}\n\n\\subsection{C}\n\nProse here.\n\n\\begin{axiom}\\label{ax:1}\nFirst axiom.\n\\end{axiom}\n\n\\begin{axiom}\\label{ax:2}\nSecond axiom.\n\\end{axiom}\n\n\\begin{axiom}\\label{ax:3}\nThird axiom.\n\\end{axiom}\n\n\\end{document}\n";

copiedReferenceDrive[ source_String, sheet_String ] :=
  Module[ { notebook, prose, target, pasted, file, text, measurements },
    notebook = NotebookPut[ withSheet[ latexToNotebook[ source ], sheet ], Visible -> False ];
    prose = First @ Cells[ notebook, CellStyle -> "Text" ];
    target = Last @ Cells[ notebook, CellStyle -> "Theorem" ];
    (* The defect's own cause, measured before the fix is exercised: an imported cell has no CellID,
       and Cells[CellID -> 0] answers every cell in the document rather than none. *)
    measurements = <| "CellID" -> CurrentValue[ target, CellID ],
      "IDMatches" -> Length @ Cells[ notebook, CellID -> 0 ],
      "Cells" -> Length @ Cells[ notebook ] |>;
    SelectionMove[ target, All, Cell ];
    CopyCellReference[ notebook ];
    SelectionMove[ prose, After, CellContents ];
    FrontEndExecute[ FrontEndToken[ notebook, "Paste" ] ];
    pasted = NotebookRead[ prose ];
    measurements[ "Keys" ] = DeleteDuplicates @ Cases[ pasted, HoldPattern[ ButtonData -> key_ ] :> key, Infinity ];
    measurements[ "Buttons" ] = Count[ pasted, _ButtonBox, Infinity ];
    (* Navigation: every fragment's key resolves to the cell that was copied. A CellID of 0 resolved
       to the document's first cell, which is what made the pasted reference dead. *)
    measurements[ "Targets" ] = Map[ Cells[ notebook, CellTags -> # ] &, measurements[ "Keys" ] ];
    measurements[ "Target" ] = { target };
    measurements[ "Ref" ] = StringCases[ notebookToLaTeX @ NotebookGet[ notebook ], "\\ref{" ~~ Except[ "}" ] .. ~~ "}" ];
    file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookCopiedReference.pdf" } ], notebook ];
    text = StringDelete[ Import[ file, "Plaintext" ], Whitespace ];
    measurements[ "Reads" ] = StringContainsQ[ text, "Prosehere.Axiom1.3.3" ];
    measurements[ "Stale" ] = StringContainsQ[ text, "Theorem0.0" | "XXX" ];
    NotebookClose[ notebook ];
    measurements
  ]

(* The other half of Pavel's call: an untagged cell is tagged rather than refused or prompted for, so
   the control never interrupts — and the tag is what makes the reference exist in the .tex too. *)
autoTagDrive[ parent_ ] :=
  Module[ { notebook, target, measurements },
    notebook = NotebookPut @ Notebook[ {
      Cell[ "A section", "Section" ],
      Cell[ "A theorem", "Theorem" ] }, StyleDefinitions -> parent, Visible -> False ];
    target = Last @ Cells[ notebook ];
    measurements = <| "Before" -> CurrentValue[ target, CellTags ] |>;
    SelectionMove[ target, All, Cell ];
    CopyCellReference[ notebook ];
    measurements[ "After" ] = CurrentValue[ target, CellTags ];
    measurements[ "Key" ] = DeleteDuplicates @ Cases[ NotebookGet @ ClipboardNotebook[ ],
      HoldPattern[ ButtonData -> key_ ] :> key, Infinity ];
    (* A second copy reuses the tag the first one gave rather than adding another. *)
    CopyCellReference[ notebook ];
    measurements[ "Again" ] = CurrentValue[ target, CellTags ];
    NotebookClose[ notebook ];
    measurements
  ]

(* PaletteAndViewUX T2: the math font-size control must reach INLINE mathematics, which it did not —
   an inline island had no style, so there was nothing for an override to be written on and
   SetMathFontSize moved every display formula and left inline mathematics exactly where it was. The
   island is styled "InlineFormula" now, and this measures the wiring end to end rather than the cells
   the control generates: View.wlt asserts those, and the ViewAndReferenceDefects lesson is that such
   assertions pass while the rendered result is wrong.

   Two claims, not one. The inline mathematics must GROW when the control is turned up, and it must
   come back on reset. The prose is measured beside it as a control: the *document* control was not
   touched, so the prose must not move — a run that scaled everything would satisfy a growth test on
   its own. Each is a separate notebook because installing a private stylesheet is a per-document act. *)
inlineMathScaling[ parent_ ] :=
  Module[ { render, prose, inline },
    prose = Cell[ "Some prose with no mathematics in it at all.", "Text" ];
    inline = Cell[ TextData[ {
      Cell[ BoxData[ FormBox[ RowBox[ { "x", "+", "y" } ], TraditionalForm ] ], "InlineFormula" ] } ], "Text" ];
    render = { cell, action } |->
      Module[ { notebook, file, value },
        notebook = NotebookPut[ Notebook[ { cell }, StyleDefinitions -> parent ],
          Visible -> False, Background -> White, LightDark -> "Light" ];
        action[ notebook ];
        file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookInlineInk.png" } ],
          notebook, ImageResolution -> 72 ];
        value = inkOf @ Import[ file ];
        NotebookClose[ notebook ];
        value ];
    <| "InlineBase" -> render[ inline, Null & ],
       "InlineScaled" -> render[ inline, SetMathFontSize[ #, 2 mathFontSizeAnchor[ parent ] ] & ],
       "InlineReset" -> render[ inline,
         ( SetMathFontSize[ #, 2 mathFontSizeAnchor[ parent ] ]; ResetDocumentView[ # ] ) & ],
       (* ResetViewRender T2's reference reading. A reset no longer REMOVES the private sheet — it
          installs a neutral one, every style at its own base size — so what it must return to is that
          neutral state and not the unwrapped document, and the two differ under an embedded parent for
          the reason the next comment gives. Setting the slider to the anchor is the same neutral state
          reached the other way, so this is the comparison that has a claim in it. *)
       "InlineNeutral" -> render[ inline, SetDocumentFontSize[ #, documentFontSizeAnchor[ parent ] ] & ],
       "ProseBase" -> render[ prose, Null & ],
       "ProseScaled" -> render[ prose, SetMathFontSize[ #, 2 mathFontSizeAnchor[ parent ] ] & ] |> ]

(* FirstReadingDefects T5: the confirmed model, measured on the page in all four slider states.

   The measurement is the exported image's WIDTH, and that is not a stylistic choice. A display
   formula's width is exactly linear in its size — "x + y" exports 26, 51, 77 and 103 px at 13, 26, 39
   and 52 pt — so width IS a size reading, where ink is not (it grows about as size^1.5, so an ink
   comparison across two sizes needs a tolerance nobody can justify) and height is not (the enclosing
   text cell's line-height floor holds an island of 6.5 pt to a 14 px line, which is exactly how the
   squared-ratio defect stayed hidden).

   Every state drags the TEXT slider, the base state to the sheet's own size. That is what makes the
   four comparable: with no override at all the export does not crop horizontally, and — the reason
   that matters more — a private sheet's parent here is an embedded notebook, so any style the sheet
   does not itself write falls through to Default.nb. An island's size is its host cell's size times a
   ratio, so a state that leaves Text unwritten cannot be measured at all. Dragging the text slider to
   13 writes every style at its own base size, which is a real state (scale 1, not Automatic) and not a
   contrivance.

   Three claims. Inline mathematics must sit at the sheet's own ratio to DISPLAY mathematics in every
   state — that is the whole of the fix, and it fails in three of the four states under the shipped
   arithmetic (2.19, 6.7 and 2.19 against 1.10). The text slider must carry display mathematics with
   it, which it did not. And an explicit math size must override that rather than compound with it. *)
mathScaleWidths[ parent_ ] :=
  Module[ { width, inline, display, document, math },
    document = documentFontSizeAnchor[ parent ];
    math = mathFontSizeAnchor[ parent ];
    inline = Cell[ TextData[ {
      Cell[ BoxData[ FormBox[ RowBox[ { "x", "+", "y" } ], TraditionalForm ] ], "InlineFormula" ] } ], "Text" ];
    display = Cell[ BoxData[ FormBox[ RowBox[ { "x", "+", "y" } ], TraditionalForm ] ], "DisplayFormula" ];
    width = { cell, text, mathematics } |->
      Module[ { notebook, file, value },
        notebook = NotebookPut[ Notebook[ { cell }, StyleDefinitions -> parent ],
          Visible -> False, Background -> White, LightDark -> "Light" ];
        SetDocumentFontSize[ notebook, text ];
        If[ mathematics =!= Automatic, SetMathFontSize[ notebook, mathematics ] ];
        file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookScale.png" } ],
          notebook, ImageResolution -> 72 ];
        value = First @ ImageDimensions @ Import[ file ];
        NotebookClose[ notebook ];
        value ];
    Map[
      state |-> <| "Display" -> width[ display, First @ state, Last @ state ],
        "Inline" -> width[ inline, First @ state, Last @ state ] |>,
      <| "Base" -> { document, Automatic }, "Text" -> { 2 document, Automatic },
        "Math" -> { 2 document, 3 math }, "Override" -> { 2 document, math } |> ]
  ]

(* ImportDisplayDefects T5: WHERE the reference goes, in the four selection states an author can be in.
   Pavel reported a cross-reference rendering in a different face from the label it points at, and the
   cause is not the stylesheets — measured, the same reference in the same Text cell under the same
   sheet is 406 ink at height 15 as inline TextData, which is the prose face exactly (409/15), and 482
   at height 17 as BoxData, because BoxData renders in the box face. Writing at a cell-bracket
   selection produced exactly that BoxData cell AND destroyed the cell's content, so the wrong font and
   the data loss are one bug. "Prose" is the assertion that matters most: it was False for the bracket
   case and no test anywhere would have noticed.

   A2 is in the list to pin what must NOT change — with the contents genuinely selected, writing over
   them is what every editor does, and a fix that "protected" them there would be wrong. *)
citationPlacement[ parent_ ] :=
  Module[ { measure },
    measure = state |->
      Module[ { notebook, cells, read },
        notebook = NotebookPut @ Notebook[ {
          Cell[ "A theorem.", "Theorem", CellTags -> "Thm:1" ],
          Cell[ "Prose here.", "Text" ] },
          StyleDefinitions -> parent, Visible -> False ];
        cells = Cells[ notebook ];
        Switch[ state,
          "Point", SelectionMove[ Last @ cells, After, CellContents ],
          "Selected", SelectionMove[ Last @ cells, All, CellContents ],
          "Nothing", SelectionMove[ notebook, After, Cell ],
          "Bracket", SelectionMove[ Last @ cells, All, Cell ] ];
        InsertCitation[ notebook, "Thm:1" ];
        read = Map[ NotebookRead, Cells[ notebook ] ];
        NotebookClose[ notebook ];
        <| "Prose" -> Or @@ Map[ ! FreeQ[ #, "Prose here." ] &, read ],
           "Buttons" -> Count[ read, _ButtonBox, Infinity ],
           "BoxData" -> Count[ read, Cell[ _BoxData, ___ ] ],
           "TextData" -> Count[ read, Cell[ _TextData, ___ ] ] |> ];
    AssociationMap[ measure, { "Point", "Selected", "Nothing", "Bracket" } ] ]

(* BasicFunctionality T3: GoBack[] is the same silent no-op one state earlier and from the other
   cause — the unset $LastHyperlinkCell rather than a $Failed notebook — so it is reachable with a
   document open and needs a measurement of its own. Three states, and only the middle one may move a
   selection: nothing followed yet, a live cell, and a cell that has since been deleted. That last
   one is why a CellObject pattern alone is not enough — SelectionMove on a deleted cell answers Null
   and does nothing at all. "Value" is measured before the symbol is assigned here, so a kernel that
   arrives with it already set fails a test rather than passing the "Unset" one for the wrong reason. *)
goBackDrive[ ] :=
  Module[ { notebook, cells, measurements },
    measurements = <| "Value" -> ValueQ[ $LastHyperlinkCell ], "Unset" -> dialogText @ GoBack[] |>;
    notebook = NotebookPut @ Notebook[ { Cell[ "One", "Text" ], Cell[ "Two", "Text" ] }, Visible -> False ];
    cells = Cells[ notebook ];
    SelectionMove[ Last[ cells ], All, Cell ];
    $LastHyperlinkCell = First[ cells ];
    measurements[ "Returned" ] = dialogText @ GoBack[];
    measurements[ "Selected" ] = SelectedCells[ notebook ] === { First[ cells ] };
    NotebookDelete[ First[ cells ] ];
    measurements[ "Stale" ] = dialogText @ GoBack[];
    NotebookClose[ notebook ];
    $LastHyperlinkCell = "First[{}] is what the stylesheet assigns with nothing selected";
    measurements[ "NonCell" ] = dialogText @ GoBack[];
    Clear[ $LastHyperlinkCell ];
    measurements
  ]

(* ImportDisplayDefects T1: an imported entry hangs its BibTeX key as a CellDingbat, and a dingbat
   wider than the Reference margin lands at the window edge, clipped, with the body pushed off the
   margin. The sheets reserve the margin; whether it clears the key depends on the face each sheet
   resolves for Reference, so the invariant is measured — the widest specimen key, rasterized at the
   sheet's own font, against the sheet's own margin. A font or size change that silently outgrows
   the gutter fails here and nowhere else. *)
referenceGutter[ sheet_ ] :=
  Module[ { notebook = CreateDocument[ { }, Visible -> False, StyleDefinitions -> sheet ], values },
    values = <|
      "Margin" -> CurrentValue[ notebook, { StyleDefinitions, "Reference", CellMargins } ][[ 1, 1 ]],
      (* BibliographyDisplay T1 reads its face off this same document rather than opening one of its
         own: the service front end answered $Failed for every measurement after these once six more
         CreateDocuments were added beside them, and every test after that failed with it. *)
      "Face" -> Map[ CurrentValue[ notebook, { StyleDefinitions, "Reference", # } ] &, { FontFamily, FontSize } ],
      "Prose" -> Map[ CurrentValue[ notebook, { StyleDefinitions, "Text", # } ] &, { FontFamily, FontSize } ],
      "Label" -> First @ ImageDimensions @ Rasterize[
        Cell[ TextData[ "[woodhous1973differentiable]" ],
          FontFamily -> CurrentValue[ notebook, { StyleDefinitions, "Reference", FontFamily } ],
          FontSize -> CurrentValue[ notebook, { StyleDefinitions, "Reference", FontSize } ] ],
        Background -> White, LightDark -> "Light" ] |>;
    NotebookClose[ notebook ];
    values
  ]

(* T2: the heading a bibliography starts at prints no number. Only a rendered page can say so — a
   CounterBox reads 0 in a single-cell Rasterize — and the paper needs sections before it, since the
   defect was that CounterIncrements -> { } suppresses the INCREMENT and leaves the sheets' Section
   dingbat printing whatever the counter already holds: "3. References", three sections in. *)
bibliographyHeading[ sheet_ ] :=
  Module[ { notebook, file, text },
    notebook = NotebookPut @ Notebook[ {
        Cell[ "One", "Section" ], Cell[ "Prose one.", "Text" ],
        Cell[ "Two", "Section" ], Cell[ "Prose two.", "Text" ],
        Cell[ "Three", "Section" ], Cell[ "Prose three.", "Text" ] },
      StyleDefinitions -> sheet, LightDark -> "Light", Visible -> False ];
    SelectionMove[ Last @ Cells[ notebook ], After, Cell ];
    InsertReference[ notebook, "smith" ];
    file = Export[ FileNameJoin[ { $TemporaryDirectory, "MathNotebookBibliographyHeading.pdf" } ], notebook ];
    text = StringDelete[ Import[ file, "Plaintext" ], Whitespace ];
    NotebookClose[ notebook ];
    <| "Heading" -> StringContainsQ[ text, "three.References", IgnoreCase -> True ],
      "Numbered" -> StringContainsQ[ text, DigitCharacter ~~ "." ~~ "References", IgnoreCase -> True ] |>
  ]

(* EnvironmentBlocks. The reported defect is a DISPLAY one and so has no kernel measurement: prose
   typed after an equation inside a definition lands 64 pt to the left of the block's own prose,
   because the body sits at the sheet's environment margin and a Text cell at the sheet's Text margin.
   So the assertion is the resolved margin of a real cell against the head's — and against a Text
   cell's, or "they agree" would also pass if the continuation had silently become a Text cell.

   Grouping is measured here too, and it is the reason this is a style and not a CellGroup: writing
   the four cells as a group leaves every one of those margins unchanged. *)
(* The front-matter button, and the ORDER is the assertion. \maketitle prints what the front matter
   declared before it, and the generated preamble hangs \maketitle on the LAST Title/Author/Date cell,
   so an author cell landing after the abstract would typeset a title with no author — which is
   invisible in the notebook and shows only in the compiled PDF. The cursor has to end in the Title,
   which is read back as the selection rather than assumed. *)
frontMatterDrive[ parent_ ] :=
  Module[ { notebook, returned, measurements },
    notebook = NotebookPut @ Notebook[ { Cell[ "Existing prose.", "Text" ] },
      StyleDefinitions -> parent, Visible -> False ];
    returned = InsertFrontMatter[ notebook ];
    measurements = <|
      "Styles" -> Map[ First @ Flatten @ { CurrentValue[ #, CellStyle ] } &, Cells[ notebook ] ],
      "Selected" -> Replace[ SelectedCells[ notebook ],
        { { cell_, ___ } :> First @ Flatten @ { CurrentValue[ cell, CellStyle ] }, _ :> None } ],
      "ReturnedTitle" -> Replace[ returned,
        { cell_CellObject :> First @ Flatten @ { CurrentValue[ cell, CellStyle ] }, other_ :> other } ],
      (* and the block a hand-written notebook exports from it: the three commands in source order *)
      "TeX" -> notebookToLaTeXDocument @ NotebookGet[ notebook ] |>;
    NotebookClose[ notebook ];
    measurements
  ]

continueBlockDrive[ parent_ ] :=
  Module[ { notebook, head, cells, continuation, measurements },
    notebook = NotebookPut @ Notebook[ {
      Cell[ "A graph is a pair", "Definition" ],
      Cell[ "Ordinary prose.", "Text" ] },
      StyleDefinitions -> parent, Visible -> False ];
    head = First @ Cells[ notebook ];
    SelectionMove[ head, All, Cell ];
    InsertEnvironment[ notebook, "DisplayFormula" ];
    InsertEnvironment[ notebook, Automatic ];
    cells = Cells[ notebook ];
    continuation = cells[[ 3 ]];
    measurements = <|
      "Styles" -> Map[ First @ Flatten @ { CurrentValue[ #, CellStyle ] } &, cells ],
      "Margins" -> Map[ AbsoluteCurrentValue[ #, CellMargins ][[ 1, 1 ]] &, cells ],
      (* the number belongs to the head alone: a continuation that incremented would read 2 here *)
      "Counters" -> Map[ CurrentValue[ #, { "CounterValue", "Theorem" } ] &, { head, continuation } ],
      "Dingbats" -> Map[ Head @ AbsoluteCurrentValue[ #, CellDingbat ] &, { head, continuation } ] |>;
    (* the same four cells grouped: CellGroupData carries no typography, which is what rules the
       obvious reading of the request out *)
    SelectionMove[ notebook, All, Notebook ];
    FrontEndTokenExecute[ notebook, "CellGroup" ];
    measurements[ "Grouped" ] = Map[ AbsoluteCurrentValue[ #, CellMargins ][[ 1, 1 ]] &, Cells[ notebook ] ];
    NotebookClose[ notebook ];
    measurements
  ]

(* Proof is the one environment whose style carries a CellFrameLabels, and the QED square belongs to
   whichever cell is now last — left on the old one it would print in the middle of the proof. *)
continueProofDrive[ parent_ ] :=
  Module[ { notebook, head, cells, measurements },
    notebook = NotebookPut @ Notebook[ { Cell[ "Immediate.", "Proof" ] },
      StyleDefinitions -> parent, Visible -> False ];
    head = First @ Cells[ notebook ];
    SelectionMove[ head, All, Cell ];
    InsertEnvironment[ notebook, Automatic ];
    cells = Cells[ notebook ];
    measurements = <|
      "Squares" -> Map[ ! FreeQ[ AbsoluteCurrentValue[ #, CellFrameLabels ], _Cell ] &, cells ] |>;
    NotebookClose[ notebook ];
    measurements
  ]

(* An imported block closes on its LAST cell (T7), so continuing one has to move that \end onto the new
   cell or the author's prose exports after the environment closed — as bare text, silently, with the
   notebook looking right. Only a live notebook can show it: the move is made on cell objects. *)
continueImportedDrive[ source_String ] :=
  Module[ { notebook, definition, measurements },
    notebook = NotebookPut @ Append[ latexToNotebook[ source ], Visible -> False ];
    definition = FirstCase[ Cells[ notebook ],
      cell_ /; First @ Flatten @ { CurrentValue[ cell, CellStyle ] } === "Definition" ];
    SelectionMove[ definition, All, Cell ];
    InsertEnvironment[ notebook, Automatic ];
    NotebookWrite[ notebook, "Carried on." ];
    measurements = <| "Source" -> notebookToLaTeX @ NotebookGet[ notebook ] |>;
    NotebookClose[ notebook ];
    measurements
  ]

$continueImportedSource = "\\documentclass{article}\n\\usepackage{amsthm}\n\\newtheorem{defn}{Definition}\n\\begin{document}\n\n\\begin{defn}\nA body.\n\\end{defn}\n\n\\end{document}\n"

(* Every group below is measured in a front end of ITS OWN, and two facts make that possible that
   are not what this file assumed (FrontEndTestIsolation T1, both measured):

   - UsingFrontEnd does NOT give a new front end. Two sequential blocks in one kernel report the
     IDENTICAL LinkObject, so a second UsingFrontEnd — the obvious fix, and the one this item was
     written to make — isolates exactly nothing.
   - Developer`UninstallFrontEnd[] is the teardown that does. Measured over four rounds the link
     goes 106 -> 109 -> 112 -> 115, each one fresh and each one answering. LinkClose on $FrontEnd is
     NOT that teardown: it leaves the kernel unable to launch another, and the next UsingFrontEnd
     then HANGS forever, with no message, uninterruptible by TimeConstrained because a blocked
     MathLink read does not take an abort. That is the wedge that stopped S1, and the two calls are
     one line apart.

   What the split buys is that a front end killed by one group cannot take the rest of the file with
   it, which is what a single association did: with all 34 entries in one, the service front end died
   somewhere among them.

   Two corrections to that last sentence, both T2 and both measured. A front end that dies is
   RELAUNCHED transparently, so exactly ONE measurement is damaged per death — the one whose export
   was in flight — rather than every measurement after it; the eleven renderers ran correctly on the
   fresh link. And Length @ Notebooks[] therefore answers 1 straight across a death, which is what
   made the death look like a mystery: the only reading that detects one is the LinkObject's own id
   changing, and MathLink`LinkConnectedQ answers False even on a healthy link. Which entry does the
   killing is named at "Default" below. *)
(* T3. A front end that dies takes its measurement's value down with it, and what that value then
   reaches is an assertion expecting a string — so the failure is reported as a CONTENT MISMATCH about
   the paclet, which is exactly what happened to BibliographyHeading and what got it written off twice
   as an environment artifact. The two readings that detect a death are the LinkObject's own id
   changing (T2: Length @ Notebooks[] answers 1 straight across one, and MathLink`LinkConnectedQ
   answers False on a HEALTHY link, so neither detects anything) and a $Failed surfacing in a stored
   value — no measurement in this file records a $Failed legitimately, the one place that could
   (splitCitationFinds) mapping it to None at the source. Either one aborts the whole file with a
   named message, because a corpse is not worth testing and a green-but-for-one run here is not a
   baseline. *)
(* A message string is a StringForm template, so a BACKTICK in it is a slot: quoting the recovery
   shell commands in markdown backticks — as the rest of this repo's prose does — made the message
   demand items 0 and 5 and print StringForm::sfr twice before the real text. No backticks here. *)
frontEndGroup::died = "The service front end did not survive the \"`1`\" measurement group. Link id before/after: `2` -> `3` (a CHANGE is a death; equal ids with a $Failed below means the front end answered but the measurement did not). Measurements carrying $Failed: `4`. Every assertion downstream of this is about a dead front end and NOT about the paclet -- do not read a content mismatch in Tests/FrontEnd.wlt as one, and do not attribute it to machine load without naming the TestID first. Recover with: defaults write com.wolfram.WolframApp ApplePersistenceIgnoreState -bool true ; pkill -9 -f MathematicaServer ; then a trivial UsingFrontEnd[ 1 + 1 ]. See CLAUDE.md, Build & test. Aborting the file rather than testing a corpse.";

frontEndLinkId[ ] :=
  Replace[ Quiet @ First @ $FrontEnd, {
      link_LinkObject :> link[[ 2 ]],
      _ :> Missing[ "NoLink" ] } ]

SetAttributes[ ownFrontEnd, HoldRest ]
ownFrontEnd[ name_String, measurements_ ] :=
  Module[ { before, values, after, damaged },
    (* Both reads have to happen INSIDE the UsingFrontEnd: after the uninstall there is no $FrontEnd
       to read an id off, and the id differing between two GROUPS is the teardown working, not a
       death. *)
    { before, values, after } =
      UsingFrontEnd @ { frontEndLinkId[ ], measurements, frontEndLinkId[ ] };
    Quiet @ Developer`UninstallFrontEnd[ ];
    damaged = Keys @ Select[ values, ! FreeQ[ #, $Failed ] & ];
    If[ before =!= after || damaged =!= { },
      Message[ frontEndGroup::died, name, before, after, damaged ];
      Abort[ ]
    ];
    values
  ]

(* "NoDocument" gets a front end to itself, and the ordering rule that used to carry it dissolves:
   the state it measures is "no document is open", which a fresh front end simply IS. It no longer
   has to be first in anything, and no later measurement can take the state away from it. *)
$measuredDialogs = ownFrontEnd[ "Dialogs", <|
  "NoDocument" -> noDocumentDialogs[ ]
|> ];

(* Live notebooks: everything that drives real cells and reads the resolved style chain without
   rendering a page. A Rasterize of a cell belongs here — it is InlineInk's and ReferenceGutter's
   measurement — because it draws one box and not a document. *)
$measuredLive = ownFrontEnd[ "Live", <|
  "FrontMatter" -> frontMatterDrive @ Get @ FileNameJoin[ { $sheetDirectory, "PlainArticle.nb" } ],
  "ContinueBlock" -> continueBlockDrive @ Get @ FileNameJoin[ { $sheetDirectory, "PlainArticle.nb" } ],
  "ContinueProof" -> continueProofDrive @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "ContinueImported" -> continueImportedDrive[ $continueImportedSource ],
  "GoBack" -> goBackDrive[ ],
  "Referencing" -> referencingDrive @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "Relabel" -> labelReferencesDrive @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "AutoTag" -> autoTagDrive @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "Placement" -> citationPlacement @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "Lists" -> listMeasurements[ $listPaper ],
  "Numbering" -> numberingMeasurements[ $numberingPaper ],
  "Saved" -> savedRoundTrip[ $savedSource ],
  "SplitCitations" -> splitCitationFinds[ $splitCitationSource, $bibliographyBib ],
  "FontRuns" -> savedFontRuns[ $fontSavedSource ],
  "InlineInk" -> AssociationMap[ inlineInk, { "A pair $(V, E)$ here.", "A list $x_1, x_2$ here." } ],
  "LetterInk" -> letterInk[ ],
  "GlyphInk" -> glyphInk[ ],
  "Sheets" -> AssociationMap[ viewMeasurements @ Get @ FileNameJoin[ { $sheetDirectory, # } ] &, $templates ],
  (* This entry is the only one of the 34 whose stylesheet parent is a NAME where every other embeds
     one with Get, and that shape is what kills a page render — but the entry itself is not the
     killer, and T2's single-shot sweep that said it was could not tell a rate from a certainty (T4).
     Measured with a fresh front end per repetition: SetDocumentFontSize + ResetDocumentView +
     NotebookClose on a named-sheet document kills the next whole-notebook Export 4/5 of the time
     (5/5 for a paclet sheet name), against 0/5 for the same sheet embedded with Get, 0/5 for either
     call alone and 0/5 with the document left open — while THIS entry, which makes those same three
     calls, survives 0/6. What immunises it is unexplained; the chain read before the size call is
     the only difference. So the file's problem was never a leak and never a count.
     Do not move a page renderer into this group, and do not read the three-group split as a cost
     ceiling that a tidier file could dissolve — the shape above is present here whatever its rate,
     and the product side of it is Work/Backlog/ResetViewRender.md. *)
  "Default" -> viewMeasurements[ "Default.nb" ],
  "SheetLoaded" -> AssociationMap[
    Module[ { notebook = CreateDocument[ { }, Visible -> False,
        StyleDefinitions -> Get @ FileNameJoin[ { $sheetDirectory, # } ] ], size },
      size = CurrentValue[ notebook, { StyleDefinitions, "Title", FontSize } ];
      NotebookClose[ notebook ];
      size ] &,
    $templates ],
  "ReferenceGutter" -> AssociationMap[
    referenceGutter @ Get @ FileNameJoin[ { $sheetDirectory, # } ] &,
    Join[ $templates, { "ComplexSystems.nb", "PlainArticle.nb" } ] ],
  "Citations" -> citationMeasurements @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "MaTeX" -> If[ $maTeXAvailable, maTeXMeasurements @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ] ]
|> ];

(* The page renderers, and the membership rule is exactly that: a measurement here writes the WHOLE
   notebook to a file — a PDF for anything that has to read the page as text, a raster for anything
   that has to weigh its ink — which is the work the shared front end did not survive.
   BibliographyHeading sits here as an ordinary member: it used to be pinned last, and being last
   only ever decided which measurement discovered the corpse. *)
$measuredRendered = ownFrontEnd[ "Rendered", <|
  "Copied" -> copiedReferenceDrive[ $axiomPaper, "AMSArticle.nb" ],
  "InlineScaling" -> inlineMathScaling @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "MathScale" -> mathScaleWidths @ Get @ FileNameJoin[ { $sheetDirectory, "AMSArticle.nb" } ],
  "Imported" -> importedText[ $importedSource ],
  "PlainSheet" -> AssociationMap[ sheetText[ $plainPaper, # ] &, { "PlainArticle.nb", "Default.nb" } ],
  "Figures" -> figureMeasurements[ $figurePaper ],
  "Body" -> importedText @ latexToNotebook[ $bodyPaper ],
  "Bibliography" -> importedText @ latexToNotebook[ $bibliographySource, bibliographyDatabase[ $bibliographyBib ] ],
  "Entries" -> importedText[ $entrySource ],
  "DisplayInk" -> displayInk[ $displayParagraph ],
  "BibliographyHeading" -> bibliographyHeading @ Get @ FileNameJoin[ { $sheetDirectory, "PlainArticle.nb" } ]
|> ];

(* ResetViewRender T2, and the one measurement in this file whose unit is a RATE. Assigning a bare
   stylesheet NAME onto a document that carries a private sheet left the front end unable to render a
   page once that document was closed — 6/10 to 9/10 across the shipped shape and four candidate
   repairs — so applyViewSettings now makes one assignment and never a name. A single run cannot pin
   that: the old shape wrote the PDF 1/10 to 4/10 of the time, so one observation of success is
   worth nothing.

   Deliberately NOT routed through ownFrontEnd. A death relaunches the front end transparently, so the
   link id changes at each one and the deaths can simply be counted inside one front end — and
   ownFrontEnd's whole job is to ABORT the file on a death, which is the opposite of what is wanted
   where a death is the quantity under test. *)
resetRenderRate[ reps_Integer ] :=
  Module[ { pdf = FileNameJoin[ { $TemporaryDirectory, "MathNotebookResetRender.pdf" } ], body, runs },
    body = { Cell[ "A Paper", "Title" ], Cell[ "Intro", "Section" ], Cell[ "Some prose here.", "Text" ] };
    runs = Table[
      Module[ { before, paper, target, after },
        before = frontEndLinkId[ ];
        paper = CreateDocument[ body, Visible -> False, StyleDefinitions -> "Default.nb" ];
        SetDocumentFontSize[ paper, 20 ];
        ResetDocumentView[ paper ];
        NotebookClose[ paper ];
        Quiet @ DeleteFile[ pdf ];
        target = CreateDocument[ body, Visible -> False ];
        Quiet @ Export[ pdf, target ];
        Quiet @ NotebookClose[ target ];
        after = frontEndLinkId[ ];
        <| "Died" -> ( before =!= after ), "Wrote" -> FileExistsQ[ pdf ] |> ],
      reps ];
    <| "Reps" -> reps,
       "Deaths" -> Count[ runs, KeyValuePattern[ "Died" -> True ] ],
       "Wrote" -> Count[ runs, KeyValuePattern[ "Wrote" -> True ] ] |>
  ];

$measuredResetRender =
  Module[ { value = UsingFrontEnd @ resetRenderRate[ 5 ] },
    Quiet @ Developer`UninstallFrontEnd[ ];
    value ];

VerificationTest[
  $measuredResetRender,
  <| "Reps" -> 5, "Deaths" -> 0, "Wrote" -> 5 |>
]

$measured = Join[ $measuredDialogs, $measuredLive, $measuredRendered ];

(* Nothing below is meaningful unless the template sheets actually loaded: Default.nb sizes Title
   at 45, every MathNotebook template at 26. *)
VerificationTest[
  Union @ Values @ $measured[ "SheetLoaded" ],
  { 26 }
]

(* The widest key must fit the gutter under every sheet, and the width must be a real measurement —
   a Rasterize fault reads 0 and would pass a bare "less than" for the wrong reason. *)
VerificationTest[
  AssociationMap[
    With[ { gutter = $measured[ "ReferenceGutter", # ] },
      100 < gutter[ "Label" ] < gutter[ "Margin" ] ] &,
    Join[ $templates, { "ComplexSystems.nb", "PlainArticle.nb" } ] ],
  AssociationMap[ True &, Join[ $templates, { "ComplexSystems.nb", "PlainArticle.nb" } ] ]
]

(* BibliographyDisplay T1. An entry is set in the document's own prose face under every sheet. The bite
   is PlainArticle: it reached Reference through geometryStyleCell, which emitted a bare
   StyleData["Reference"] and so dropped the base's StyleDefinitions -> StyleData["Text"], leaving the
   sheet to fall through to DEFAULT'S OWN Reference — measured Times 12 against prose of Source Sans
   Pro 15, a bibliography in a face belonging to no part of the document. That face is also why the
   gutter above had to widen: the key measures 190 at it against 173 at the widest template face. The
   screen pair, since ComplexSystems prints its entries at 9 against prose of 10 by the journal's call. *)
VerificationTest[
  Map[ #[ "Face" ] === #[ "Prose" ] &, $measured[ "ReferenceGutter" ] ],
  AssociationMap[ True &, Join[ $templates, { "ComplexSystems.nb", "PlainArticle.nb" } ] ]
]

(* T2. Three sections in, the heading is there and carries no number — the two halves apart, because a
   heading that failed to render at all would also satisfy "no number". *)
VerificationTest[
  { $measured[ "BibliographyHeading", "Heading" ], $measured[ "BibliographyHeading", "Numbered" ] },
  { True, False }
]

(* The reported defect, literally: on every template, Theorem, Proof, Reference, Item and
   ItemNumbered stayed at their base size while Text moved. *)
VerificationTest[
  AssociationMap[
    Complement[ { "Theorem", "Proof", "Reference", "Item", "ItemNumbered" }, $measured[ "Sheets", #, "Prose" ] ] &,
    $templates ],
  AssociationMap[ { } &, $templates ]
]

VerificationTest[ (* Text lands exactly on the requested size, on screen and in print *)
  AssociationMap[ $measured[ "Sheets", #, "Scaled", "Screen", "Text" ] &, $templates ],
  AssociationMap[ 20 &, $templates ]
]

VerificationTest[ (* every prose style moved — screen AND "Printout", or the PDF is unchanged *)
  Union @ Flatten @ Table[
    With[ { m = $measured[ "Sheets", sheet ] },
      Table[ m[ "Scaled", environment, style ] > m[ "Base", environment, style ],
        { environment, { "Screen", "Printout" } }, { style, m[ "Prose" ] } ] ],
    { sheet, $templates } ],
  { True }
]

VerificationTest[ (* reset restores every base size exactly, not approximately *)
  AssociationMap[ $measured[ "Sheets", #, "Restored" ] === $measured[ "Sheets", #, "Base" ] &, $templates ],
  AssociationMap[ True &, $templates ]
]

(* A plain Default.nb document has no theorem environments; the control must still reach the prose
   it does have, and writing cells for absent styles must stay harmless. *)
VerificationTest[
  { $measured[ "Default", "Scaled", "Screen", "Text" ],
    SubsetQ[ $measured[ "Default", "Prose" ], { "Text", "Item", "ItemNumbered" } ],
    Union @ Table[ $measured[ "Default", "Scaled", "Screen", style ] > $measured[ "Default", "Base", "Screen", style ],
      { style, $measured[ "Default", "Prose" ] } ],
    $measured[ "Default", "Restored" ] === $measured[ "Default", "Base" ] },
  { 20, True, { True }, True }
]

(* T3: the style a citation renders from is resolved from the tag through the live notebook. *)
VerificationTest[
  $measured[ "Citations" ],
  <| "sec" -> "Section", "thm" -> "Theorem", "def" -> "Definition",
     "ollivier" -> "Reference", "prose" -> "Text", "absent" -> None |>
]

(* ... so a numbered environment cites by number and everything else keeps the tag. *)
VerificationTest[
  KeyValueMap[ FreeQ[ citationButton[ #1, #2 ], _CounterBox ] &, $measured[ "Citations" ] ],
  { False, False, False, True, True, True }
]

(* BasicFunctionality T2 and T5: the reported defect, literally. With no document open every one of
   the twelve tells the author, where each formerly returned an unevaluated expression and no message.
   Asserted as the whole association so an entry point that stops answering cannot hide behind the
   eleven that still do. *)
VerificationTest[
  $measured[ "NoDocument" ],
  AssociationMap[ "Open a notebook first!" &,
    { "CopyCellReference", "TagSelectedCell", "InsertCitation", "InsertEnvironment",
      "ContinueEnvironment", "LabelReferences",
      "SetDocumentFontSize", "SetMathFontSize", "ResetDocumentView",
      "ConvertLaTeXCells", "ConvertMathCells", "ConvertToMaTeX", "ConvertFromMaTeX",
      "ConvertLaTeXToMaTeX", "ConvertMaTeXToLaTeX" } ]
]

(* EnvironmentBlocks. The reported defect and its repair, as resolved margins of real cells. Under
   PlainArticle a Definition body sits at 130 and a Text cell at 66: the continuation must land on 130
   like the head, and the assertion names the Text cell's 66 in the same list so that a continuation
   which had quietly become a Text cell fails rather than passing an "equal to the head" test. *)
VerificationTest[
  { $measured[ "ContinueBlock", "Styles" ],
    $measured[ "ContinueBlock", "Margins" ],
    $measured[ "ContinueBlock", "Counters" ],
    $measured[ "ContinueBlock", "Dingbats" ] },
  { { "Definition", "DisplayFormula", "Definition", "Text" },
    { 130, 66, 130, 66 },
    { 1, 1 },
    { Cell, Symbol } }
]

(* Grouping the same four cells changes not one of those margins, which is why the block is carried by
   the style and not by a CellGroup — the obvious reading of the request, ruled out by measurement. *)
VerificationTest[
  $measured[ "ContinueBlock", "Grouped" ],
  $measured[ "ContinueBlock", "Margins" ]
]

(* The QED square moves to whichever cell is last, and is gone from the one it was on. *)
VerificationTest[
  $measured[ "ContinueProof", "Squares" ],
  { False, True }
]

(* Continuing an IMPORTED block: the new prose is inside the environment, the \end having moved with
   it. Left where it was, this export would read "\\end{defn}\n\nCarried on." — right in the notebook
   and wrong in the paper. *)
VerificationTest[
  StringContainsQ[ $measured[ "ContinueImported", "Source" ], "Carried on.\n\\end{defn}" ],
  True
]

(* BasicFunctionality T3: the palette's "Go back" before any hyperlink has been followed, which is
   the state the button is in the moment a paper is opened. It answered SelectionMove[
   $LastHyperlinkCell, All, Cell ] with no message; it now says so, and says something different for
   a cell that has since been deleted. The non-cell state is the shape the stylesheet's own
   ButtonFunction writes when it clicks with nothing selected. *)
VerificationTest[
  KeyTake[ $measured[ "GoBack" ], { "Value", "Unset", "Stale", "NonCell" } ],
  <| "Value" -> False, "Unset" -> "Follow a hyperlink first!",
    "Stale" -> "The cell that link was followed from is gone!",
    "NonCell" -> "Follow a hyperlink first!" |>
]

(* And a live cell is still gone back to, so the guard is a guard and not a refusal: the selection
   leaves the last cell and lands on the recorded one. *)
VerificationTest[
  KeyTake[ $measured[ "GoBack" ], { "Returned", "Selected" } ],
  <| "Returned" -> Null, "Selected" -> True |>
]

(* BasicFunctionality T7, and the weakest test in this file on purpose. A link followed with
   "OpenInNewWindow" leaves its target in a window of its own, so GoBack has to raise the source
   notebook or the selection moves out of the author's sight. The raise itself cannot be measured
   here — SelectedNotebook[] answers $Failed whatever is selected, and AbsoluteCurrentValue[ notebook,
   "WindowSelected" ] answers $Failed too, both measured on two visible notebooks — so what is
   asserted is that the call is in the definition, and the effect is Pavel's to confirm on a real
   window. It bites on the call being dropped, which is what it is for; it would not bite on the call
   being wrong. The test above is what keeps it honest: raising must not cost the selection move. *)
VerificationTest[
  FreeQ[ DownValues[ GoBack ], SetSelectedNotebook ],
  False
]

(* With a document, the guard that was always in the source and never reachable now fires — and a
   real selection still succeeds, so the guard is a guard and not a refusal. *)
VerificationTest[
  { $measured[ "Referencing", "Unselected" ], $measured[ "Referencing", "Copied" ],
    $measured[ "Referencing", "Clipboard" ] },
  { "Select a cell!", Null, { "ref:1" } }
]

(* The notebook-argument overloads, driven for the first time: the tag reaches the cell and the
   bibliography entry gets the label its citations read. *)
VerificationTest[
  { $measured[ "Referencing", "Tagged" ], $measured[ "Referencing", "Dingbat" ] },
  { "Thm:key", "[Sm09]" }
]

(* Four environments land in order, and the theorem counter runs 1, 2, 3 across the two theorems and
   the lemma while Proof consumes none of it — it reads the lemma's 3 rather than a 4 of its own. *)
VerificationTest[
  { $measured[ "Referencing", "Styles" ], $measured[ "Referencing", "Counters" ] },
  { { "Section", "Theorem", "Reference", "Theorem", "Lemma", "Proof", "DisplayFormulaNumbered" },
    { 1, 2, 3, 3 } }
]

(* The citation written by the two-argument form resolves against the tag it was given. The boxes
   are read back off a live notebook, which splits the prefix string into runs of its own, so what is
   asserted is the counter chain rather than the whole RowBox. *)
VerificationTest[
  Cases[ $measured[ "Referencing", "Citation" ], _CounterBox, Infinity ],
  { CounterBox[ "Section", "Thm:key" ], CounterBox[ "Theorem", "Thm:key" ] }
]

(* T6. Refreshing the labels leaves every cell of the document alive — the prose and the entries alike,
   the entries included because SetOptions mutates a cell where NotebookPut replaces it. This is the
   whole claim of the rewrite: the old route answered False here for every cell in the notebook, which
   is why a reference clicked after a refresh, and Go back, stopped working. *)
(* The front-matter button lands three cells in the order \maketitle needs, leaves the cursor in the
   Title, and returns that cell. Reading the selection back is the point: "puts the cursor in the
   Title" is the half of the button an author notices and the half no structural check would see. *)
VerificationTest[
  KeyTake[ $measured[ "FrontMatter" ], { "Styles", "Selected", "ReturnedTitle" } ],
  <| "Styles" -> { "Title", "Author", "Abstract", "Text" },
     "Selected" -> "Title", "ReturnedTitle" -> "Title" |>
]

(* And it exports as the three commands in source order, with \maketitle after the author and before
   the abstract — the generated preamble putting it on the last front-matter cell. *)
VerificationTest[
  With[ { tex = $measured[ "FrontMatter", "TeX" ],
      at = ( command |-> First @ First @ StringPosition[ $measured[ "FrontMatter", "TeX" ], command ] ) },
    { StringContainsQ[ tex, "\\documentclass{article}" ],
      at[ "\\title" ] < at[ "\\author" ] < at[ "\\maketitle" ] < at[ "\\begin{abstract}" ] } ],
  { True, True }
]

VerificationTest[
  $measured[ "Relabel", "Survived" ],
  { True, True, True, True }
]

(* The label itself is unchanged by the route: the tagged entry reads as its citations do, hanging its
   own indent, and prose is not given a dingbat. A tag since removed leaves the cell indistinguishable
   from one that was never labelled — and by the option being gone, not set to Inherited. *)
VerificationTest[
  { $measured[ "Relabel", "Labelled" ], $measured[ "Relabel", "Indent" ],
    $measured[ "Relabel", "Cleared" ] === $measured[ "Relabel", "Fresh" ],
    $measured[ "Relabel", "Stored" ], $measured[ "Relabel", "Prose" ] },
  { Cell[ TextData[ "[Sm09]" ] ], 0, True, { }, { } }
]

(* T3, in a live notebook. The entry joins the bibliography at its end rather than landing at the
   selection — which is on the citation cell three cells earlier — and it comes back through
   NotebookPut carrying the dingbat that makes it read as the citation pointing at it. *)
VerificationTest[
  { $measured[ "Referencing", "Entries" ], $measured[ "Referencing", "EntryDingbat" ] },
  { { "Sm09", "Ol09" }, Cell[ TextData[ "[Ol09]" ] ] }
]

(* FirstReadingDefects T4, the defect's cause: an imported cell carries no CellID at all, and a
   CellID of 0 is not "no cell" but EVERY cell — so the retired Dynamic resolved its counters at
   whichever cell came first in the document. This is the measurement that turned a wrong word into
   two independent defects, and it is asserted so a future CellID-keyed button cannot come back. *)
VerificationTest[
  { $measured[ "Copied", "CellID" ],
    $measured[ "Copied", "IDMatches" ] === $measured[ "Copied", "Cells" ] },
  { 0, True }
]

(* The reported reproduction, fixed and measured on the rendered page: the pasted reference to the
   third axiom of the third subsection reads "Axiom 1.3.3" — the cell's own word over the cell's own
   three counters — where the style's spec said "Theorem" over two, and neither the reported
   "Theorem 0.0" nor the front end's XXX is anywhere on the page. *)
VerificationTest[
  { $measured[ "Copied", "Reads" ], $measured[ "Copied", "Stale" ] },
  { True, False }
]

(* And it navigates: the paste splits the button into one fragment per run, every fragment carries
   the one key, and that key resolves to exactly the cell that was copied. *)
VerificationTest[
  { $measured[ "Copied", "Keys" ],
    $measured[ "Copied", "Buttons" ] > 0,
    $measured[ "Copied", "Targets" ] },
  { { "ax:3" }, True, { $measured[ "Copied", "Target" ] } }
]

(* A copied reference is a \ref on export, so it survives the round trip as the cross-reference it
   is rather than as the number it happens to print today. *)
VerificationTest[
  $measured[ "Copied", "Ref" ],
  { "\\ref{ax:3}" }
]

(* Pavel's call (2026-07-29): an untagged cell is tagged automatically rather than prompted for or
   refused, and a second copy reuses that tag rather than accumulating one per click. *)
VerificationTest[
  { $measured[ "AutoTag", "Before" ], $measured[ "AutoTag", "After" ],
    $measured[ "AutoTag", "Again" ], $measured[ "AutoTag", "Key" ] },
  { { }, "ref:1", "ref:1", { "ref:1" } }
]

(* PaletteAndViewUX T2: turning the math control up really does enlarge inline mathematics on the page,
   and reset really does put it back.

   The obvious control — "prose does not move" — is NOT available here and asserting it was wrong:
   measured, prose goes from 1186 ink to 1526 and Text from 13 to 15 under a math-only call. That is the
   embedded-parent trap this repo already records, not the control leaking. The private sheet's parent is
   an embedded notebook, so every style the sheet does not itself override falls through to Default.nb,
   whose Text is 15. It is pinned below rather than worked around, so a future session reads it as the
   trap and not as a bug.

   What isolates the math control is therefore the two RATIOS: inline mathematics must grow by MORE than
   that document-wide perturbation does. No magic threshold, and it is exactly the claim Pavel asked
   for — the inline size follows the math slider and not merely the page. *)
(* One clause of this changed with ResetViewRender T2 and the change is a claim, not an accommodation.
   A reset used to take the private sheet OFF, which is the assignment that left the front end unable
   to render a page; it now installs a NEUTRAL sheet instead — every style restated at its own base
   size. Under a real named sheet the two are indistinguishable, measured: eight styles resolve
   identically to the bare parent on ten runs out of ten. Under the EMBEDDED parent this measurement
   is obliged to use they are not, and for the trap named above rather than for a new reason — an
   unwrapped document lets unoverridden styles fall through to Default.nb (Text 15) where the neutral
   sheet states the sheet's own (13), so "reset returns to the unwrapped base" is no longer the right
   reference. The right one is the same neutral state reached the other way, by dragging the text
   slider to the sheet's own size. *)
VerificationTest[
  { Divide[ $measured[ "InlineScaling", "InlineScaled" ], $measured[ "InlineScaling", "InlineBase" ] ] >
      Divide[ $measured[ "InlineScaling", "ProseScaled" ], $measured[ "InlineScaling", "ProseBase" ] ],
    $measured[ "InlineScaling", "InlineReset" ] === $measured[ "InlineScaling", "InlineNeutral" ],
    $measured[ "InlineScaling", "InlineReset" ] < $measured[ "InlineScaling", "InlineScaled" ],
    $measured[ "InlineScaling", "InlineBase" ] > 0,
    $measured[ "InlineScaling", "ProseScaled" ] > $measured[ "InlineScaling", "ProseBase" ] },
  { True, True, True, True, True }
]

(* FirstReadingDefects T5. The sheet's own ratio is 1.05 and a relative FontSize renders at its square,
   so the wanted proportion of inline to display mathematics is 1.05^2 = 1.1025 — measured 1.077, 1.118,
   1.104 and 1.077 across the four states, the spread being one pixel of quantization at these sizes.
   The tolerance is 10%, which admits every one of those and excludes all three failures of the shipped
   arithmetic by a wide margin. Asserting the ratio rather than the sizes is the point: it is a claim
   about the two kinds of mathematics agreeing, and it holds whatever the sliders are set to. *)
VerificationTest[
  Map[ Abs[ #[ "Inline" ] / #[ "Display" ] / 1.1025 - 1 ] < 0.1 &, $measured[ "MathScale" ] ],
  <| "Base" -> True, "Text" -> True, "Math" -> True, "Override" -> True |>
]

(* The two halves of defect 3's first report, as display facts. Doubling the text slider doubles the
   display formula — it used to leave it exactly where it was, which is what reads as the equations
   having been left behind — and an explicit math size at the anchor puts it back to its base width
   whatever the text slider is doing, so the override is an override and not a second factor. The
   widths are exact rather than compared: "x + y" is 26 px at 13 pt and 51 at 26, the odd pixel being
   the glyph advance and not slack in the claim. *)
VerificationTest[
  Map[ #[ "Display" ] &, $measured[ "MathScale" ] ],
  <| "Base" -> 26, "Text" -> 51, "Math" -> 77, "Override" -> 26 |>
]

(* ImportDisplayDefects T5: the reference lands INSIDE a cell in every state, as inline TextData and
   never as a BoxData cell, and it never costs the cell its content. The bracket case is the one that
   was broken both ways — it destroyed "Prose here." and produced the BoxData cell whose box face is
   what Pavel saw. Exactly one button in every state: a duplicate would mean the insertion point moved
   without the write following it. *)
VerificationTest[
  Map[ #[ "Prose" ] &, $measured[ "Placement" ] ],
  <| "Point" -> True, "Selected" -> False, "Nothing" -> True, "Bracket" -> True |>
]

VerificationTest[
  { Map[ #[ "BoxData" ] &, $measured[ "Placement" ] ],
    Map[ #[ "TextData" ] &, $measured[ "Placement" ] ],
    Map[ #[ "Buttons" ] &, $measured[ "Placement" ] ] },
  { <| "Point" -> 0, "Selected" -> 0, "Nothing" -> 0, "Bracket" -> 0 |>,
    <| "Point" -> 1, "Selected" -> 1, "Nothing" -> 1, "Bracket" -> 1 |>,
    <| "Point" -> 1, "Selected" -> 1, "Nothing" -> 1, "Bracket" -> 1 |> }
]

(* Inline Math Converter Defects T1: a comma-bearing span really renders as mathematics — visible
   ink, and the "$" delimiters gone. Blank < Converted < Literal on every specimen. *)
VerificationTest[
  Map[ #[ "Blank" ] < #[ "Converted" ] < #[ "Literal" ] &, $measured[ "InlineInk" ] ],
  AssociationMap[ True &, { "A pair $(V, E)$ here.", "A list $x_1, x_2$ here." } ]
]

(* T2: the split formula carries ink, and the converted paper carries less than the literal LaTeX
   it replaces — the backslashes, the braces and the two "equation*" are gone. Both papers are
   rendered as notebooks (LaTeXPaperImport T12), so the comparison is between like and like; the
   converted one is three cells against the literal one's single cell and still measures less. *)
VerificationTest[
  { $measured[ "DisplayInk", "Formula" ] > 0,
    $measured[ "DisplayInk", "Starred" ] < $measured[ "DisplayInk", "Literal" ] },
  { True, True }
]

(* ... and "equation*" really is unnumbered on the page: the identical document written with
   "equation" carries strictly more ink, and the equation number is the only difference. *)
VerificationTest[
  $measured[ "DisplayInk", "Starred" ] < $measured[ "DisplayInk", "Unstarred" ],
  True
]

(* T3: no letter of the alphabet renders blank ... *)
VerificationTest[
  $measured[ "LetterInk", "Minimum" ] > 0,
  True
]

(* LaTeXPaperImport T3: the references resolve on the page. "Section~2" and "Definition~2.1" are
   the numbers of the cells the labels landed on, and no reference renders as the front end's XXX. *)
VerificationTest[
  { StringContainsQ[ $measured[ "Imported" ], "Section~2" ],
    StringContainsQ[ $measured[ "Imported" ], "Definition~2.1" ],
    StringContainsQ[ $measured[ "Imported" ], "XXX" ] },
  { True, True, False }
]

(* LaTeXPaperImport T4: the bibliography is on the page, each entry under its own [key] dingbat and
   its TeX accent drawn as the character it prints; the citation in the prose reads as the same
   label, and the \bibliography command itself is nowhere to be seen. *)
VerificationTest[
  { StringContainsQ[ $measured[ "Bibliography" ], "[ehlers] J" ],
    StringContainsQ[ $measured[ "Bibliography" ], "rgen Ehlers, The geometry of free fall, 2012." ],
    StringContainsQ[ $measured[ "Bibliography" ], "[andreka, Theorem~1.1]" ],
    StringContainsQ[ $measured[ "Bibliography" ], "\\bibliography" ],
    StringContainsQ[ $measured[ "Bibliography" ], "XXX" ] },
  { True, True, True, False, False }
]

(* LaTeXPaperImport T10: a thebibliography written into the .tex is on the page as a bibliography —
   each entry under its own [key] dingbat, the citation reading as the same label, and none of the
   markup that produced it left as text. The [Sm09] the source prints instead of a number is
   deliberately not shown: it would make the entry and the citation to it disagree. An entry is prose,
   so what prose carries verbatim it carries verbatim too — the ~ and the \emph are on the page as
   they are everywhere else in an imported paper. *)
VerificationTest[
  { StringContainsQ[ $measured[ "Entries" ], "[smith] A.~Smith" ],
    StringContainsQ[ $measured[ "Entries" ], "[jones] B.~Jones" ],
    StringContainsQ[ $measured[ "Entries" ], "citing [smith]" ],
    StringContainsQ[ $measured[ "Entries" ], "bibitem" | "thebibliography" | "Sm09" ],
    StringContainsQ[ $measured[ "Entries" ], "XXX" ] },
  { True, True, True, False, False }
]

(* ... and the two the kernel has opinions about draw the italic letter, not the constant. *)
VerificationTest[
  With[ { ink = $measured[ "LetterInk" ] },
    { ink[ "E" ] === ink[ "ItalicE" ], ink[ "E" ] =!= ink[ "ExponentialE" ],
      ink[ "I" ] === ink[ "ItalicI" ], ink[ "I" ] =!= ink[ "ImaginaryI" ] } ],
  { True, True, True, True }
]

(* FirstReadingDefects T1: \varnothing draws the empty-set glyph — exactly the ink of \[EmptySet],
   where it used to measure 0 — and in the compound the glyph really reaches the page: strictly
   more ink than the U \[NotEqual] it extends, where the drop left the two measuring the same. *)
VerificationTest[
  With[ { ink = $measured[ "GlyphInk" ] },
    { ink[ "Varnothing" ] > 0, ink[ "Varnothing" ] === ink[ "EmptySet" ],
      ink[ "Compound" ] > ink[ "Relation" ] } ],
  { True, True, True }
]

(* LaTeXPaperImport T5: the captions number themselves on the page, straight through the document as
   article does, and "Figure~2" is the number of the cell the label landed on rather than the front
   end's XXX. An evaluated figure's graphic really lands in the rendered document — strictly more ink
   than the same paper unevaluated — and still exports the source byte for byte, so a live picture
   cannot leak into the .tex. *)
VerificationTest[
  { StringContainsQ[ $measured[ "Figures", "Text" ], "Figure 1. The first picture." ],
    StringContainsQ[ $measured[ "Figures", "Text" ], "Figure 2. The second picture." ],
    StringContainsQ[ $measured[ "Figures", "Text" ], "See Figure~2." ],
    StringContainsQ[ $measured[ "Figures", "Text" ], "XXX" ],
    $measured[ "Figures", "Graphics" ] > 0,
    $measured[ "Figures", "Ink" ],
    $measured[ "Figures", "Exported" ] },
  { True, True, True, False, True, True, True }
]

(* A paper written to disk and opened again still exports its source byte for byte. The front end
   handed back nine buttons where the import made three — one per bracket, comma and key — and every
   one of them would have exported a command of its own. *)
VerificationTest[
  { $measured[ "Saved", "Buttons" ] > 3, $measured[ "Saved", "Exported" ] },
  { True, True }
]

(* FirstReadingDefects T3: each key of the compound citation navigates to its own entry, through a
   real save, and the reopened paper still exports the one \cite{ehlers, andreka} byte for byte —
   the recomposition read off the fragments' merged ButtonNotes, not off the display separators. *)
VerificationTest[
  $measured[ "SplitCitations" ],
  <| "Found" -> { "ehlers", "andreka" }, "Exported" -> True |>
]

(* ImportDisplayDefects T2: the styled runs the font commands became survive that same save. The
   three plain runs come back as the very StyleBoxes the import wrote — the "TextItalic" name that
   tells \textit from \emph included — the math-holding emph as its inline Cell island, and the
   reopened notebook still exports the source byte for byte. *)
VerificationTest[
  $measured[ "FontRuns" ],
  <| "StyleBoxes" -> { StyleBox[ "light cone", FontWeight -> "Bold" ],
      StyleBox[ "here and now", FontSlant -> "Italic" ],
      StyleBox[ "upright", "TextItalic", FontSlant -> "Italic" ] },
    "Islands" -> 1, "Exported" -> True |>
]

(* LaTeXPaperImport T7: a theorem whose body wraps around a display equation is three cells, and the
   page has to show one heading, one number and one equation number for it — and the theorem after
   it has to read 1.2 and not 1.4. The proof beside it is the same claim for the QED square, which
   comes from CellFrameLabels rather than from the dingbat and so needs suppressing separately. *)
VerificationTest[
  { StringCount[ $measured[ "Body" ], "Theorem 1.1." ],
    StringCount[ $measured[ "Body" ], "Theorem 1.2." ],
    StringCount[ $measured[ "Body" ], "Proof." ],
    StringCount[ $measured[ "Body" ], "\[EmptySquare]" ],
    StringContainsQ[ $measured[ "Body" ], "See Theorem~1.1, Theorem~1.2 and~(1)." ],
    StringContainsQ[ $measured[ "Body" ], "XXX" | "\\begin{equation" ] },
  { 1, 1, 1, 1, True, False }
]

(* LaTeXPaperImport T8: the second list restarts. Without the per-list reset these read 1, 2, 2, 3. *)
VerificationTest[
  $measured[ "Lists", "Counters" ],
  { 1, 2, 0, 1 }
]

(* ... and the front matter is on the page: the title and author as their own styles, the abstract
   headed once however many paragraphs it runs to, the [label] of an item drawn instead of a number,
   and no list or front-matter command left as prose. The author is read case-insensitively because
   the Author style is small caps, so the PDF's plaintext of "An Author" is "AN AUTHOR".

   ImportDisplayDefects T3 inverted the \maketitle clause: it used to assert the command was on the
   page (1), and now asserts it is not (0). That is the one assertion in the repo that a carried
   paragraph is really invisible — a cell count says a cell is gone, and only a rendered page says
   nothing was drawn in its place. The count stays in the test rather than becoming a
   StringContainsQ so that a *second* copy appearing would fail it too. *)
VerificationTest[
  { StringContainsQ[ $measured[ "Lists", "Text" ], "A Title" ],
    StringContainsQ[ $measured[ "Lists", "Text" ], "An Author", IgnoreCase -> True ],
    StringCount[ $measured[ "Lists", "Text" ], "Abstract." ],
    StringContainsQ[ $measured[ "Lists", "Text" ], "(E)" ],
    StringContainsQ[ $measured[ "Lists", "Text" ],
      "\\item" | "\\title" | "\\author" | "\\begin{abstract}" | "\\begin{enumerate}" ],
    StringCount[ $measured[ "Lists", "Text" ], "\\maketitle" ],
    StringContainsQ[ $measured[ "Lists", "Text" ], "XXX" ] },
  { True, True, 1, True, False, 0, False }
]

(* LaTeXPaperImport T9: the resolved counters. The definitions restart in the second subsection, the
   lemma numbers with the theorems rather than with the definitions, the starred convention consumes
   nothing so the lemma after it is 2 and not 3, and the equation restarts in the second section. *)
VerificationTest[
  $measured[ "Numbering", "Counters" ],
  <| "Definition" -> { 1, 2, 1 }, "Theorem" -> { 1, 1, 2 }, "Equation" -> { 1, 1 } |>
]

(* ... and what the dingbats print, which no counter value can say. Three counters for a definition
   where the sheets print two, an unnumbered Convention, an equation number carrying its section, an
   enumerate lettered by its label= rather than numbered by the style, and every reference reading its
   target's own number. *)
VerificationTest[
  With[ { text = $measured[ "Numbering", "Text" ] },
    { StringCount[ text, "Definition 1.1.1." ], StringCount[ text, "Definition 1.1.2." ],
      StringCount[ text, "Definition 1.2.1." ],
      StringCount[ text, "Theorem 1.1." ], StringCount[ text, "Lemma 1.2." ],
      StringCount[ text, "Convention." ], StringContainsQ[ text, "Convention 1" ],
      StringCount[ text, "(1.1)" ], StringCount[ text, "(2.1)" ],
      StringContainsQ[ text, "(a) Lettered." ], StringContainsQ[ text, "(b) Also lettered." ],
      StringContainsQ[ text, "See Definition~1.1.1, Lemma~1.2, (1.1) and (2.1)." ],
      StringContainsQ[ text, "XXX" ] } ],
  { 1, 1, 1, 1, 1, 1, False, 2, 2, True, True, True, False }
]

(* LaTeXPaperImport T11: the environments are live on the fifth sheet — the name, the number, the
   QED square and the numbered headings — and the cross-reference reads the definition's own number. *)
VerificationTest[
  Map[ StringContainsQ[ $measured[ "PlainSheet", "PlainArticle.nb" ], # ] &,
    { "Definition2.1.", "Proof.", "\[EmptySquare]", "1.First", "2.Second", "Definition~2.1", "Section~2" } ],
  ConstantArray[ True, 7 ]
]

(* And the same paper on Default.nb, which is what an import landed on before this task: no name, no
   number, no square, no heading number, and a reference that reads 2.0. *)
VerificationTest[
  Map[ StringContainsQ[ $measured[ "PlainSheet", "Default.nb" ], # ] &,
    { "Definition2.1.", "Proof.", "\[EmptySquare]", "1.First", "Definition~2.0" } ],
  { False, False, False, False, True }
]

(* ConversionUX T2: the converted image is wider under a document whose math control is at twice the
   anchor, and it is the same image whether the slider was moved before the conversion or after it.
   Converting at the fixed base size gives 14 for the size and one width for all three. *)
If[ $maTeXAvailable,
VerificationTest[
  With[ { m = $measured[ "MaTeX" ] },
    { m[ "Size" ], m[ "Base" ] > 0, m[ "Scaled" ] > m[ "Base" ], m[ "Scaled" ] === m[ "Rescaled" ] } ],
  { 2 $maTeXBaseFontSize, True, True, True }
]
]

(* BasicFunctionality T4: the two MaTeX palette buttons, driven through the notebook overloads they
   call. A MaTeX cell is an image and native typeset math is not, so the render and the unrender are
   one GraphicsBox appearing and then going away — the only pair of states that tells them apart. *)
If[ $maTeXAvailable,
VerificationTest[
  Lookup[ $measured[ "MaTeX" ], { "Rendered", "Unrendered" } ],
  { 1, 0 }
]
]

(* EditableMaTeX T1: what the author gets is not a bare picture but the front end's own TeX assistant
   box, carrying the TeX it was rendered from — which is what makes the mathematics editable again, and
   what a kernel assertion about the constructor cannot claim about a document. *)
If[ $maTeXAvailable,
VerificationTest[
  Lookup[ $measured[ "MaTeX" ], { "Editable", "EditableTeX" } ],
  { 1, "x^2" }
]
]

(* The LaTeX pair the Selection group gained. A typed Text cell becomes a DisplayFormula carrying an
   image, and comes back as the author's own text — the two spaces and the dollars are the assertion,
   a paraphrase reading "x^2" or "\\[ x^2 \\]" being what a converter that rebuilds the source rather
   than storing it would give. *)
If[ $maTeXAvailable,
VerificationTest[
  Lookup[ $measured[ "MaTeX" ], { "TypedRendered", "TypedBack" } ],
  { { True, "DisplayFormula" }, { "$$ x^2 $$", "Text" } }
]
]
