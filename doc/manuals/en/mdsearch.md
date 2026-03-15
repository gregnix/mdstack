# mdsearch

## Purpose

`mdsearch` provides **full-text search** in an mdviewer widget with
match highlighting and forward/backward navigation.

The module:
- searches directly in the viewer's Tk text widget
- highlights matches with color tags
- tracks the current match position per widget
- requires no document re-parse

---

## Dependencies

- Tcl/Tk ≥ 8.6
- `mdviewer 0.3`

---

## Public API

### `mdsearch::find viewerPath pattern`

Searches for `pattern` in the viewer and highlights all matches.
Resets the current match to the first one.

```tcl
set positions [mdsearch::find .v "Tcl"]
puts "[llength $positions] matches found"
```

**Return value:** list of match positions (text widget indices, e.g. `{2.5 4.12 ...}`).
Use `mdsearch::count` to get the number of matches as an integer.
Search is case-insensitive.

---

### `mdsearch::next viewerPath`

Jumps to the next match (wraps around at end).

```tcl
mdsearch::next .v
```

---

### `mdsearch::prev viewerPath`

Jumps to the previous match (wraps around at start).

```tcl
mdsearch::prev .v
```

---

### `mdsearch::clearHighlight viewerPath`

Removes all highlights.

```tcl
mdsearch::clearHighlight .v
```

---

### `mdsearch::count viewerPath`

Returns the total number of current matches.

```tcl
set total [mdsearch::count .v]
```

---

### `mdsearch::current viewerPath`

Returns the index of the current match (1-based, 0 = none).

```tcl
puts "[mdsearch::current .v] of [mdsearch::count .v]"
```

---

## Tags

| Tag | Color | Meaning |
|-----|-------|---------|
| `searchmatch` | Yellow `#FFEB3B` | All matches |
| `searchcurrent` | Orange `#FF9800` | Current match |

---

## Example

```tcl
package require mdviewer 0.3
package require mdsearch 0.1

set v [mdviewer::create .v]
pack $v -fill both -expand 1

# Search bar
ttk::entry .search -textvariable searchVar
ttk::button .go   -text "Search" -command {
    mdsearch::find $v $searchVar
    .status configure -text "[mdsearch::current $v] / [mdsearch::count $v]"
}
ttk::button .next -text "▶" -command {mdsearch::next $v}
ttk::button .prev -text "◀" -command {mdsearch::prev $v}
```

---

## Non-goals

- No regex search (literal only)
- No replace
- No cross-document search
