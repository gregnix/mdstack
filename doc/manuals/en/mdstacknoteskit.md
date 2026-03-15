# mdstacknoteskit

## Purpose

Adapter between **noteskit** (note storage) and **mdstack** (editor orchestrator).

Enables integration of noteskit notes into mdstack-based applications.

---

## Architecture

```
┌─────────────────────────────────────────┐
│               Application               │
└─────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌──────────────────────┐
│    noteskit     │  │       mdstack        │
│  (CRUD/Storage) │  │  (Editor/Preview)    │
└─────────────────┘  └──────────────────────┘
         │                    │
         └────────┬───────────┘
                  ▼
         ┌─────────────────┐
         │ mdstacknoteskit │
         │    (Adapter)    │
         └─────────────────┘
```

---

## Dependencies

- `noteskit 0.1`
- `mdstack 0.1`

---

## Usage

```tcl
package require noteskit        0.1
package require mdstack         0.1
package require mdstacknoteskit 0.1

# 1. Initialize noteskit
noteskit::init sqlite -db notes.db

# 2. Set mdstack editor API
mdstack::setEditorAPI \
    -getText  [list $editor get] \
    -setText  [list $editor set] \
    -clear    [list $editor clear]

# 3. Load a note
mdstacknoteskit::loadNote $noteId

# 4. Save changes
mdstacknoteskit::saveCurrent
```

---

## API

### `mdstacknoteskit::loadNote id`

Loads a note from noteskit into mdstack.

### `mdstacknoteskit::saveCurrent`

Saves the current mdstack entry back to noteskit.

### `mdstacknoteskit::connectCallbacks`

Sets up automatic save-on-change callbacks between noteskit and mdstack.

---

## Typical pattern

```tcl
# Open note
mdstacknoteskit::loadNote $selectedId

# Auto-save on mdstack save event
mdstack::onsave {
    mdstacknoteskit::saveCurrent
}

# Close with save prompt
proc closeNote {} {
    if {[mdstack::modified]} {
        # ask whether to save...
    }
    mdstack::pop
}
```
