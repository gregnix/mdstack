# docir-md (Markdown → DocIR)

**Moved.** The `docir::mdSource` module no longer lives in mdstack. As of
May 2026 it was renamed to `docir::mdSource` (naming convention:
sources are called `docir::FORMATSource`) and moved to the central
[docir Repository](../../../docir/).

## Where to find it now

- Module: `docir/mdSource-0.1.tm` in the docir repo under `lib/tm/`
- Docs: `docir/doc/{de,en}/docir-spec.md` for the format spec
- Cookbook: `docir/doc/{de,en}/cookbook.md` for examples

## How to use it from mdstack

mdstack loads it from the docir tree via `tcl::tm::path` (see `tests/_paths.tcl`).
There is no `lib/docir-loader.tcl`.

```tcl
tcl::tm::path add /path/to/docir/lib/tm
package require docir::mdSource

# Function lives in namespace ::docir::md (package name is mdSource):
set ir [::docir::md::fromAst $ast]
```

## Why the move?

- DocIR became large and independent enough for its own repo
- Naming conflict: man-viewer had a `docir::mdSource` as SINK (DocIR → Markdown),
  mdstack had a `docir::mdSource` as SOURCE. Clear convention in the docir repo:
  `docir-FORMAT` (sink) vs `docir::FORMATSource` (source).
- Eliminated code duplication (was a 1:1 copy between repos)

See [`docir/CHANGES.md`](../../../docir/CHANGES.md) for the migration.
