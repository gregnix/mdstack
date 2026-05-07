# Manuals (English)

> **Note (May 2026):** Module names have been migrated to the `mdstack::*`
> scheme (e.g., `mdstack::parser` instead of `mdparser`). Manual filenames
> remain unchanged for historical reasons — content is current.

## Core / Parser

| Module | Description |
|--------|-------------|
| [mdstack::parser](mdparser.md) | Markdown → AST parser |
| [mdstack::validator](mdvalidator.md) | AST validator |
| [mdstack::model](mdmodel.md) | Semantic document model |
| [docir-md](docir-md.md) | _moved_ to [docir repo](../../../docir/) as `docir::mdSource` |

## Renderers

| Module | Description |
|--------|-------------|
| [mdstack::html](mdhtml.md) | Markdown → HTML |
| [mdstack::pdf](mdpdf.md) | Markdown → PDF |
| [mdstack::theme](mdtheme.md) | Shared theme system (HTML, PDF, Tk) |
| [pdf4tcllib](pdf4tcllib.md) | PDF extension library |

## GUI / Tk

| Module | Description |
|--------|-------------|
| [mdstack::viewer](mdviewer.md) | Markdown viewer (Tk text widget) |
| [mdstack::text](mdtext.md) | Editor widget |
| [mdstack::search](mdsearch.md) | Full-text search in viewer |
| [mdstack::outline](mdoutline.md) | Heading structure panel |
| [mdstack::contextmenu](mdcontextmenu.md) | Right-click context menu |

## Stack / Integration

| Module | Description |
|--------|-------------|
| [mdstack](mdstack.md) | Stack orchestrator |
| [mdstack::stacknoteskit](mdstacknoteskit.md) | noteskit adapter |
| [mdhelp_pdf](mdhelp_pdf.md) | Widget-based PDF export |

## Legacy

| Module | Description |
|--------|-------------|
| [mdstack::editor (legacy)](mdeditor.md) | Editor widget (legacy) |
| [mdstack::editorkit](mdeditorkit.md) | Editor kit (legacy) |
| [mdstack::editwidget (legacy)](mdeditwidget.md) | Edit widget (legacy) |
