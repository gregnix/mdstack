# mdstack::indexgen

> Version 0.1

## Purpose

`mdstack::indexgen` builds and updates `index.md` and `indexsub.md` in a
Markdown directory tree. Generated sections sit inside HTML comments so
manual text before/after the blocks is kept.

```
<!-- mdindexgen:begin -->
... generated ...
<!-- mdindexgen:end -->
```

## Dependencies

- Tcl 8.6 or 9 (`package require Tcl 8.6 9`)
- No Tk, no docir

## Public API

### `mdstack::indexgen::scan dir ?-verbose 0? ?-dryrun 0?`

Recursively create/update `index.md` and `indexsub.md`.

Returns a dict: `updated`, `unchanged`, `created`.

### `mdstack::indexgen::updateIndex dir ?-dryrun 0?`

Only `index.md` in that directory.

### `mdstack::indexgen::updateSub dir ?-dryrun 0?`

Only `indexsub.md`.

### `mdstack::indexgen::readTitle file`

Title from YAML frontmatter or first H1; fallback: filename.

### `mdstack::indexgen::readDescription file`

First non-empty paragraph after the title (max 200 characters).

### `mdstack::indexgen::configure ?-key value ...?`

| Option | Default idea | Meaning |
|--------|----------------|---------|
| `-skip_files` | `index.md indexsub.md` | files to skip |
| `-skip_dirs` | `build dist .git …` | directories to skip |
| `-descriptions` | 0/1 | short description in the index |
| `-sort` | `name` / `title` | sort order |

## Example

```tcl
tcl::tm::path add /path/to/mdstack/lib
package require mdstack::indexgen 0.1
mdstack::indexgen::scan /path/to/docs -verbose 1
mdstack::indexgen::scan /path/to/docs -dryrun 1 -verbose 1
```

## See also

- [index](index.md) — manual list
- [mdstack::parser](mdparser.md) — frontmatter / H1 used for titles
