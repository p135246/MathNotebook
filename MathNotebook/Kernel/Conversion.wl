Package["WolframInstitute`MathNotebook`"]

PackageExport[ConvertLaTeXCells]
PackageExport[ConvertMathCells]

PackageScope["texToBoxes"]
PackageScope["$glyphlessMacros"]
PackageScope["boxesToTeX"]
PackageScope["splitInlineMath"]
PackageScope["splitDisplayMath"]
PackageScope["inlineMathCell"]
PackageScope["inlinePartToTeX"]
PackageScope["$displayDelimiters"]
PackageScope["mergeStrings"]
PackageScope["alignBoxes"]
PackageScope["displayParse"]
PackageScope["displaySource"]
PackageScope["displayBodyBoxes"]
PackageScope["storedSourceTeX"]
PackageScope["storedLaTeXSource"]
PackageScope["maTeXEditedQ"]
PackageScope["cellBoxes"]
PackageScope["retainedCellOptions"]
PackageScope["convertLaTeXNotebook"]
PackageScope["convertMathNotebook"]
PackageScope["mapCells"]
PackageScope["convertLaTeXCell"]
PackageScope["convertMathCell"]
PackageScope["convertCells"]
PackageScope["convertSelectedCells"]
PackageScope["writeCells"]

(* T5: convertCells[ transform, $Failed ] stays unevaluated exactly as the overloads do. *)
ConvertLaTeXCells[] :=
  withInputNotebook[ { notebook } |-> convertCells[ convertLaTeXCell, notebook ] ]

ConvertLaTeXCells[ notebook_NotebookObject ] :=
  NotebookPut[ convertLaTeXNotebook[ NotebookGet[ notebook ] ], notebook ]

ConvertLaTeXCells[ cells : { __CellObject } ] :=
  writeCells[ convertLaTeXCell, cells ]

ConvertMathCells[] :=
  withInputNotebook[ { notebook } |-> convertCells[ convertMathCell, notebook ] ]

ConvertMathCells[ notebook_NotebookObject ] :=
  NotebookPut[ convertMathNotebook[ NotebookGet[ notebook ] ], notebook ]

ConvertMathCells[ cells : { __CellObject } ] :=
  writeCells[ convertMathCell, cells ]

convertLaTeXNotebook[ notebook_Notebook ] :=
  mapCells[ convertLaTeXCell, notebook ]

convertMathNotebook[ notebook_Notebook ] :=
  mapCells[ convertMathCell, notebook ]

convertCells[ cellTransform_, notebook_NotebookObject ] :=
  Replace[ SelectedCells[ notebook ],
    { {} :> NotebookPut[ mapCells[ cellTransform, NotebookGet[ notebook ] ], notebook ],
      cells_List :> writeCells[ cellTransform, cells ] } ]

(* An empty selection converts nothing, where convertCells reads it as the whole notebook. Every
   transform there is keyed on a math style and so leaves prose alone; one keyed on a cell's own
   text is not, and would take the paper with it. *)
convertSelectedCells[ cellTransform_, notebook_NotebookObject ] :=
  Replace[ SelectedCells[ notebook ],
    { {} :> MessageDialog[ "Select a cell first!" ],
      cells_List :> writeCells[ cellTransform, cells ] } ]

writeCells[ cellTransform_, cells_List ] :=
  Scan[ { cell } |-> NotebookWrite[ cell, cellTransform @ NotebookRead[ cell ], All ], cells ]

mapCells[ cellTransform_, Notebook[ cells_List, options___ ] ] :=
  Notebook[ Flatten @ Map[ mapCells[ cellTransform, # ] &, cells ], options ]

mapCells[ cellTransform_, Cell[ CellGroupData[ cells_List, state___ ], options___ ] ] :=
  Cell[ CellGroupData[ Flatten @ Map[ mapCells[ cellTransform, # ] &, cells ], state ], options ]

mapCells[ cellTransform_, cell_Cell ] :=
  cellTransform[ cell ]

(* FirstReadingDefects T1: the box path answers \[Null] — U+F3A0, a named character drawn as
   nothing — for 179 of the 207 \@unicode macros in its own import table, \varnothing among them,
   and inside a RowBox the character is dropped outright, so no pass over the boxes can restore
   it. Each such macro is instead replaced in the TeX before conversion by a braced digit
   sentinel, which survives every box position, and the sentinel is mapped back to the character
   afterwards. The table pairs each macro with its glyph: the import table's own intended
   codepoint where the front end draws it, a hand-chosen standard equivalent where that codepoint
   is itself an unnamed private-use character. texToBoxes routes any fragment naming one of these
   straight to the presentation path — the expression path drops the glyph even when it parses. *)
texToBoxes[ tex_String ] :=
  If[ StringContainsQ[ tex, $glyphlessPattern ],
    presentationBoxes[ tex ],
    Replace[ Quiet @ ToExpression[ tex, TeXForm, HoldComplete ],
      { HoldComplete[ $Failed ] :> presentationBoxes[ tex ],
        held : HoldComplete[ expression_ ] /; FreeQ[ held, HoldPattern[ E ] | HoldPattern[ I ] ] :>
          MakeBoxes[ expression, TraditionalForm ],
        _ :> presentationBoxes[ tex ] } ] ]

presentationBoxes[ tex_String ] :=
  If[ StringContainsQ[ tex, "\\ref" | "\\eqref" | "\\pageref" ],
    $Failed,
    Replace[ Quiet @ Convert`TeX`TeXToBoxes[ glyphSentinelTeX @ tex ],
      { FormBox[ boxes_, TraditionalForm ] :> namedGlyphBoxes @ boxes, _ :> $Failed } ] ]

glyphSentinelTeX[ tex_String ] :=
  StringReplace[ tex,
    $glyphlessPattern :> "{9061" <> ToString @ First @ ToCharacterCode @ $glyphlessMacros[ "$1" ] <> "1609}" ]

namedGlyphBoxes[ boxes_ ] :=
  boxes /. string_String :> RuleCondition @ StringReplace[ string,
    "9061" ~~ Shortest[ digits : DigitCharacter .. ] ~~ "1609" :> FromCharacterCode @ FromDigits @ digits ]

$glyphlessMacros = <|
  "approxeq" -> "\:224a",
  "backepsilon" -> "\:03f6",
  "backprime" -> "\[ReversePrime]",
  "backsim" -> "\:223d",
  "backsimeq" -> "\:22cd",
  "barwedge" -> "\[Nand]",
  "Bbbk" -> "\[DoubleStruckK]",
  "between" -> "\:226c",
  "bigstar" -> "\[FivePointedStar]",
  "blacksquare" -> "\[FilledSquare]",
  "blacktriangle" -> "\[UpPointer]",
  "blacktriangledown" -> "\[DownPointer]",
  "blacktriangleleft" -> "\[FilledLeftTriangle]",
  "blacktriangleright" -> "\[FilledRightTriangle]",
  "boxdot" -> "\:22a1",
  "boxminus" -> "\:229f",
  "boxplus" -> "\:229e",
  "boxtimes" -> "\:22a0",
  "Bumpeq" -> "\[HumpDownHump]",
  "Cap" -> "\:22d2",
  "centerdot" -> "\[CenterDot]",
  "circeq" -> "\:2257",
  "circlearrowleft" -> "\:21ba",
  "circlearrowright" -> "\:21bb",
  "circledast" -> "\:229b",
  "circledcirc" -> "\:229a",
  "circleddash" -> "\:229d",
  "circledS" -> "\:24c8",
  "complement" -> "\:2201",
  "Cup" -> "\:22d3",
  "curlyeqprec" -> "\:22de",
  "curlyeqsucc" -> "\:22df",
  "curlyvee" -> "\:22ce",
  "curlywedge" -> "\:22cf",
  "curvearrowleft" -> "\:21b6",
  "curvearrowright" -> "\:21b7",
  "diagdown" -> "\:2572",
  "diagup" -> "\:2571",
  "divideontimes" -> "\:22c7",
  "doteqdot" -> "\:2251",
  "dotplus" -> "\:2214",
  "doublebarwedge" -> "\:2306",
  "downdownarrows" -> "\:21ca",
  "downharpoonleft" -> "\[LeftDownVector]",
  "downharpoonright" -> "\[RightDownVector]",
  "eqcirc" -> "\:2256",
  "eqsim" -> "\[EqualTilde]",
  "eqslantgtr" -> "\:2a96",
  "eqslantless" -> "\:2a95",
  "eth" -> "\[Eth]",
  "fallingdotseq" -> "\:2252",
  "Finv" -> "\:2132",
  "Game" -> "\:2141",
  "geqq" -> "\[GreaterFullEqual]",
  "geqslant" -> "\[GreaterSlantEqual]",
  "ggg" -> "\:22d9",
  "gnapprox" -> "\:2a8a",
  "gneq" -> "\:2a88",
  "gneqq" -> "\[NotGreaterFullEqual]",
  "gnsim" -> "\:22e7",
  "gtrapprox" -> "\:2a86",
  "gtrdot" -> "\:22d7",
  "gtreqless" -> "\[GreaterEqualLess]",
  "gtreqqless" -> "\:2a8c",
  "gtrless" -> "\[GreaterLess]",
  "gvertneqq" -> "\[NotGreaterFullEqual]",
  "intercal" -> "\:22ba",
  "leftarrowtail" -> "\:21a2",
  "leftleftarrows" -> "\:21c7",
  "leftrightarrows" -> "\[LeftArrowRightArrow]",
  "leftrightharpoons" -> "\[ReverseEquilibrium]",
  "leftrightsquigarrow" -> "\:21ad",
  "leftthreetimes" -> "\:22cb",
  "leqq" -> "\[LessFullEqual]",
  "leqslant" -> "\[LessSlantEqual]",
  "lessapprox" -> "\:2a85",
  "lessdot" -> "\:22d6",
  "lesseqgtr" -> "\[LessEqualGreater]",
  "lesseqqgtr" -> "\:2a8b",
  "lessgtr" -> "\[LessGreater]",
  "Lleftarrow" -> "\:21da",
  "lll" -> "\:22d8",
  "lnapprox" -> "\:2a89",
  "lneq" -> "\:2a87",
  "lneqq" -> "\[NotLessFullEqual]",
  "lnsim" -> "\:22e6",
  "looparrowleft" -> "\:21ab",
  "looparrowright" -> "\:21ac",
  "lozenge" -> "\:25ca",
  "Lsh" -> "\:21b0",
  "ltimes" -> "\:22c9",
  "lvertneqq" -> "\[NotLessFullEqual]",
  "measuredangle" -> "\[MeasuredAngle]",
  "multimap" -> "\:22b8",
  "ncong" -> "\[NotTildeFullEqual]",
  "ngeqq" -> "\[NotGreaterEqual]",
  "ngeqslant" -> "\[NotGreaterEqual]",
  "nleftarrow" -> "\:219a",
  "nLeftarrow" -> "\:21cd",
  "nleftrightarrow" -> "\:21ae",
  "nLeftrightarrow" -> "\:21ce",
  "nleqq" -> "\[NotLessEqual]",
  "nleqslant" -> "\[NotLessEqual]",
  "nmid" -> "\:2224",
  "nparallel" -> "\[NotDoubleVerticalBar]",
  "npreceq" -> "\[NotPrecedesSlantEqual]",
  "nrightarrow" -> "\:219b",
  "nRightarrow" -> "\:21cf",
  "nshortmid" -> "\:2224",
  "nshortparallel" -> "\[NotDoubleVerticalBar]",
  "nsubseteqq" -> "\[NotSubsetEqual]",
  "nsucceq" -> "\[NotSucceedsSlantEqual]",
  "nsupseteqq" -> "\[NotSupersetEqual]",
  "ntriangleleft" -> "\[NotLeftTriangle]",
  "ntrianglelefteq" -> "\[NotLeftTriangleEqual]",
  "ntriangleright" -> "\[NotRightTriangle]",
  "ntrianglerighteq" -> "\[NotRightTriangleEqual]",
  "nvdash" -> "\:22ac",
  "nvDash" -> "\:22ad",
  "nVdash" -> "\:22ae",
  "nVDash" -> "\:22af",
  "pitchfork" -> "\:22d4",
  "precapprox" -> "\:2ab7",
  "preccurlyeq" -> "\[PrecedesSlantEqual]",
  "precnapprox" -> "\:2ab9",
  "precneqq" -> "\:2ab5",
  "precnsim" -> "\[NotPrecedesTilde]",
  "rightarrowtail" -> "\:21a3",
  "rightleftarrows" -> "\[RightArrowLeftArrow]",
  "rightrightarrows" -> "\:21c9",
  "rightsquigarrow" -> "\:219d",
  "rightthreetimes" -> "\:22cc",
  "risingdotseq" -> "\:2253",
  "Rrightarrow" -> "\:21db",
  "Rsh" -> "\:21b1",
  "rtimes" -> "\:22ca",
  "shortmid" -> "\[Divides]",
  "shortparallel" -> "\[DoubleVerticalBar]",
  "smallfrown" -> "\[Cap]",
  "smallsetminus" -> "\[Backslash]",
  "smallsmile" -> "\[Cup]",
  "sphericalangle" -> "\[SphericalAngle]",
  "square" -> "\[EmptySquare]",
  "Subset" -> "\:22d0",
  "subseteqq" -> "\:2ac5",
  "subsetneq" -> "\:228a",
  "subsetneqq" -> "\:2acb",
  "succapprox" -> "\:2ab8",
  "succcurlyeq" -> "\[SucceedsSlantEqual]",
  "succnapprox" -> "\:2aba",
  "succneqq" -> "\:2ab6",
  "succnsim" -> "\[NotSucceedsTilde]",
  "Supset" -> "\:22d1",
  "supseteqq" -> "\:2ac6",
  "supsetneq" -> "\:228b",
  "supsetneqq" -> "\:2acc",
  "thickapprox" -> "\[TildeTilde]",
  "thicksim" -> "\[Tilde]",
  "triangledown" -> "\:25bf",
  "triangleq" -> "\:225c",
  "twoheadleftarrow" -> "\:219e",
  "twoheadrightarrow" -> "\:21a0",
  "upharpoonleft" -> "\[LeftUpVector]",
  "upharpoonright" -> "\[RightUpVector]",
  "upuparrows" -> "\:21c8",
  "varkappa" -> "\[CurlyKappa]",
  "varnothing" -> "\[EmptySet]",
  "varpropto" -> "\[Proportional]",
  "varsubsetneq" -> "\:228a",
  "varsubsetneqq" -> "\:2acb",
  "varsupsetneq" -> "\:228b",
  "varsupsetneqq" -> "\:2acc",
  "vartriangle" -> "\:25b5",
  "vartriangleleft" -> "\:25c1",
  "vartriangleright" -> "\:25b7",
  "vDash" -> "\[DoubleRightTee]",
  "Vdash" -> "\:22a9",
  "veebar" -> "\[Xor]",
  "Vvdash" -> "\:22aa"|>

$glyphlessPattern := $glyphlessPattern =
  RegularExpression[ "\\\\(" <> StringRiffle[ Keys @ $glyphlessMacros, "|" ] <> ")(?![a-zA-Z])" ]

boxesToTeX[ TemplateBox[ association_Association, "TeXAssistantTemplate", ___ ] ] :=
  association[ "input" ]

boxesToTeX[ boxes_ ] :=
  Quiet @ Check[ Convert`TeX`BoxesToTeX[ boxes ], $Failed ]

(* The island carries the style "InlineFormula" so that the math font-size control can reach it: an
   unstyled island has nothing for an override to be written on, which is why SetMathFontSize moved
   every display formula and left inline mathematics where it was (PaletteAndViewUX T2). The style is
   not declared by any MathNotebook sheet and does not need to be — it resolves through the chain from
   front-end resources, as 1.05*Inherited, and that *relativity* is the point: measured, an island in a
   Title cell renders at 1649 ink against 420 in a Text cell, so inline mathematics tracks the cell it
   sits in. The control therefore scales the ratio rather than writing an absolute size, which would
   break that tracking — at an absolute 26 the Title island *shrinks* to 1577. The exporters match
   Cell[ BoxData[ ... ], ___ ], so the added style needs no change there. *)
inlineMathCell[ tex_String ] :=
  Replace[ texToBoxes[ tex ],
    { $Failed -> "$" <> tex <> "$",
      boxes_ :> Cell[ BoxData[ FormBox[ boxes, TraditionalForm ] ], "InlineFormula",
        TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> tex |> |> ] } ]

splitInlineMath[ text_String ] :=
  StringSplit[ text,
    { Shortest[ "$" ~~ tex__ ~~ "$" ] /; StringFreeQ[ tex, "$" ] :> inlineMathCell[ tex ],
      Shortest[ "\\(" ~~ tex__ ~~ "\\)" ] :> inlineMathCell[ tex ] } ]

alignBoxes[ body_String ] :=
  GridBox[
    Map[ { row } |-> Map[ { chunk } |-> Replace[ texToBoxes[ chunk ], $Failed -> chunk ], StringSplit[ row, "&" ] ],
      StringSplit[ body, "\\\\" ] ],
    GridBoxAlignment -> { "Columns" -> { { Right, Left } } } ]

(* The fourth field is the math-mode inner environment the display environment wraps — what MaTeX
   and the front end are given, since the outer environment is the page's business — or None where
   the body is bare mathematics already. The closing brace of each opener keeps the prefixes apart:
   \begin{align} cannot take the first thirteen characters of \begin{alignat}, because the "}" the
   opener demands is an "a" there. alignat and alignedat both carry the column-count argument, so
   the body passes it through unchanged; the native grid strips it (stripGridArgument). *)
$displayDelimiters = {
  { "$$", "$$", False, None },
  { "\\[", "\\]", False, None },
  { "\\begin{equation*}", "\\end{equation*}", False, None },
  { "\\begin{equation}", "\\end{equation}", True, None },
  { "\\begin{align*}", "\\end{align*}", False, "aligned" },
  { "\\begin{align}", "\\end{align}", True, "aligned" },
  { "\\begin{gather*}", "\\end{gather*}", False, "gathered" },
  { "\\begin{gather}", "\\end{gather}", True, "gathered" },
  { "\\begin{multline*}", "\\end{multline*}", False, "multlined" },
  { "\\begin{multline}", "\\end{multline}", True, "multlined" },
  { "\\begin{alignat*}", "\\end{alignat*}", False, "alignedat" },
  { "\\begin{alignat}", "\\end{alignat}", True, "alignedat" },
  { "\\begin{flalign*}", "\\end{flalign*}", False, "aligned" },
  { "\\begin{flalign}", "\\end{flalign}", True, "aligned" } }

displayParse[ trimmed_String ] :=
  First[ StringCases[ trimmed,
    Map[ Apply[ { open, close, numbered, kind } |->
        ( StartOfString ~~ open ~~ Shortest[ body__ ] ~~ close ~~ EndOfString :> { body, numbered, kind } ) ],
      $displayDelimiters ] ],
    $Failed ]

splitDisplayMath[ text_String ] :=
  StringSplit[ text,
    Map[ Apply[ { open, close, numbered, kind } |->
        ( span : ( open ~~ Shortest[ body__ ] ~~ close ) :> displaySpanCell[ span, body, numbered, kind ] ) ],
      $displayDelimiters ] ]

displaySpanCell[ span_String, body_String, numbered_, None ] :=
  Replace[ texToBoxes[ StringTrim[ body ] ],
    { $Failed -> span,
      boxes_ :> displayFormulaCell[ boxes, numbered, span ] } ]

displaySpanCell[ span_String, body_String, numbered_, environment_String ] :=
  displayFormulaCell[ alignBoxes @ stripGridArgument @ StringTrim[ body ], numbered, span ]

(* The LaTeX a display cell is rendered from and whether its source asked for a number: the body
   inside the delimiters where the text carries any, the whole of it where it carries none, so a
   bare fragment is as renderable as a full environment. A multiline environment becomes its
   math-mode inner form — align an aligned, gather a gathered, multline a multlined — which is what
   MaTeX and the front end both draw where the outer environment is the page's business. *)
displaySource[ text_String ] :=
  Replace[ displayParse @ StringTrim[ text ],
    { { body_, numbered_, environment_String } :>
        { "\\begin{" <> environment <> "}\n" <> StringTrim[ body ] <> "\n\\end{" <> environment <> "}", numbered },
      { body_, numbered_, None } :> { StringTrim[ body ], numbered },
      $Failed :> { StringTrim[ text ], False } } ]

$innerEnvironments = { "aligned", "gathered", "multlined", "alignedat" }

(* alignat and alignedat open with the column count; the grid reads rows and columns from the body
   alone, so the argument comes off first. *)
stripGridArgument[ body_String ] :=
  StringReplace[ body, StartOfString ~~ "{" ~~ DigitCharacter .. ~~ "}" -> "", 1 ]

displayBodyBoxes[ tex_String ] :=
  First[ StringCases[ StringTrim[ tex ],
    StartOfString ~~ "\\begin{" ~~ environment : WordCharacter .. ~~ "}" ~~ body__ ~~
        "\\end{" ~~ closing : WordCharacter .. ~~ "}" ~~ EndOfString /;
          environment === closing && MemberQ[ $innerEnvironments, environment ] :>
      alignBoxes @ stripGridArgument @ StringTrim[ body ] ],
    Replace[ texToBoxes[ tex ], $Failed -> tex ] ]

displayFormulaCell[ boxes_, numbered_, sourceTeX_String ] :=
  Cell[ BoxData[ FormBox[ boxes, TraditionalForm ] ],
    If[ TrueQ[ numbered ], "DisplayFormulaNumbered", "DisplayFormula" ],
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> sourceTeX |> |> ]

convertLaTeXCell[ cell : Cell[ text_String, style_String /; StringFreeQ[ style, "Input" | "Code" | "Output" | "Program" | "Message" | "Print" ], options___ ] ] :=
  Replace[
    Replace[ mergeStrings @ splitDisplayMath[ text ],
      { { _String } :> inlineTextCell[ cell, text, style, { options } ],
        parts_List :> MapIndexed[
          { part, position } |-> convertedPartCell[ part, style, If[ position === { 1 }, { options }, { } ] ],
          DeleteCases[ Replace[ parts, chunk_String :> StringTrim[ chunk ], { 1 } ], "" ] ] } ],
    { single_Cell } :> single ]

convertLaTeXCell[ Cell[ TextData[ parts_ ], style_String, options___ ] ] :=
  Cell[ TextData[ Flatten @ Map[ Replace[ part_String :> splitInlineMath[ part ] ], Flatten @ { parts } ] ], style, options ]

convertLaTeXCell[ cell_ ] :=
  cell

inlineTextCell[ cell_Cell, text_String, style_String, options_List ] :=
  If[ StringContainsQ[ text, "$" | "\\(" ],
    Replace[ splitInlineMath[ text ],
      { { _String } :> cell,
        parts_List :> Cell[ TextData[ parts ], style, Sequence @@ options ] } ],
    cell ]

convertedPartCell[ Cell[ content_, displayStyle_String, tagging___ ], _, options_List ] :=
  Cell[ content, displayStyle, tagging, Sequence @@ options ]

convertedPartCell[ text_String, style_String, options_List ] :=
  Replace[ splitInlineMath[ text ],
    { { unchanged_String } :> Cell[ unchanged, style, Sequence @@ options ],
      parts_List :> Cell[ TextData[ parts ], style, Sequence @@ options ] } ]

convertMathCell[ cell : Cell[ _, "DisplayFormula" | "DisplayFormulaNumbered", options___ ] ] :=
  Replace[ displayTeXString[ cell ],
    { $Failed -> cell,
      tex_String :> Cell[ tex, "Text", Sequence @@ retainedCellOptions[ { options } ] ] } ]

convertMathCell[ Cell[ TextData[ parts_ ], style_String, options___ ] ] :=
  Replace[ mergeStrings[ Map[ inlinePartToTeX, Flatten @ { parts } ] ],
    { { text_String } :> Cell[ text, style, options ],
      merged_List :> Cell[ TextData[ merged ], style, options ] } ]

convertMathCell[ cell_ ] :=
  cell

displayTeXString[ cell : Cell[ _, style_String, ___ ] ] :=
  With[ { stored = storedSourceTeX[ cell ] },
    If[ StringQ[ stored ],
      stored,
      Replace[ boxesToTeX @ cellBoxes[ cell ],
        { $Failed -> $Failed,
          tex_String :> If[ style === "DisplayFormulaNumbered",
            "\\begin{equation}\n" <> tex <> "\n\\end{equation}",
            "\\[ " <> tex <> " \\]" ] } ] ]
  ]

inlinePartToTeX[ part : Cell[ BoxData[ FormBox[ boxes_, TraditionalForm ] ], ___ ] ] :=
  Replace[ storedSourceTeX[ part ],
    { tex_String :> "$" <> tex <> "$",
      $Failed :> Replace[ boxesToTeX[ boxes ], { $Failed -> part, tex_String :> "$" <> tex <> "$" } ] } ]

(* The font command is rebuilt from the run itself, not from stored source, so an edit to the
   styled text reaches the .tex. The style name marks \textit; a bare italic — the Format menu's
   own — exports as \emph, the semantic default. Both the StyleBox and the inline-Cell shape of a
   run serialize here, their contents recursing through the same clauses. *)
inlinePartToTeX[ StyleBox[ content_, "TextItalic", ___ ] ] :=
  fontTeX[ "textit", content ]

inlinePartToTeX[ Cell[ TextData[ content_ ], "TextItalic", ___ ] ] :=
  fontTeX[ "textit", content ]

inlinePartToTeX[ StyleBox[ content_, ___, FontWeight -> "Bold", ___ ] ] :=
  fontTeX[ "textbf", content ]

inlinePartToTeX[ Cell[ TextData[ content_ ], ___, FontWeight -> "Bold", ___ ] ] :=
  fontTeX[ "textbf", content ]

inlinePartToTeX[ StyleBox[ content_, ___, FontSlant -> "Italic", ___ ] ] :=
  fontTeX[ "emph", content ]

inlinePartToTeX[ Cell[ TextData[ content_ ], ___, FontSlant -> "Italic", ___ ] ] :=
  fontTeX[ "emph", content ]

inlinePartToTeX[ part_ ] :=
  part

fontTeX[ command_String, content_ ] :=
  "\\" <> command <> "{" <> StringJoin[ inlinePartToTeX /@ Flatten @ { content } ] <> "}"

mergeStrings[ parts_List ] :=
  FixedPoint[ Replace[ { before___, first_String, second_String, after___ } :> { before, first <> second, after } ], parts ]

(* EditableMaTeX T1, Pavel's call: where a cell carries the front end's TeX assistant box, the box's own
   "input" slot is the source of truth and the tagging rule is its mirror — so TeX the author edited in
   the notebook reaches the .tex, the thebibliography side of this repo's who-owns-the-entries split
   rather than the .bib side. Every path that reads a MaTeX cell's TeX goes through here (displayTeXString,
   inlinePartToTeX, mathTeX, laTeXSourceText, resizedMaTeXCell), so the precedence is stated once.
   A cell the author made with Ctrl+4 alone carries the box and no rule, and now exports its TeX too. *)
storedSourceTeX[ cell_ ] :=
  Replace[ maTeXBoxTeX[ cell ], $Failed :> storedTagging[ cell, "SourceTeX" ] ]

(* Kept apart from the TeX a cell is rendered from: a re-render is given the body, and the author's
   own text — delimiters, line breaks and all — is what the trip back to LaTeX gives him. An edit to
   the box invalidates it: the two describe the same mathematics and only one of them was changed, so
   giving back the recorded text would silently discard the edit and re-export the old formula. *)
storedLaTeXSource[ cell_ ] :=
  If[ maTeXEditedQ[ cell ], $Failed, storedTagging[ cell, "LaTeXSource" ] ]

maTeXEditedQ[ cell_ ] :=
  With[ { edited = maTeXBoxTeX[ cell ] },
    StringQ[ edited ] && edited =!= storedTagging[ cell, "SourceTeX" ] ]

storedTagging[ Cell[ ___, TaggingRules -> tagging_, ___ ], key_String ] :=
  Lookup[ Association @ Lookup[ Association @ tagging, "MathNotebook", <||> ], key, $Failed ]

storedTagging[ _, _ ] :=
  $Failed

cellBoxes[ Cell[ BoxData[ FormBox[ boxes_, TraditionalForm ] ], ___ ] ] :=
  boxes

cellBoxes[ Cell[ BoxData[ boxes_ ], ___ ] ] :=
  boxes

retainedCellOptions[ options_List ] :=
  Select[ options, MatchQ[ ( CellID | CellTags | CellLabel ) -> _ ] ]
