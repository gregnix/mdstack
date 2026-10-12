# mdstack::contextmenu

## Purpose

`mdstack::contextmenu` provides **right-click menus** for Markdown editors.

The module:
- is **editor-local** (no application logic)
- offers formatting actions
- offers insertion actions
- has **no save/open/preview** functions

---

## Dependencies

- Tcl/Tk ≥ 8.6
- `mdstack::uicontextmenu 0.1`

---

## Public API

### `mdstack::contextmenu::attachToEditor editor`

Attaches the context menu to an mdstack::text editor.

```tcl
package require mdstack::text        0.1
package require mdstack::uicontextmenu 0.1
package require mdstack::contextmenu 0.1

set editor [mdstack::text::create .editor]
mdstack::contextmenu::attachToEditor $editor
```

After this, **right-click** in the editor opens the menu.

---

## Menu entries

### Edit

| Entry | Accelerator | Description |
|-------|-------------|-------------|
| Cut | Ctrl+X | Selection to clipboard |
| Copy | Ctrl+C | Copy selection |
| Paste | Ctrl+V | Paste from clipboard |

### Formatting

| Entry | Accelerator | Description |
|-------|-------------|-------------|
| Bold | Ctrl+B | `**text**` |
| Italic | Ctrl+I | `*text*` |
| Code | Ctrl+\` | `` `text` `` |
| Strikethrough | — | `~~text~~` |

### Heading (submenu): H1–H6 (Ctrl+1 through Ctrl+3 for first three)

### List / Quote (submenu)

| Entry | Result |
|-------|--------|
| Unordered list | `- ` prefix |
| Ordered list | `1. ` prefix |
| Task list | `- [ ] ` prefix |
| Blockquote | `> ` prefix |

### Insert (submenu)

| Entry | Result |
|-------|--------|
| Link | `[label](url)` template |
| Image | `![alt](url)` template |
| Code block | ` ```\n\n``` ` |
| Table | 3×3 table template |
| Horizontal rule | `---` |

---

## Spec syntax of `mdstack::uicontextmenu::createFromSpec`

`createFromSpec path spec` builds a menu from a list of entries:

```tcl
mdstack::uicontextmenu::createFromSpec .m {
    {Save   {app::save $w}}                      ;# command (multi-word is fine)
    {Quit   {exit 0} -accelerator Ctrl+Q}        ;# command with options
    {Run    -command {app::run} -state disabled} ;# explicit command
    -                                            ;# separator
    {Insert -menu {{Link {app::link}} {Image {app::image}}}}  ;# explicit submenu
    {Format {{Bold {app::wrap **}} - {Italic {app::wrap *}}}} ;# short submenu form
    {check  Wrap  -variable ::wrap -command app::rewrap}
    {radio  Small -variable ::size -value s}
}
```

How an entry `{label X ...}` is read:

- `{label -menu spec}` is always a submenu, `{label -command cmd ?opts?}`
  always a command entry.
- Options after the command (`{label cmd -accelerator ...}`) make it a
  command entry.
- In the short form `{label X}`, X is a submenu only when it is a
  well-formed spec: every element is `-` or an entry with at least two words.
  A Tcl command starts with a one-word command name, so `{puts hello}` or
  `{app::save $w}` is a command, not a submenu. Use `-menu` or `-command` to
  state the intent explicitly.

Submenu widgets get generated child paths (`.m.sub0`, `.m.sub1`, ...), so
labels may contain capitals, spaces and dots.

---

## Non-goals

- No file operations
- No preview
- No keyboard shortcut management (accelerators are display-only)
