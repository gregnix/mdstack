# mdstack

## Purpose

`mdstack` is the **orchestrator** for Markdown documents.

The module:
- manages a **stack** of documents
- connects **editor** and **preview** through callbacks
- abstracts the **data source** (e.g. noteskit)
- knows **no concrete modules** — only callbacks

---

## Architecture

```
          mdstack (Orchestrator)
               │
  ┌────────────┼────────────┐
  ▼            ▼            ▼
Editor      Preview     Data source
(Callbacks) (Callback)  (noteskit)
```

**Important:**
- mdstack **never** calls widget methods directly
- mdstack has **no knowledge** of editor widgets
- Everything runs through defined callbacks

---

## Dependencies

- Tcl ≥ 8.6
- No Tk dependency
- No hard coupling to mdtext, mdviewer, or noteskit

---

## Editor API

### `mdstack::setEditorAPI` (required before use)

```tcl
mdstack::setEditorAPI \
    -getText    SCRIPT \
    -setText    SCRIPT \
    -clear      SCRIPT \
    ?-onchange   SCRIPT? \
    ?-isModified SCRIPT?
```

| Option | Required | Description |
|--------|----------|-------------|
| `-getText` | ✅ | Returns Markdown string |
| `-setText` | ✅ | Receives text as argument |
| `-clear` | ✅ | Clears the editor |
| `-onchange` | optional | Registers change callback → live preview |
| `-isModified` | optional | Returns 0/1 |

**Example with mdtext:**

```tcl
set editor [mdtext::create .editor]

mdstack::setEditorAPI \
    -getText    [list $editor get] \
    -setText    [list $editor set] \
    -clear      [list $editor clear] \
    -onchange   [list $editor onchange] \
    -isModified [list $editor modified]
```

### Internal wrapper procs

```tcl
mdstack::editorGetText       ;# get text from editor
mdstack::editorSetText $t    ;# set text
mdstack::editorClear         ;# clear editor
mdstack::editorIsModified    ;# modified status
```

---

## Preview API

```tcl
mdstack::setPreviewAPI -render SCRIPT
```

The script receives the text as argument.

```tcl
mdstack::setPreviewAPI -render {renderMarkdown}

proc renderMarkdown {text} {
    set ast [mdparser::parse $text]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel .preview $doc
}
```

```tcl
mdstack::updatePreview   ;# manual update
```

---

## Stack management

```tcl
mdstack::push -id $id -text $markdown -source "noteskit"
mdstack::pop
mdstack::goto $id
mdstack::clear
```

### Current entry

```tcl
mdstack::current         ;# → {id text source modified}
mdstack::currentId       ;# → "note1"
mdstack::currentText     ;# → "# Markdown..."
mdstack::currentSource   ;# → "noteskit"
```

### Stack info

```tcl
mdstack::size       ;# number of entries
mdstack::isEmpty    ;# is stack empty?
mdstack::index      ;# current index
mdstack::history    ;# list of all IDs
mdstack::entries    ;# all entries (metadata)
```

### Modified status

```tcl
mdstack::modified       ;# query status (0/1)
mdstack::modified 0     ;# reset
mdstack::modified 1     ;# mark as changed
```

```tcl
mdstack::save   ;# invokes onsave callback
```

---

## Callbacks

```tcl
mdstack::onchange   { puts "Switched to: [mdstack::currentId]" }
mdstack::onmodified { .status configure -text "Modified" }
mdstack::onsave {
    noteskit::saveNote [mdstack::currentId] [mdstack::currentText]
}
```

---

## Complete example

```tcl
package require mdstack  0.1
package require mdtext   0.1
package require mdviewer 0.3
package require mdparser 0.2
package require mdmodel  0.1

set editor  [mdtext::create   .editor]
set preview [mdviewer::create .preview]

mdstack::setEditorAPI \
    -getText  [list $editor get] \
    -setText  [list $editor set] \
    -clear    [list $editor clear] \
    -onchange [list $editor onchange]

mdstack::setPreviewAPI -render {renderPreview}

proc renderPreview {text} {
    set ast [mdparser::parse $text]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel .preview $doc
}

mdstack::onsave {
    noteskit::save [mdstack::currentId] [mdstack::currentText]
}

mdstack::push -id "note1" -text $markdown -source "noteskit"
```

---

## Non-goals

- No rendering (→ mdviewer)
- No editing (→ mdtext)
- No file management (→ application)
- No GUI (→ application)
- **No widget references** — callbacks only
