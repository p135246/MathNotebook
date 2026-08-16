(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "WolframInstitute/MathNotebook",
    "Description" -> "Write mathematics papers in Wolfram notebooks: referencing palette, LaTeX journal stylesheets, LaTeX conversion, MaTeX integration",
    "Creator" -> "Pavel Hajek",
    "License" -> "MIT",
    "PublisherID" -> "WolframInstitute",
    "Version" -> "0.1.24",
    "WolframVersion" -> "14.3+",
    "PrimaryContext" -> "WolframInstitute`MathNotebook`",
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> {
          {
            "WolframInstitute`MathNotebook`",
            "MathNotebookLoader.wl"
          }
        },
        "Symbols" -> {
          "WolframInstitute`MathNotebook`CopyCellReference",
          "WolframInstitute`MathNotebook`TagSelectedCell",
          "WolframInstitute`MathNotebook`GoBack",
          "WolframInstitute`MathNotebook`InsertEnvironment",
          "WolframInstitute`MathNotebook`InsertFrontMatter",
          "WolframInstitute`MathNotebook`InsertCitation",
          "WolframInstitute`MathNotebook`InsertReference",
          "WolframInstitute`MathNotebook`SortBibliography",
          "WolframInstitute`MathNotebook`LabelReferences",
          "WolframInstitute`MathNotebook`ConvertLaTeXCells",
          "WolframInstitute`MathNotebook`ConvertMathCells",
          "WolframInstitute`MathNotebook`ImportLaTeXDocument",
          "WolframInstitute`MathNotebook`ExportLaTeXDocument",
          "WolframInstitute`MathNotebook`ExportLaTeXBundle",
          "WolframInstitute`MathNotebook`ConvertToMaTeX",
          "WolframInstitute`MathNotebook`ConvertFromMaTeX",
          "WolframInstitute`MathNotebook`ConvertLaTeXToMaTeX",
          "WolframInstitute`MathNotebook`ConvertMaTeXToLaTeX",
          "WolframInstitute`MathNotebook`InstallMaTeX",
          "WolframInstitute`MathNotebook`OpenMaTeXPreferences",
          "WolframInstitute`MathNotebook`SetDocumentFontSize",
          "WolframInstitute`MathNotebook`SetMathFontSize",
          "WolframInstitute`MathNotebook`ResetDocumentView",
          "WolframInstitute`MathNotebook`InstallLaTeXFonts",
          "WolframInstitute`MathNotebook`OpenTutorial",
          "WolframInstitute`MathNotebook`UpdateMathNotebook",
          "WolframInstitute`MathNotebook`$MathNotebookCloudVersion"
        }
      },
      {"Documentation", "Root" -> "Documentation", "Language" -> "English"},
      {"FrontEnd", "Root" -> "FrontEnd", "Prepend" -> True},
      {"Asset", "Root" -> "Assets", "Assets" -> {{"Tutorial", "MathNotebookTutorial.nb"}}}
    }
  |>
]
