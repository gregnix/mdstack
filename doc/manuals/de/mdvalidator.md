# mdvalidator

> **API reference:** [English version](../en/mdvalidator.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`mdvalidator` prüft einen von `mdparser` erzeugten AST auf strukturelle
Korrektheit. Das Modul ist **headless** (kein Tk) und hat keine
Seiteneffekte.

---

## Abhängigkeiten

- Tcl ≥ 8.6
- `mdparser 0.2` (für Tests)
- keine Tk-Abhängigkeit

---

## Öffentliche API

### `mdvalidator::validate ast ?-strict bool?`

Validiert den AST und gibt eine Liste von Fehlermeldungen zurück.
Leere Liste = valide.

```tcl
set errs [mdvalidator::validate $ast]
if {[llength $errs] > 0} {
    puts "Fehler: [join $errs \n]"
}
```

**Option `-strict 1`:** Unbekannte Block-Typen werden als Fehler
(statt Warnung) gemeldet.

### `mdvalidator::report ast`

Liefert einen formatierten Bericht als String.

```tcl
set ast [mdparser::parse "# Titel\n\nText."]
puts [mdvalidator::report $ast]
# -> "AST validation: ok (N nodes)"
```

---

## Validierungsregeln

| Regel | Beschreibung |
|-------|-------------|
| Root-Typ | Root-Node muss `type=document` haben |
| Blöcke vorhanden | `blocks`-Schlüssel muss existieren |
| Node-Struktur | Jeder Node braucht `type`, `content`, `meta` |
| Bekannte Typen | Warnung bei unbekannten Block-Typen (strict: Fehler) |

---

## Tests

```bash
tclsh tests/validator.tcl    # 42 Tests
tclsh tests/all.tcl --core   # enthalten in Gruppe A
```
