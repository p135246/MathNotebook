Needs[ "WolframInstitute`MathNotebook`" ]
AppendTo[ $ContextPath, "WolframInstitute`MathNotebook`PackageScope`" ]

VerificationTest[
  FileExistsQ @ findExecutable[ "pdflatex" ],
  True
]

VerificationTest[
  FileExistsQ @ findExecutable[ "gs" ],
  True
]

VerificationTest[
  mathTeX[ Cell[ BoxData[ FormBox[ SuperscriptBox[ "x", "2" ], TraditionalForm ] ], "DisplayFormula" ] ],
  "x^2"
]

VerificationTest[
  mathTeX[ Cell[ "", "DisplayFormulaNumbered",
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "\\begin{align}a&=b\\\\c&=d\\end{align}" |> |> ] ],
  "\\begin{aligned}\na&=b\\\\c&=d\n\\end{aligned}"
]

VerificationTest[
  maTeXCellQ[ Cell[ "", "DisplayFormula",
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x", "MaTeX" -> True |> |> ] ],
  True
]

VerificationTest[
  maTeXCellQ[ Cell[ "plain", "Text" ] ],
  False
]

VerificationTest[
  MatchQ[
    fromMaTeXNotebook[ Notebook[ { Cell[ "rendered", "DisplayFormulaNumbered", CellID -> 7,
      TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True |> |> ] } ] ],
    Notebook[ { Cell[ BoxData[ FormBox[ SuperscriptBox[ "x", "2" ], TraditionalForm ] ], "DisplayFormulaNumbered", CellID -> 7, ___ ] } ] ],
  True
]

(* A cell of typed LaTeX is taken whole: the body inside its delimiters where it has any, all of its
   text where it has none, and the number the source asked for. Both halves of displaySource are
   asserted here because both decide what MaTeX is handed and what style the cell comes out with. *)
VerificationTest[
  Map[ displaySource,
    { "\\frac{a}{b}", "  $$ x^2 $$  ", "\\[ x^2 \\]", "\\begin{equation}E=mc^2\\end{equation}",
      "\\begin{align*}a&=b\\end{align*}" } ],
  { { "\\frac{a}{b}", False }, { "x^2", False }, { "x^2", False }, { "E=mc^2", True },
    { "\\begin{aligned}\na&=b\n\\end{aligned}", False } }
]

(* What was typed comes back byte for byte, delimiters and all \[LongDash] which is the whole reason the
   source is stored beside the body MaTeX is given rather than being recovered from it. *)
VerificationTest[
  maTeXToLaTeXCell[ Cell[ "rendered", "DisplayFormula", CellID -> 4,
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True,
      "LaTeXSource" -> "  $$ x^2 $$  " |> |> ] ],
  Cell[ "  $$ x^2 $$  ", "Text", CellID -> 4 ]
]

(* A cell rendered from typeset mathematics has no source of its own, so it gets the delimiters its
   style implies rather than nothing at all. *)
VerificationTest[
  Map[ maTeXToLaTeXCell,
    { Cell[ "rendered", "DisplayFormulaNumbered",
        TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True |> |> ],
      Cell[ "rendered", "DisplayFormula",
        TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True |> |> ] } ],
  { Cell[ "\\begin{equation}\nx^2\n\\end{equation}", "Text" ], Cell[ "\\[ x^2 \\]", "Text" ] }
]

VerificationTest[
  maTeXToLaTeXCell[ Cell[ "prose", "Text" ] ],
  Cell[ "prose", "Text" ]
]

(* Nothing is rendered that is not an author's prose: an empty cell has no LaTeX in it, and an
   evaluation cell's text is not mathematics. Asserted without MaTeX, so it holds on a machine with
   no TeX distribution \[LongDash] a cell these clauses did not take would call MaTeX`MaTeX and fail here. *)
VerificationTest[
  Map[ laTeXToMaTeXCell[ 14 ], { Cell[ "   ", "Text" ], Cell[ "x^2", "Input" ], Cell[ BoxData[ "x" ], "Text" ] } ],
  { Cell[ "   ", "Text" ], Cell[ "x^2", "Input" ], Cell[ BoxData[ "x" ], "Text" ] }
]

(* EditableMaTeX T1. The picture rides in the front end's TeX assistant box, which is what makes a
   converted cell editable, and the state written is "Boxes" \[LongDash] a kernel-written "Input" draws the
   version panel instead of the mathematics. *)
VerificationTest[
  maTeXBox[ "x^2", GraphicsBox[ "picture" ] ],
  TemplateBox[ <| "boxes" -> GraphicsBox[ "picture" ], "errors" -> { }, "input" -> "x^2",
    "state" -> "Boxes" |>, "TeXAssistantTemplate" ]
]

(* Read through a cell, through a FormBox, and off the box itself; a bare picture has no TeX of its
   own, and neither has prose. The reader is narrow on purpose: a Text cell may hold several inline
   assistant boxes, where "the TeX of this cell" has no one answer. *)
VerificationTest[
  Map[ maTeXBoxTeX,
    { Cell[ BoxData[ maTeXBox[ "x^2", GraphicsBox[ "picture" ] ] ], "DisplayFormula" ],
      Cell[ BoxData[ FormBox[ maTeXBox[ "y_1", GraphicsBox[ "picture" ] ], TraditionalForm ] ], "DisplayFormula" ],
      maTeXBox[ "z", GraphicsBox[ "picture" ] ],
      Cell[ BoxData[ GraphicsBox[ "picture" ] ], "DisplayFormula" ],
      Cell[ "prose", "Text" ] } ],
  { "x^2", "y_1", "z", $Failed, $Failed }
]

(* The box's own TeX wins over the tagging rule, so mathematics edited in the notebook is what the
   exporters see. Every path below reads it through storedSourceTeX, which is where the precedence is
   stated once: the cell's rule still says x^2 and its box says y^3. *)
$editedMaTeXCell = Cell[ BoxData[ maTeXBox[ "y^3", GraphicsBox[ "picture" ] ] ], "DisplayFormula", CellID -> 4,
  TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True,
    "LaTeXSource" -> "  $$ x^2 $$  " |> |> ];

VerificationTest[
  { storedSourceTeX[ $editedMaTeXCell ], maTeXEditedQ[ $editedMaTeXCell ], mathTeX[ $editedMaTeXCell ],
    convertMathCell[ $editedMaTeXCell ] },
  { "y^3", True, "y^3", Cell[ "y^3", "Text", CellID -> 4 ] }
]

(* An edit invalidates the recorded typed source: the two describe the same mathematics and only one of
   them was changed, so giving the author back what he typed before the edit would discard it silently
   \[LongDash] and re-export the old formula. The trip back gives the edited body with the delimiters the style
   implies instead. *)
VerificationTest[
  { storedLaTeXSource[ $editedMaTeXCell ], maTeXToLaTeXCell[ $editedMaTeXCell ] },
  { $Failed, Cell[ "\\[ y^3 \\]", "Text", CellID -> 4 ] }
]

(* Untouched, the box and the rule agree, nothing was edited, and the typed source is still the
   author's own text \[LongDash] delimiters, spacing and all. *)
VerificationTest[
  With[ { cell = Cell[ BoxData[ maTeXBox[ "x^2", GraphicsBox[ "picture" ] ] ], "DisplayFormula", CellID -> 4,
      TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True,
        "LaTeXSource" -> "  $$ x^2 $$  " |> |> ] },
    { maTeXEditedQ[ cell ], storedLaTeXSource[ cell ], maTeXToLaTeXCell[ cell ] } ],
  { False, "  $$ x^2 $$  ", Cell[ "  $$ x^2 $$  ", "Text", CellID -> 4 ] }
]

(* A cell with no box at all \[LongDash] every MaTeX cell written before this shape existed \[LongDash] reads exactly as it
   did: the rule is the only source there is, and nothing about it counts as an edit. *)
VerificationTest[
  With[ { cell = Cell[ "rendered", "DisplayFormula",
      TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True,
        "LaTeXSource" -> "$$ x^2 $$" |> |> ] },
    { maTeXEditedQ[ cell ], storedSourceTeX[ cell ], storedLaTeXSource[ cell ] } ],
  { False, "x^2", "$$ x^2 $$" }
]

(* The trip out of MaTeX rebuilds typeset boxes from the edited TeX and re-mirrors the rule from it,
   so the picture and the rule cannot leave the pair disagreeing. *)
VerificationTest[
  MatchQ[ fromMaTeXNotebook[ Notebook[ { $editedMaTeXCell } ] ],
    Notebook[ { Cell[ BoxData[ FormBox[ SuperscriptBox[ "y", "3" ], TraditionalForm ] ], "DisplayFormula", CellID -> 4,
      TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "y^3" |> |> ] } ] ],
  True
]

VerificationTest[
  StringFreeQ[ userInitFile[], "Documents" ] && StringMatchQ[ userInitFile[], ___ ~~ "Kernel" ~~ $PathnameSeparator ~~ "init.m" ],
  True
]

VerificationTest[
  Head @ Quiet @ ToExpression[ $maTeXPreferences, InputForm, HoldComplete ],
  HoldComplete
]

VerificationTest[
  StringContainsQ[ $maTeXPreferences, "$MaTeXPreamble" ] && StringContainsQ[ $maTeXPreferences, "$useMaTeXQ = False" ],
  True
]
