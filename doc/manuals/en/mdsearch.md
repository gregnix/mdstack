# mdstack::search

## Purpose

`mdstack::search` provides **full-text search** in an mdstack::viewer widget with
match highlighting and forward/backward navigation.

The module:
- searches directly in the viewer's Tk text widget
- highlights matches with color tags
- tracks the current match position per widget
- requires no document re-parse

---

## Dependencies

- Tcl/Tk ≥ 8.6
- `mdstack::viewer 0.3`

---

## Public API

### `mdstack::search::find viewerPath pattern`

Searches for `pattern` in the viewer and highlights all matches.
Resets the current match to the first one.

```tcl
set positions [mdstack::search::find .v "Tcl"]
puts "[llength $positions] matches found"
```

**Return value:** list of match positions (text widget indices, e.g. `{2.5 4.12 ...}`).
Use `mdstack::search::count` to get the number of matches as an integer.
Search is case-insensitive.

---

### `mdstack::search::next viewerPath`

Jumps to the next match (wraps around at end).

```tcl
mdstack::search::next .v
```

---

### `mdstack::search::prev viewerPath`

Jumps to the previous match (wraps around at start).

```tcl
mdstack::search::prev .v
```

---

### `mdstack::search::clearHighlight viewerPath`

Removes all highlights.

```tcl
mdstack::search::clearHighlight .v
```

---

### `mdstack::search::count viewerPath`

Returns the total number of current matches.

```tcl
set total [mdstack::search::count .v]
```

---

### `mdstack::search::current viewerPath`

Returns the index of the current match (1-based, 0 = none).

```tcl
puts "[mdstack::search::current .v] of [mdstack::search::count .v]"
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
package require mdstack::viewer 0.3
package require mdstack::search 0.1

set v [mdstack::viewer::create .v]
pack $v -fill both -expand 1

# Search bar
ttk::entry .search -textvariable searchVar
ttk::button .go   -text "Search" -command {
    mdstack::search::find $v $searchVar
    .status configure -text "[mdstack::search::current $v] / [mdstack::search::count $v]"
}
ttk::button .next -text "▶" -command {mdstack::search::next $v}
ttk::button .prev -text "◀" -command {mdstack::search::prev $v}
```

---

## Non-goals

- No regex search (literal only)
- No replace
- No cross-document search
