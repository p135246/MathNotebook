Package["WolframInstitute`MathNotebook`"]

PackageExport[SetDocumentFontSize]
PackageExport[SetMathFontSize]
PackageExport[ResetDocumentView]

PackageScope["$mathStyleNames"]
PackageScope["$inlineMathStyleName"]
PackageScope["$viewSettingKeys"]
PackageScope["baseStyleCells"]
PackageScope["baseFontSizes"]
PackageScope["documentFontSizeAnchor"]
PackageScope["mathFontSizeAnchor"]
PackageScope["viewSettings"]
PackageScope["viewStyleSheet"]
PackageScope["parentStyleSheet"]
PackageScope["viewStyleCells"]
PackageScope["mergedStyleCells"]
PackageScope["documentViewScale"]
PackageScope["mathViewScale"]
PackageScope["relativeMathScale"]
PackageScope["maTeXFontSize"]
PackageScope["rescaleMaTeXCells"]
PackageScope["resizedMaTeXCell"]
PackageScope["maTeXContentQ"]

(* BasicFunctionality T5: the same $Failed hole the five referencing entry points had — with no
   document open this handed $Failed to the notebook_NotebookObject overload, which matches nothing,
   so the call returned unevaluated with no message. Measured for all seven before it was touched. *)
SetDocumentFontSize[ size : _?NumericQ | Automatic ] :=
  withInputNotebook[ { notebook } |-> SetDocumentFontSize[ notebook, size ] ]

(* FirstReadingDefects T5: the document control now moves mathematics too when the math control is
   untouched, so it has to re-render the MaTeX cells exactly as the math control does — a MaTeX cell
   is an image and inherits nothing. Before the model changed this call could not affect them. *)
SetDocumentFontSize[ notebook_NotebookObject, size : _?NumericQ | Automatic ] :=
  ( applyViewSettings[ notebook, <| "DocumentFontSize" -> size |> ];
    rescaleMaTeXCells[ notebook ] )

SetMathFontSize[ size : _?NumericQ | Automatic ] :=
  withInputNotebook[ { notebook } |-> SetMathFontSize[ notebook, size ] ]

SetMathFontSize[ notebook_NotebookObject, size : _?NumericQ | Automatic ] :=
  ( applyViewSettings[ notebook, <| "MathFontSize" -> size |> ];
    rescaleMaTeXCells[ notebook ] )

ResetDocumentView[] :=
  withInputNotebook[ ResetDocumentView ]

ResetDocumentView[ notebook_NotebookObject ] :=
  ( applyViewSettings[ notebook, AssociationMap[ Automatic &, Join[ $viewSettingKeys, $obsoleteViewSettingKeys ] ] ];
    rescaleMaTeXCells[ notebook ] )

$viewSettingKeys = { "DocumentFontSize", "MathFontSize" }

(* A content-width control shipped in 0.1.5 through 0.1.7 and was then withdrawn. Its key is still
   cleared on reset so that a document written with one of those versions is left with no trace of
   it; nothing else reads the key, and the private sheet is rebuilt whole on every call, so a
   leftover value cannot affect a document's layout. *)
$obsoleteViewSettingKeys = { "ContentWidth" }

$mathStyleNames = { "DisplayFormula", "DisplayFormulaNumbered", "DisplayFormulaEquationNumber" }

(* Inline mathematics is the fourth math style and it cannot join the three above, because its size is
   RELATIVE and theirs are absolute. An inline island is styled "InlineFormula" (Conversion.wl), a
   style no MathNotebook sheet declares — it resolves through the chain from front-end resources as
   1.05*Inherited, so an island renders at 1.05 x the size of whatever cell it sits in: measured, 1649
   ink in a Title cell against 420 in a Text cell. That tracking is worth keeping, so the control
   scales the RATIO instead of writing a size. Writing an absolute size does reach the island — it is
   how this was first tried — but it stops the tracking, and a Title's inline mathematics then
   *shrinks* (1577 against 1649 as shipped). baseFontSizes could not supply a base here anyway: it
   drops non-numeric resolutions, and 1.05*Inherited is one. *)
$inlineMathStyleName = "InlineFormula"

$inlineMathRatio = 1.05

(* FirstReadingDefects T5, defect 3's second half, and the two things it turns on.

   FIRST, the ratio is applied to a host cell the DOCUMENT control has already scaled, so scaling it
   by the mathematics ratio alone multiplied the two — the double-scaling Pavel reported. The argument
   here is therefore the RELATIVE scale, mathScale/docScale: the document ratio the host carries is
   divided back out, so an island lands where mathematics is being shown whatever the text slider is
   doing, while still tracking the size of the cell it sits in (an island in a Title is still larger).
   A relative scale of exactly 1 — every state in which the two controls agree, the untouched document
   and the text-only one among them — writes nothing, so the sheet's own ratio stands untouched.

   SECOND, and this is measured rather than reasoned: a RELATIVE FontSize on this style renders at
   the SQUARE of the ratio. Swept r over { 0.5, 1, 1.05, 1.5, 2 } against hosts 13, 26 and 52 and read
   the width of "x + y" (a DisplayFormula's width is exactly linear in its size, 26/51/77/103 px at
   13/26/39/52, so width is a size measurement), an island whose style says r*Inherited comes out at
   r^2 x host every time: r = 2 on a host of 26 renders 104 pt, not 52. The style is resolved once for
   the inline Cell and again for its own contents, and Inherited picks the ratio up both times. So the
   ratio to write is the square ROOT of the wanted relative scale, times the sheet's own ratio — which
   is also why the shipped control was worse than reported: SetMathFontSize at twice the anchor wrote
   2.1 and drew 4.41 x the host. The line-height floor of the enclosing text cell hides this at
   r < 1 (r = 0.5 on a host of 26 is a 6.5 pt island in a 14 px line), so the sweep must read WIDTH. *)
inlineMathCells[ scale_ ] /; scale == 1 :=
  { }

inlineMathCells[ scale_ ] :=
  With[ { ratio = $inlineMathRatio Sqrt[ scale ] },
    { Cell[ StyleData[ $inlineMathStyleName ], FontSize -> ratio Inherited ],
      Cell[ StyleData[ $inlineMathStyleName, "Printout" ], FontSize -> ratio Inherited ] } ]

(* The two ratios the whole control is built from, and the model Pavel confirmed on 2026-07-29.
   documentViewScale is Automatic exactly when the author has not touched the text slider.
   mathViewScale FALLS BACK TO IT rather than to 1: an untouched math slider means "scale with the
   page", so one slider moves prose, display mathematics, inline mathematics and MaTeX coherently;
   an explicit math size overrides that and is measured against the mathematics anchor instead. The
   fallback is the whole of defect 3's first half — display mathematics used to stand still while the
   prose around it grew, which reads as the equations having been left behind. *)
documentViewScale[ parent_, settings_Association ] :=
  viewScale[ Lookup[ settings, "DocumentFontSize", Automatic ], documentFontSizeAnchor[ parent ] ]

mathViewScale[ parent_, settings_Association ] :=
  Replace[ viewScale[ Lookup[ settings, "MathFontSize", Automatic ], mathFontSizeAnchor[ parent ] ],
    Automatic :> documentViewScale[ parent, settings ] ]

relativeMathScale[ math_, document_ ] :=
  Replace[ math, Automatic -> 1 ] / Replace[ document, Automatic -> 1 ]

(* Anything that is not a size is an absent override: the setting is stored as Inherited to delete
   the tagging rule, so a key that survives is numeric, but a document written by an older release
   is not this function's problem to distinguish. *)
viewScale[ size_?NumericQ, anchor_ ] :=
  size / anchor

viewScale[ _, _ ] :=
  Automatic

applyViewSettings[ notebook_NotebookObject, changes_Association ] :=
  With[ { parent = parentStyleSheet[ notebook ] },
    KeyValueMap[
      { key, value } |-> ( CurrentValue[ notebook, { TaggingRules, "MathNotebook", key } ] = Replace[ value, Automatic -> Inherited ] ),
      changes ];
    (* ONE assignment, and it is never a bare stylesheet NAME. That is ResetViewRender T2's repair and
       it is a measured one.

       Assigning a name onto a document that carries a private sheet leaves the front end unable to
       render a page once that document is closed — measured with a fresh front end per repetition, the
       old shape killed the next whole-notebook Export 6/10 to 9/10 and the PDF simply was not written.
       This version never does it: the new sheet is installed directly onto the RECOVERED parent, which
       is what actually prevents the nesting the old intermediate assignment was there for, so the
       intermediate was unnecessary as well as lethal. Measured 0/10 with the resolved sizes of eight
       styles identical to the bare parent's on all ten runs.

       Four alternatives were measured and every one of them is worse. Taking the private sheet off
       first (Inherited, or Automatic), assigning the name twice, and resetting the front end's menus
       afterwards all still die (6/8 to 8/8) — the name is the clause, not the order.
       CurrentValue[ notebook, StyleDefinitions ] = parent measures 0/10 by being a SILENT NO-OP: the
       private sheet survives, the document stays at the overridden size, and "reset" stops resetting,
       which a death rate on its own cannot distinguish from a repair. And a pass-through private sheet
       with no override cells changes what the styles resolve to (Theorem 15 -> 12).

       What this costs is that a document keeps a private sheet after a reset instead of returning to a
       bare name, so the Format menu no longer shows its sheet selected. The neutral sheet restates each
       style at its own base size — the "scale exactly 1" state, which this file already distinguishes
       from Automatic — so the page is identical and parentStyleSheet still recovers the real sheet, and
       a later reset is idempotent. The hazard is NOT gone from the product: picking a stylesheet from
       the Format menu is the front end making that same assignment itself. It is gone from every path
       this paclet controls. The defect is Wolfram 15.0's. *)
    With[ { settings = viewSettings[ notebook ] },
      If[ documentTaggingRules[ notebook ] === <||>,
        CurrentValue[ notebook, { TaggingRules, "MathNotebook" } ] = Inherited ];
      SetOptions[ notebook,
        StyleDefinitions -> viewStyleSheet[ parent, neutralViewSettings[ parent, settings ] ] ] ] ]

(* An empty settings association used to mean "take the private sheet off", which is the lethal
   assignment. It now means "install a sheet that changes nothing": the document's own anchor size,
   which fontSizeCells writes out as every style at its base size. *)
neutralViewSettings[ parent_, settings_Association ] :=
  If[ settings === <| |>,
    <| "DocumentFontSize" -> documentFontSizeAnchor[ parent ] |>,
    settings ]

documentTaggingRules[ notebook_NotebookObject ] :=
  Replace[ CurrentValue[ notebook, { TaggingRules, "MathNotebook" } ], Except[ _Association ] -> <||> ]

viewSettings[ notebook_NotebookObject ] :=
  KeyTake[ documentTaggingRules[ notebook ], $viewSettingKeys ]

(* The private sheet is marked by a hidden style cell so that a sheet the user installed
   themselves is never unwrapped — without a marker a second call would nest the sheets and
   reset could not recover the original. The marker cannot live in the sheet's notebook options:
   the front end drops TaggingRules from a stylesheet notebook whatever shape it is given. *)
parentStyleSheet[ notebook_NotebookObject ] :=
  Replace[ CurrentValue[ notebook, StyleDefinitions ],
    Notebook[ cells_, ___ ] /; ! FreeQ[ cells, StyleData[ $viewStyleSheetMarker ] ] :>
      FirstCase[ cells, Cell[ StyleData[ StyleDefinitions -> parent_ ] ] :> parent ] ]

$viewStyleSheetMarker = "MathNotebookView"

viewStyleSheet[ parent_, settings_Association ] :=
  Notebook[
    Join[
      { Cell[ StyleData[ StyleDefinitions -> parent ] ],
        Cell[ StyleData[ $viewStyleSheetMarker ], StyleMenuListing -> None, MenuSortingValue -> None ] },
      viewStyleCells[ parent, settings ] ],
    StyleDefinitions -> "PrivateStylesheetFormatting.nb" ]

viewStyleCells[ parent_, settings_Association ] :=
  With[ { sizes = baseFontSizes[ parent ],
          document = documentViewScale[ parent, settings ],
          math = mathViewScale[ parent, settings ] },
    mergedStyleCells @ Join[
      fontSizeCells[ sizes, Complement[ styleFontSizeNames[], $mathStyleNames ], document ],
      fontSizeCells[ sizes, $mathStyleNames, math ],
      inlineMathCells[ relativeMathScale[ math, document ] ] ] ]

(* Of two cells carrying the same StyleData head the front end keeps the first and discards the
   second outright — it does not merge their options. The prose and mathematics controls overlap on
   no style today, but they are generated independently and merging is what makes that safe. *)
mergedStyleCells[ cells_List ] :=
  KeyValueMap[ { style, options } |-> Cell[ style, Sequence @@ options ],
    Merge[ Map[ First[ # ] -> Rest[ List @@ # ] &, cells ], Catenate ] ]

fontSizeCells[ _, _, Automatic ] :=
  { }

(* Both the bare style and its "Printout" variant must be written: LaTeXBase gives every prose
   and math style an explicit printout size, and the environment-specific definition wins across
   the whole chain, so a bare override alone never reaches the PDF.

   A scale of exactly 1 still writes its cells — the styles come back at their own base sizes, which
   is what an author who has dragged a slider to the sheet's own size asked for and is not the same
   state as an untouched document (Automatic, above), where nothing is written at all. *)
fontSizeCells[ sizes_Association, styles_List, scale_ ] :=
  Join[
    KeyValueMap[ { style, base } |-> Cell[ StyleData[ style ], FontSize -> Round[ base scale ] ],
      KeyTake[ sizes[ "Screen" ], styles ] ],
    KeyValueMap[ { style, base } |-> Cell[ StyleData[ style, "Printout" ], FontSize -> Round[ base scale ] ],
      KeyTake[ sizes[ "Printout" ], styles ] ] ]

baseStyleCells[] := baseStyleCells[] =
  First @ Get @ FileNameJoin[ { PacletObject[ "WolframInstitute/MathNotebook" ][ "Location" ],
    "FrontEnd", "StyleSheets", "MathNotebook", "LaTeXBase.nb" } ]

(* The base sizes are read out of the document's own stylesheet chain, for the same reason the
   margins are: it is the only channel that resolves a style whose declaration carries no bare
   FontSize of its own. LaTeXBase declares the theorem environments, Proof and Reference as
   StyleData[ name, StyleDefinitions -> StyleData[ "Text" ] ] with a "Printout" size but no screen
   size, and does not declare the list styles at all — so extracting the sizes from the file left
   those styles with no screen override and they never changed size. { style, "Printout" } in the
   path resolves the print environment through the chain; StyleData[ style, "Printout" ] does not,
   it silently returns the screen value. Non-numeric results are dropped: Default.nb gives the
   equation number a symbolic "-1 + Inherited". *)
baseFontSizes[ parent_ ] := baseFontSizes[ parent ] =
  With[ { document = CreateDocument[ { }, Visible -> False, StyleDefinitions -> parent ] },
    With[ { read = environment |-> Select[
          AssociationMap[
            CurrentValue[ document, { StyleDefinitions, environment[ # ], FontSize } ] &,
            styleFontSizeNames[] ],
          NumericQ ] },
      With[ { sizes = <| "Screen" -> read[ # & ], "Printout" -> read[ { #, "Printout" } & ] |> },
        NotebookClose[ document ];
        sizes ] ] ]

(* The styles to scale are those LaTeXBase gives an explicit FontSize in either environment, plus
   the list styles it leaves to Default.nb. Deriving the list from the file rather than from the
   chain is deliberate: it keeps the character styles — Hyperlink, Citation, URL — out, so an
   inline citation goes on inheriting the size of the cell it sits in instead of being pinned. *)
styleFontSizeNames[] := styleFontSizeNames[] =
  Join[
    Union @ Cases[ baseStyleCells[],
      Cell[ StyleData[ style_String ] | StyleData[ style_String, StyleDefinitions -> _ ] |
          StyleData[ style_String, "Printout" ], options___ ] /;
        ! FreeQ[ { options }, FontSize ] :> style, { 1 } ],
    { "Item", "ItemNumbered", "ItemParagraph" } ]

documentFontSizeAnchor[ parent_ ] :=
  baseFontSizes[ parent ][ "Screen", "Text" ]

mathFontSizeAnchor[ parent_ ] :=
  baseFontSizes[ parent ][ "Screen", "DisplayFormula" ]

(* MaTeX cells are images rendered at a fixed size, so they cannot inherit a style change.
   The TeX survives in TaggingRules, so they are re-rendered at the scaled size instead. The size
   is scaled from the base one by the ratio mathematics is being shown at — mathViewScale, which is
   the document ratio while the math slider is untouched (T5) — so an untouched document gives back
   $maTeXBaseFontSize exactly. ConvertToMaTeX reads it too, which is what makes a newly converted
   cell the same size as one the slider has already been over; the pure two-argument form is what
   lets that be asserted without a front end. *)
maTeXFontSize[ notebook_NotebookObject ] :=
  maTeXFontSize[ parentStyleSheet[ notebook ], viewSettings[ notebook ] ]

maTeXFontSize[ parent_, settings_Association ] :=
  Round[ $maTeXBaseFontSize Replace[ mathViewScale[ parent, settings ], Automatic -> 1 ] ]

rescaleMaTeXCells[ notebook_NotebookObject ] :=
  With[ { cells = Select[ Cells[ notebook ], maTeXContentQ @ NotebookRead[ # ] & ] },
    If[ cells =!= { },
      ensureMaTeX[];
      writeCells[ resizedMaTeXCell[ maTeXFontSize[ notebook ] ], cells ] ] ]

(* The slider must reach inline MaTeX islands as well as display cells, and an island lives inside
   a prose cell the display predicate says nothing about. *)
maTeXContentQ[ cell : Cell[ content_, ___ ] ] :=
  maTeXCellQ[ cell ] || ! FreeQ[ content, part_Cell /; maTeXCellQ[ part ] ]

maTeXContentQ[ _ ] :=
  False

(* The author's own source is carried across the re-render, or dragging either slider would silently
   cost a converted cell the text ConvertMaTeXToLaTeX gives back. *)
resizedMaTeXCell[ size_ ][ cell : Cell[ _, style_String, options___ ] ] /; maTeXCellQ[ cell ] :=
  maTeXCell[ storedSourceTeX[ cell ], style, { options }, size, storedLaTeXSource[ cell ] ]

resizedMaTeXCell[ size_ ][ Cell[ TextData[ parts_ ], style_String, options___ ] ] :=
  Cell[ TextData[ Map[
      Replace[ part_Cell /; maTeXCellQ[ part ] :> inlineMaTeXCell[ storedSourceTeX[ part ], size ] ],
      Flatten @ { parts } ] ], style, options ]

resizedMaTeXCell[ _ ][ cell_ ] :=
  cell
