# mdsearch

> **API reference:** [English version](../en/mdsearch.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`mdsearch` bietet **Volltext-Suche** im mdviewer-Widget mit Treffer-Hervorhebung
und Vorwärts-/Rückwärts-Navigation.

Das Modul:
- sucht direkt im Tk-Text-Widget des Viewers
- hebt Treffer farbig hervor
- merkt sich den aktuellen Treffer pro Widget
- ist **zustandslos** gegenüber dem Dokument (kein Re-Parse nötig)

---

## Abhängigkeiten

- Tcl/Tk ≥ 8.6
- `mdviewer 0.3`

---

## Öffentliche API

### `mdsearch::find viewerPath pattern`

Sucht `pattern` im Viewer und hebt alle Treffer hervor.
Setzt den aktuellen Treffer auf den ersten.

```tcl
set n [mdsearch::find .v "Tcl"]
puts "$n Treffer gefunden"
```

**Rückgabewert:** Anzahl der Treffer (Integer)

Die Suche ist **case-insensitive**.

---

### `mdsearch::next viewerPath`

Springt zum nächsten Treffer (wrap-around am Ende).

```tcl
mdsearch::next .v
```

---

### `mdsearch::prev viewerPath`

Springt zum vorherigen Treffer (wrap-around am Anfang).

```tcl
mdsearch::prev .v
```

---

### `mdsearch::clearHighlight viewerPath`

Entfernt alle Hervorhebungen.

```tcl
mdsearch::clearHighlight .v
```

---

### `mdsearch::count viewerPath`

Gibt die Anzahl der aktuellen Treffer zurück.

```tcl
set total [mdsearch::count .v]
```

---

### `mdsearch::current viewerPath`

Gibt den Index des aktuellen Treffers zurück (1-basiert, 0 = kein Treffer).

```tcl
set idx [mdsearch::current .v]
puts "$idx von [mdsearch::count .v]"
```

---

## Tags

| Tag | Farbe | Bedeutung |
|-----|-------|-----------|
| `searchmatch` | Gelb (`#FFEB3B`) | Alle Treffer |
| `searchcurrent` | Orange (`#FF9800`) | Aktueller Treffer |

---

## Vollständiges Beispiel

```tcl
package require mdviewer 0.3
package require mdsearch 0.1

set v [mdviewer::create .v]
pack $v -fill both -expand 1

# Suchleiste
ttk::entry .search -textvariable searchVar
ttk::button .go -text "Suchen" -command {
    set n [mdsearch::find $v $searchVar]
    .status configure -text "$n Treffer"
}
ttk::button .next -text "▶" -command {mdsearch::next $v}
ttk::button .prev -text "◀" -command {mdsearch::prev $v}

# Status anzeigen
proc updateStatus {} {
    global v
    set cur [mdsearch::current $v]
    set tot [mdsearch::count $v]
    .status configure -text "$cur / $tot"
}
```

---

## Nicht-Ziele

- Kein Regex-Suche (nur Literal-Suche)
- Kein Ersetzen
- Keine Suche über mehrere Dokumente
