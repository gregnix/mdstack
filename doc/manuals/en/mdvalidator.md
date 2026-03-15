# mdvalidator

## Purpose

`mdvalidator` checks an AST produced by `mdparser` for structural
correctness. The module is **headless** (no Tk) and has no side effects.

---

## Dependencies

- Tcl ≥ 8.6
- No Tk dependency

---

## Public API

### `mdvalidator::validate ast ?-strict bool?`

Validates the AST and returns a list of error messages.
Empty list = valid.

```tcl
set errs [mdvalidator::validate $ast]
if {[llength $errs] > 0} {
    puts "Errors:\n[join $errs \n]"
}

# Strict mode: unknown block types are errors (not warnings)
set errs [mdvalidator::validate $ast -strict 1]
```

### `mdvalidator::report ast ?-strict bool?`

Returns a formatted validation report as a string.

```tcl
set ast [mdparser::parse "# Title\n\nText."]
puts [mdvalidator::report $ast]
# -> "AST validation: ok (N nodes)"
```

---

## Validation rules

| Rule | Description |
|------|-------------|
| Root type | Root node must have `type=document` |
| Blocks present | `blocks` key must exist |
| Node structure | Every node needs `type`, `content`, `meta` |
| Known types | Warning on unknown block types (strict: error) |

---

## Tests

```bash
tclsh tests/validator.tcl    # 42 tests
tclsh tests/all.tcl --core   # included in group A
```
