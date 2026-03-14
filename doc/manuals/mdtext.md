# mdtext

## Zweck

`mdtext` ist ein **Markdown-Editor-Widget** für Tcl/Tk.

Das Modul:
- ist ein **reines Editor-Widget** (kein Preview)
- bietet **Smart Return** (Listen-Fortsetzung)
- bietet **Tab/Shift-Tab** (Einrücken)
- hat **keine App-Logik** (kein Save/Open)

---

## Architektur

```
mdtext = Editor-Widget
    ↓
mdparser = Parser (getrennt)
    ↓
mdviewer = Preview (getrennt)
```

mdtext ist **nur für Texteingabe** zuständig.

---

## Abhängigkeiten

- Tcl/Tk ≥ 8.6
- Keine weiteren Abhängigkeiten

---

## Öffentliche API

### `mdtext::create path ?options?`

Erzeugt einen Editor.

```tcl
set editor [mdtext::create .editor]
pack $editor -fill both -expand 1
```

#### Text-Widget Optionen

Alle Optionen werden an das Tk-Text-Widget durchgereicht:

```tcl
set editor [mdtext::create .editor \
    -width 80 \
    -height 30 \
    -font "Consolas 12" \
    -wrap word]
```

**Defaults:**
- `-undo 1`
- `-wrap word`
- `-font TkFixedFont`

---

### Features aktivieren

```tcl
$editor enableFeature smartReturn   ;# Listen-Fortsetzung
$editor enableFeature indent        ;# Tab/Shift-Tab
```

Features sind standardmäßig **deaktiviert**.

---

### Basis-API

| Kommando | Beschreibung |
|----------|--------------|
| `$editor get` | Text holen |
| `$editor set $text` | Text setzen |
| `$editor clear` | Leeren |
| `$editor modified` | Modified-Status abfragen |
| `$editor modified 0` | Modified-Status zurücksetzen |
| `$editor onchange $callback` | Change-Callback setzen |

---

### Format-Operationen

| Kommando | Beschreibung |
|----------|--------------|
| `$editor wrap "**"` | Selektion mit `**` umschließen (Bold) |
| `$editor wrap "*"` | Selektion mit `*` umschließen (Italic) |
| `$editor wrap "\`"` | Selektion mit Backticks umschließen (Code) |
| `$editor prefix "> "` | Zeile mit Prefix versehen (Quote) |
| `$editor prefix "- "` | Zeile mit Prefix versehen (Liste) |
| `$editor heading 2` | Zeile als H2 formatieren |
| `$editor codeblock tcl` | Code-Block einfügen |
| `$editor checkbox` | Checkbox togglen |
| `$editor table 3 4` | 3x4 Tabelle einfügen |

---

### Kontext-Abfragen

| Kommando | Rückgabe |
|----------|----------|
| `$editor lineType` | `heading`, `list`, `numlist`, `checkbox`, `quote`, `codeblock`, `code`, `text`, `empty` |
| `$editor currentLine` | Aktuelle Zeile als Text |
| `$editor getHeadings` | Liste: `{level text index}` |

---

### Widget-Zugriff

| Kommando | Beschreibung |
|----------|--------------|
| `$editor widget` | Widget-Pfad (für bind) |
| `$editor text` | Internes Text-Kommando |

---

## Smart Return

Wenn `smartReturn` aktiviert:

| Zeilen-Typ | Return-Verhalten |
|------------|-----------------|
| Liste `- Item` | `\n- ` einfügen |
| Nummeriert `1. Item` | `\n2. ` einfügen |
| Checkbox `- [ ] Task` | `\n- [ ] ` einfügen |
| Quote `> Text` | `\n> ` einfügen |
| Leere Liste `- ` | Zeile löschen |

---

## Tab/Shift-Tab

Wenn `indent` aktiviert:

| Taste | Verhalten |
|-------|-----------|
| Tab | 2 Spaces einfügen / Zeile einrücken |
| Shift-Tab | 2 Spaces entfernen |

---

## Change-Callback

```tcl
$editor onchange {
    puts "Text geändert!"
    updatePreview
}
```

Der Callback wird bei jeder Änderung aufgerufen:
- Normale Texteingabe
- Smart Return
- Tab/Shift-Tab
- Format-Operationen

---

## Beispiel: Editor mit Preview

```tcl
package require mdtext 0.1
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3

# Editor
set editor [mdtext::create .editor]
$editor enableFeature smartReturn
$editor enableFeature indent

# Preview
set preview [mdviewer::create .preview]

# Live-Update
$editor onchange {
    set md [$editor get]
    set ast [mdparser::parse $md]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel $preview $doc
}
```

---

## Nicht-Ziele

* Kein Preview (→ mdviewer)
* Kein Parsing (→ mdparser)
* Kein Save/Open (→ Anwendung)
* Keine Toolbar (→ Anwendung)

Diese Aufgaben gehören in separate Module oder die Anwendung.
