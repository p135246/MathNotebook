Package["WolframInstitute`MathNotebook`"]

PackageExport[ConvertToMaTeX]
PackageExport[ConvertFromMaTeX]
PackageExport[ConvertLaTeXToMaTeX]
PackageExport[ConvertMaTeXToLaTeX]
PackageExport[InstallMaTeX]
PackageExport[OpenMaTeXPreferences]

PackageScope["findExecutable"]
PackageScope["executableDirectories"]
PackageScope["mathTeX"]
PackageScope["maTeXCellQ"]
PackageScope["maTeXCell"]
PackageScope["maTeXBox"]
PackageScope["maTeXBoxTeX"]
PackageScope["inlineMaTeXCell"]
PackageScope["splitInlineMaTeX"]
PackageScope["laTeXMixedMaTeXCells"]
PackageScope["toMaTeXNotebook"]
PackageScope["fromMaTeXNotebook"]
PackageScope["laTeXToMaTeXCell"]
PackageScope["maTeXToLaTeXCell"]
PackageScope["maTeXToLaTeXNotebook"]
PackageScope["laTeXSourceText"]
PackageScope["userInitFile"]
PackageScope["$maTeXPreferences"]
PackageScope["$maTeXBaseFontSize"]
PackageScope["ensureMaTeX"]

$maTeXBaseFontSize = 14

(* Loading MaTeX is not enough for every environment the delimiter table admits: multlined lives in
   mathtools, which MaTeX's BasePreamble does not carry. Added to the user Preamble once, and only
   when absent, so an author's own preamble survives. *)
ensureMaTeX[] :=
  ( Needs[ "MaTeX`" ];
    With[ { preamble = Lookup[ Options[ MaTeX`MaTeX ], "Preamble", { } ] },
      If[ FreeQ[ preamble, line_String /; StringContainsQ[ line, "mathtools" ] ],
        SetOptions[ MaTeX`MaTeX, "Preamble" -> Append[ preamble, "\\usepackage{mathtools}" ] ] ] ] )

(* A MaTeX cell is an image, so it cannot inherit a style change and has to be rendered at the size
   the document is showing mathematics at right now. That size is maTeXFontSize, the same function
   SetMathFontSize re-renders through — a conversion and a later slider touch therefore agree, where
   converting at the fixed $maTeXBaseFontSize left every new cell at 14 until the slider was moved. *)
ConvertToMaTeX[] :=
  withInputNotebook[ { notebook } |->
    ( ensureMaTeX[]; convertCells[ toMaTeXCell @ maTeXFontSize[ notebook ], notebook ] ) ]

ConvertToMaTeX[ notebook_NotebookObject ] :=
  ( ensureMaTeX[];
    NotebookPut[ toMaTeXNotebook[ NotebookGet[ notebook ], maTeXFontSize[ notebook ] ], notebook ] )

ConvertToMaTeX[ cells : { __CellObject } ] :=
  ( ensureMaTeX[];
    writeCells[ toMaTeXCell @ maTeXFontSize @ ParentNotebook @ First[ cells ], cells ] )

ConvertFromMaTeX[] :=
  withInputNotebook[ { notebook } |-> convertCells[ fromMaTeXCell, notebook ] ]

ConvertFromMaTeX[ notebook_NotebookObject ] :=
  NotebookPut[ fromMaTeXNotebook[ NotebookGet[ notebook ] ], notebook ]

ConvertFromMaTeX[ cells : { __CellObject } ] :=
  writeCells[ fromMaTeXCell, cells ]

(* The other pair's diagonal: the LaTeX an author typed as text, rendered in one step. Where
   ConvertToMaTeX reads a typeset cell, this reads the cell's own string — its display delimiters if
   it carries any, all of it if it carries none — so a cell holding a bare \frac{a}{b} renders as
   readily as one holding $$ ... $$. The source is stored verbatim beside the body MaTeX is given,
   which is what lets the trip back give what was typed rather than a re-delimited paraphrase.

   An empty selection converts nothing here, alone among the conversions in this file: every other
   one touches only cells of a math style, where this one would render every prose cell in the paper. *)
ConvertLaTeXToMaTeX[] :=
  withInputNotebook[ { notebook } |->
    ( ensureMaTeX[]; convertSelectedCells[ laTeXToMaTeXCell @ maTeXFontSize[ notebook ], notebook ] ) ]

ConvertLaTeXToMaTeX[ cells : { __CellObject } ] :=
  ( ensureMaTeX[];
    writeCells[ laTeXToMaTeXCell @ maTeXFontSize @ ParentNotebook @ First[ cells ], cells ] )

ConvertMaTeXToLaTeX[] :=
  withInputNotebook[ { notebook } |-> convertCells[ maTeXToLaTeXCell, notebook ] ]

ConvertMaTeXToLaTeX[ notebook_NotebookObject ] :=
  NotebookPut[ maTeXToLaTeXNotebook[ NotebookGet[ notebook ] ], notebook ]

ConvertMaTeXToLaTeX[ cells : { __CellObject } ] :=
  writeCells[ maTeXToLaTeXCell, cells ]

OpenMaTeXPreferences[] :=
  With[ { file = userInitFile[] },
    If[ ! FileExistsQ[ file ],
      CreateDirectory[ DirectoryName[ file ], CreateIntermediateDirectories -> True ];
      Export[ file, $maTeXPreferences, "Text" ] ];
    NotebookOpen[ file ]
  ]

userInitFile[] :=
  FileNameJoin[ { $UserBaseDirectory, "Kernel", "init.m" } ]

InstallMaTeX[] :=
  (
    If[ ! PacletObjectQ @ Quiet @ PacletObject[ "MaTeX" ],
      Replace[ Quiet @ PacletInstall[ "MaTeX" ], _?FailureQ :> PacletInstall[ latestMaTeXReleaseURL[] ] ] ];
    ensureMaTeX[];
    MaTeX`ConfigureMaTeX[
      "pdfLaTeX" -> findExecutable[ "pdflatex" ],
      "Ghostscript" -> findExecutable[ "gs" ] ]
  )

toMaTeXNotebook[ notebook_Notebook, size_ ] :=
  mapCells[ toMaTeXCell[ size ], notebook ]

fromMaTeXNotebook[ notebook_Notebook ] :=
  mapCells[ fromMaTeXCell, notebook ]

maTeXToLaTeXNotebook[ notebook_Notebook ] :=
  mapCells[ maTeXToLaTeXCell, notebook ]

toMaTeXCell[ size_ ][ cell : Cell[ _, style : "DisplayFormula" | "DisplayFormulaNumbered", options___ ] ] :=
  With[ { tex = mathTeX[ cell ] },
    If[ tex === $Failed, cell, maTeXCell[ tex, style, { options }, size ] ]
  ]

(* Inline mathematics converts island by island: any box island in a prose cell whose TeX can be
   read — its stored source, else its boxes — is re-rendered through MaTeX in text style. Buttons
   and other unreadable islands pass through unchanged, so a citation survives the conversion. *)
toMaTeXCell[ size_ ][ Cell[ TextData[ parts_ ], style_String, options___ ] ] :=
  Cell[ TextData[ Flatten @ Map[ toInlineMaTeXPart[ size ], Flatten @ { parts } ] ], style, options ]

toMaTeXCell[ size_ ][ cell_ ] :=
  cell

toInlineMaTeXPart[ size_ ][ part : Cell[ BoxData[ _ ], ___ ] ] /; FreeQ[ part, _ButtonBox ] :=
  With[ { tex = Replace[ storedSourceTeX[ part ], Except[ _String ] :> boxesToTeX @ cellBoxes[ part ] ] },
    If[ StringQ[ tex ], inlineMaTeXCell[ tex, size ], part ] ]

toInlineMaTeXPart[ _ ][ part_ ] :=
  part

(* The one place a MaTeX cell is built. Converting and re-rendering at a new size differ only in
   where the TeX comes from, and building both here is what keeps them from drifting apart on the
   size — which is exactly how a converted cell came to ignore the document's math size. The fifth
   argument is the author's own source where a cell has one, carried separately from the body MaTeX
   renders because that body is what every later re-render is given. *)
maTeXCell[ tex_String, style_String, options_List, size_ ] :=
  maTeXCell[ tex, style, options, size, None ]

maTeXCell[ tex_String, style_String, options_List, size_, source_ ] :=
  Cell[ BoxData[ maTeXBox[ tex, ToBoxes @ MaTeX`MaTeX[ tex, "DisplayStyle" -> True, FontSize -> size ] ] ], style,
    Sequence @@ retainedCellOptions[ options ],
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> tex, "MaTeX" -> True,
      If[ StringQ[ source ], "LaTeXSource" -> source, Nothing ] |> |> ]

(* EditableMaTeX T1: the picture goes in the front end's own TeX assistant box — the one Ctrl+4 makes —
   which carries the TeX beside it in an "input" slot and is therefore editable, where a bare
   GraphicsBox can only be selected and resized. Clicking it is the front end's business
   (doEnterTeXAssistant in InputAssistant.mx), and the string it hands back goes through
   InputAssistant`TeXStringToBoxes — which is the symbol $maTeXPreferences overrides, so an edit
   re-renders through MaTeX exactly when $useMaTeXQ is set and through the built-in parser otherwise.

   Three measurements hold this up (2026-08-01, 15.0.0). The wrapper is display-transparent: one
   DisplayFormula cell rendered as a whole notebook at 144 dpi, Background -> White and
   LightDark -> "Light", measures {183, 40} px and 1083 ink bare and {183, 40} px and 1083 ink wrapped.
   It survives a file: Export then NotebookOpen/NotebookGet gives back
   Cell[ BoxData[ TemplateBox[ <| four slots |>, "TeXAssistantTemplate" ] ], "DisplayFormula" ] with the
   input string byte-intact — unlike a ButtonBox in a TextData, this box is not split by the reopen.
   And only "Boxes" may be written: a kernel-written "state" -> "Input" falls through
   InputAssistantBoxes' own Which to its pleaseUpgradeBoxes branch and draws the panel "Displaying this
   output requires a more recent version", which reads as a version fault and is not one. *)
maTeXBox[ tex_String, boxes_ ] :=
  TemplateBox[ <| "boxes" -> boxes, "errors" -> { }, "input" -> tex, "state" -> "Boxes" |>,
    "TeXAssistantTemplate" ]

(* The reader is deliberately narrow — the box as a cell's whole content, or the box itself — rather
   than a FirstCase at Infinity: a Text cell may hold several inline assistant boxes, and "the TeX of
   this cell" is then not a question with one answer. Since the inline builder below wraps its islands
   too, that is now the ordinary case rather than a hypothetical: each island is its own Cell, so
   storedSourceTeX reads it through this reader per island and an edited island exports its edit. *)
maTeXBoxTeX[ Cell[ BoxData[ boxes_ ], ___ ] ] :=
  maTeXBoxTeX[ boxes ]

maTeXBoxTeX[ FormBox[ boxes_, _ ] ] :=
  maTeXBoxTeX[ boxes ]

maTeXBoxTeX[ TemplateBox[ slots_, "TeXAssistantTemplate", ___ ] ] :=
  Lookup[ Association @ slots, "input", $Failed ]

maTeXBoxTeX[ _ ] :=
  $Failed

(* The one place an inline MaTeX island is built. "DisplayStyle" -> False is what \( ... \) means:
   textstyle operators and fractions, sized to sit inside a prose line, where the display builder
   above sets a displayed equation. The island carries the same tagging as a display cell, so
   maTeXCellQ, the re-render and the trip back to LaTeX treat both forms through one predicate. *)
inlineMaTeXCell[ tex_String, size_ ] :=
  Cell[ BoxData[ maTeXBox[ tex, ToBoxes @ MaTeX`MaTeX[ tex, "DisplayStyle" -> False, FontSize -> size ] ] ],
    "InlineFormula",
    TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> tex, "MaTeX" -> True |> |> ]

splitInlineMaTeX[ size_ ][ text_String ] :=
  StringSplit[ text,
    { Shortest[ "$" ~~ tex__ ~~ "$" ] /; StringFreeQ[ tex, "$" ] :> inlineMaTeXCell[ tex, size ],
      Shortest[ "\\(" ~~ tex__ ~~ "\\)" ] :> inlineMaTeXCell[ tex, size ] } ]


laTeXToMaTeXCell[ size_ ][ Cell[ TextData[ parts : _String | { __String } ], style_String, options___ ] ] :=
  laTeXToMaTeXCell[ size ][ Cell[ StringJoin @ Flatten @ { parts }, style, options ] ]

laTeXToMaTeXCell[ size_ ][ Cell[ text_String, style_String /; StringFreeQ[ style, "Input" | "Code" | "Output" | "Program" | "Message" | "Print" ], options___ ] ] /; StringTrim[ text ] =!= "" :=
  If[ mixedLaTeXQ[ text ],
    laTeXMixedMaTeXCells[ text, style, { options }, size ],
    Apply[
      { tex, numbered } |-> maTeXCell[ tex, If[ TrueQ[ numbered ], "DisplayFormulaNumbered", "DisplayFormula" ],
        { options }, size, text ],
      displaySource[ text ] ] ]

laTeXToMaTeXCell[ _ ][ cell_ ] :=
  cell

(* A cell that is one display formula — or carries no delimiter at all, a bare \frac{a}{b} — renders
   whole through the branch above. A cell of prose with mathematics inside it renders piecewise. *)
mixedLaTeXQ[ text_String ] :=
  displayParse[ StringTrim[ text ] ] === $Failed &&
    ( StringContainsQ[ text, "$" | "\\(" ] ||
      ! StringFreeQ[ text, Alternatives @@ Cases[ $displayDelimiters[[ All, 1 ]], Except[ "$$" ] ] ] )

(* The MaTeX twin of convertLaTeXCell: display spans become MaTeX display cells of their own, each
   remembering the span as typed, and the chunks between them become prose cells whose $ ... $ and
   \( ... \) runs are inline MaTeX islands. *)
laTeXMixedMaTeXCells[ text_String, style_String, options_List, size_ ] :=
  Replace[
    Replace[ mergeStrings @ splitDisplayMaTeX[ size ][ text ],
      parts_List :> MapIndexed[
        { part, position } |-> maTeXPartCell[ part, style, If[ position === { 1 }, options, { } ], size ],
        DeleteCases[ Replace[ parts, chunk_String :> StringTrim[ chunk ], { 1 } ], "" ] ] ],
    { single_Cell } :> single ]

splitDisplayMaTeX[ size_ ][ text_String ] :=
  StringSplit[ text,
    Map[ Apply[ { open, close, numbered, environment } |->
        ( span : ( open ~~ Shortest[ body__ ] ~~ close ) :> maTeXDisplaySpan[ span, size ] ) ],
      $displayDelimiters ] ]

maTeXDisplaySpan[ span_String, size_ ] :=
  Apply[
    { tex, numbered } |-> maTeXCell[ tex,
      If[ TrueQ[ numbered ], "DisplayFormulaNumbered", "DisplayFormula" ], { }, size, span ],
    displaySource @ StringTrim[ span ] ]

maTeXPartCell[ part_Cell, _, options_List, _ ] :=
  Replace[ part, Cell[ content_, partStyle_String, tagging___ ] :> Cell[ content, partStyle, tagging, Sequence @@ options ] ]

maTeXPartCell[ chunk_String, style_String, options_List, size_ ] :=
  Replace[ splitInlineMaTeX[ size ][ chunk ],
    { { unchanged_String } :> Cell[ unchanged, style, Sequence @@ options ],
      parts_List :> Cell[ TextData[ parts ], style, Sequence @@ options ] } ]

maTeXToLaTeXCell[ cell : Cell[ _, style_String, options___ ] ] /; maTeXCellQ[ cell ] :=
  With[ { text = laTeXSourceText[ cell, style ] },
    If[ StringQ[ text ], Cell[ text, "Text", Sequence @@ retainedCellOptions[ { options } ] ], cell ] ]

(* A prose cell whose islands were rendered through MaTeX comes back as typed text: each island's
   stored source re-wears its dollars, native islands and font runs serialize as in ConvertMath, and
   adjacent strings merge — so a ConvertLaTeXToMaTeX followed by this returns the text as typed, up
   to \( ... \) coming back as $ ... $. Prose with only native islands is left to ConvertMath. *)
maTeXToLaTeXCell[ Cell[ TextData[ parts_ ], style_String, options___ ] ] /;
    ! FreeQ[ { parts }, part_Cell /; maTeXCellQ[ part ] ] :=
  Replace[ mergeStrings @ Map[ maTeXInlinePartToTeX, Flatten @ { parts } ],
    { { text_String } :> Cell[ text, style, options ],
      merged_List :> Cell[ TextData[ merged ], style, options ] } ]

maTeXToLaTeXCell[ cell_ ] :=
  cell

maTeXInlinePartToTeX[ part_Cell /; maTeXCellQ[ part ] ] :=
  Replace[ storedSourceTeX[ part ], { tex_String :> "$" <> tex <> "$", _ :> part } ]

maTeXInlinePartToTeX[ part_ ] :=
  inlinePartToTeX[ part ]

(* What was typed, where the cell was made from typed LaTeX; the stored body wearing the delimiters
   its style implies, where it was made from typeset mathematics instead and has no source of its own. *)
laTeXSourceText[ cell_Cell, style_String ] :=
  Replace[ storedLaTeXSource[ cell ],
    Except[ _String ] :> Replace[ storedSourceTeX[ cell ], tex_String :> delimitedTeX[ tex, style ] ] ]

delimitedTeX[ tex_String, "DisplayFormulaNumbered" ] :=
  "\\begin{equation}\n" <> tex <> "\n\\end{equation}"

delimitedTeX[ tex_String, _String ] :=
  "\\[ " <> tex <> " \\]"

fromMaTeXCell[ cell : Cell[ _, style_String, options___ ] ] /; maTeXCellQ[ cell ] :=
  With[ { tex = storedSourceTeX[ cell ] },
    Cell[ BoxData[ FormBox[ displayBodyBoxes[ tex ], TraditionalForm ] ], style,
      Sequence @@ retainedCellOptions[ { options } ],
      TaggingRules -> <| "MathNotebook" -> <| "SourceTeX" -> tex |> |> ]
  ]

(* MaTeX islands in prose return to native typeset islands, source preserved, so the built-in math
   size control reaches them again. *)
fromMaTeXCell[ Cell[ TextData[ parts_ ], style_String, options___ ] ] /;
    ! FreeQ[ { parts }, part_Cell /; maTeXCellQ[ part ] ] :=
  Cell[ TextData[ Flatten @ Map[ fromInlineMaTeXPart, Flatten @ { parts } ] ], style, options ]

fromMaTeXCell[ cell_ ] :=
  cell

fromInlineMaTeXPart[ part_Cell /; maTeXCellQ[ part ] ] :=
  Replace[ storedSourceTeX[ part ], { tex_String :> inlineMathCell[ tex ], _ :> part } ]

fromInlineMaTeXPart[ part_ ] :=
  part

maTeXCellQ[ Cell[ ___, TaggingRules -> tagging_, ___ ] ] :=
  TrueQ @ Lookup[ Association @ Lookup[ Association @ tagging, "MathNotebook", <||> ], "MaTeX", False ]

maTeXCellQ[ _ ] :=
  False

mathTeX[ cell_Cell ] :=
  With[ { stored = storedSourceTeX[ cell ] },
    If[ StringQ[ stored ], First @ displaySource[ stored ], boxesToTeX @ cellBoxes[ cell ] ]
  ]

$maTeXPreferences = "\
(* ::Package:: *)

(** User initialization file **)

(* MaTeX preferences: preamble, magnification, and the inline-TeX hook.
   The hook is due to Nik Murzin, https://github.com/sw1sh; set $useMaTeXQ = True to enable it,
   so that TeX typed into a notebook renders through LaTeX instead of the built-in parser. *)

Needs[ \"MaTeX`\" ];

$MaTeXPreamble = {
  \"\\\\usepackage{amsfonts}\",
  \"\\\\usepackage{amssymb}\",
  \"\\\\usepackage{mathtools}\",
  \"\\\\usepackage{tikz}\",
  \"\\\\usepackage{tikz-cd}\",
  \"\\\\usetikzlibrary{cd}\"
};

$useMaTeXMag = 2;
$useMaTeXBaselineShift = 0;

InputAssistant`TeXStringToBoxes // Unprotect;
InputAssistant`TeXStringToBoxes[ s_String ] /; TrueQ[ $useMaTeXQ ] :=
  AdjustmentBox[
    ToBoxes @ MaTeX[ s, Magnification -> $useMaTeXMag, \"Preamble\" -> $MaTeXPreamble ],
    BoxBaselineShift -> $useMaTeXBaselineShift
  ];
InputAssistant`TeXStringToBoxes // Protect;

$useMaTeXQ = False;
"

latestMaTeXReleaseURL[] :=
  First @ Query[ "assets", All, "browser_download_url" ] @
    Import[ "https://api.github.com/repos/szhorvat/MaTeX/releases/latest", "RawJSON" ]

findExecutable[ name_String ] :=
  SelectFirst[
    FileNameJoin /@ Tuples[ { executableDirectories[],
      If[ $OperatingSystem === "Windows", { name <> ".exe", name }, { name } ] } ],
    FileExistsQ ]

executableDirectories[] :=
  Join[
    StringSplit[ Environment[ "PATH" ], If[ $OperatingSystem === "Windows", ";", ":" ] ],
    { "/usr/local/bin", "/opt/homebrew/bin", "/Library/TeX/texbin", "/usr/bin" },
    FileNames[ "*", FileNames[ "/usr/local/texlive/*/bin" ] ] ]
