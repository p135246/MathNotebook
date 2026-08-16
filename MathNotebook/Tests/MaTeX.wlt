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

(* Every display environment normalizes to its math-mode inner form, argument passed through where
   the environment carries one, and the star only decides the number. *)
VerificationTest[
  Map[ displaySource,
    { "\\begin{gather}a\\\\b\\end{gather}", "\\begin{multline*}a\\\\b\\end{multline*}",
      "\\begin{alignat}{2}a&=b\\end{alignat}", "\\begin{flalign*}a&=b\\end{flalign*}" } ],
  { { "\\begin{gathered}\na\\\\b\n\\end{gathered}", True },
    { "\\begin{multlined}\na\\\\b\n\\end{multlined}", False },
    { "\\begin{alignedat}\n{2}a&=b\n\\end{alignedat}", True },
    { "\\begin{aligned}\na&=b\n\\end{aligned}", False } }
]

VerificationTest[
  mathTeX[ Cell[ "", "DisplayFormulaNumbered",
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "\\begin{gather}a\\\\b\\end{gather}" |> |> ] ],
  "\\begin{gathered}\na\\\\b\n\\end{gathered}"
]

(* The native boxes of a stored inner environment are a grid, the alignedat argument stripped. *)
VerificationTest[
  MatchQ[ displayBodyBoxes[ "\\begin{gathered}\na\\\\b\n\\end{gathered}" ], _GridBox ] &&
    MatchQ[ displayBodyBoxes[ "\\begin{alignedat}\n{2}a&=b\n\\end{alignedat}" ], _GridBox ],
  True
]

(* A prose cell whose islands were rendered through MaTeX comes back as the typed text, islands
   re-wearing their dollars and adjacent strings merged; the prose keeps its style and options. *)
VerificationTest[
  maTeXToLaTeXCell[ Cell[ TextData[ { "Let ", Cell[ "img", "InlineFormula",
      TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True |> |> ],
      " be a square." } ], "Text", CellID -> 3 ] ],
  Cell[ "Let $x^2$ be a square.", "Text", CellID -> 3 ]
]

(* Prose with only native islands is not this conversion's business. *)
VerificationTest[
  maTeXToLaTeXCell[ Cell[ TextData[ { "Let ",
      Cell[ BoxData[ FormBox[ "x", TraditionalForm ] ], "InlineFormula" ], " be." } ], "Text" ] ],
  Cell[ TextData[ { "Let ",
    Cell[ BoxData[ FormBox[ "x", TraditionalForm ] ], "InlineFormula" ], " be." } ], "Text" ]
]

(* An inline MaTeX island returns to a native typeset island with its source preserved. *)
VerificationTest[
  MatchQ[
    fromMaTeXNotebook[ Notebook[ { Cell[ TextData[ { "Let ", Cell[ "img", "InlineFormula",
        TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> "x^2", "MaTeX" -> True |> |> ],
        " be." } ], "Text" ] } ] ],
    Notebook[ { Cell[ TextData[ { "Let ",
      Cell[ BoxData[ FormBox[ SuperscriptBox[ "x", "2" ], TraditionalForm ] ], "InlineFormula", ___ ],
      " be." } ], "Text" ] } ] ],
  True
]
