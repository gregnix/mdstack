# mdvalidator-0.1.tm -- AST Validator for mdstack AST-Spec v0.3
#
# Validates each node in the AST against the specification.
# Returns a list of errors (empty = valid).
#
# Usage:
#   package require mdvalidator 0.1
#   set errors [mdvalidator::validate $ast]
#   set errors [mdvalidator::validate $ast -strict]
#
# In strict mode, warnings are also reported as errors
# (e.g. unknown node types, empty text.value).

package provide mdvalidator 0.1

namespace eval mdvalidator {
    variable errors
    variable strict
    variable path
}

# validate --
#   Main entry: validates a complete AST.
#   Returns a list of error strings.
proc mdvalidator::validate {ast args} {
    variable errors
    variable strict
    variable path

    set errors {}
    set strict [expr {"-strict" in $args}]
    set path "/"

    if {![dict exists $ast type]} {
        lappend errors "/: No type field"
        return $errors
    }
    if {[dict get $ast type] ne "document"} {
        lappend errors "/: Root-Node must have type=document, is [dict get $ast type]"
        return $errors
    }

    validateDocument $ast
    return $errors
}

# report --
#   Formatted output of validation results.
proc mdvalidator::report {ast args} {
    set errs [validate $ast {*}$args]
    if {[llength $errs] == 0} {
        return "AST valide (Spec v0.3)"
    }
    set lines [list "AST validation: [llength $errs] errors"]
    foreach e $errs {
        lappend lines "  $e"
    }
    return [join $lines "\n"]
}

# --- Internal Validation Procs ---

proc mdvalidator::addError {msg} {
    variable errors
    variable path
    lappend errors "${path}: $msg"
}

proc mdvalidator::addWarning {msg} {
    variable errors
    variable strict
    variable path
    if {$strict} {
        lappend errors "${path}: WARNUNG: $msg"
    }
}

proc mdvalidator::requireField {node field} {
    if {![dict exists $node $field]} {
        addError "Required field '$field' missing"
        return 0
    }
    return 1
}

proc mdvalidator::requireString {node field} {
    if {![requireField $node $field]} { return 0 }
    return 1
}

proc mdvalidator::requireList {node field} {
    if {![requireField $node $field]} { return 0 }
    set val [dict get $node $field]
    if {[catch {llength $val}]} {
        addError "Field '$field' is not a valid list"
        return 0
    }
    return 1
}

# --- Document ---

proc mdvalidator::validateDocument {node} {
    variable path
    set saved $path
    set path "/document"

    requireField $node version
    if {[dict exists $node version] && [dict get $node version] != 1} {
        addError "version must be 1, is [dict get $node version]"
    }
    requireField $node meta
    requireField $node reflinks

    if {[requireList $node blocks]} {
        set idx 0
        foreach block [dict get $node blocks] {
            set path "/document/blocks\[$idx\]"
            validateBlock $block
            incr idx
        }
    }

    set path $saved
}

# --- Block Nodes ---

proc mdvalidator::validateBlock {node} {
    variable path
    set saved $path

    if {![dict exists $node type]} {
        addError "Block ohne type-Feld"
        set path $saved
        return
    }

    set type [dict get $node type]
    switch -- $type {
        heading    { validateHeading $node }
        paragraph  { validateParagraph $node }
        code_block { validateCodeBlock $node }
        list       { validateList $node }
        blockquote { validateBlockquote $node }
        hr         { }
        image      { validateImage $node "block" }
        table      { validateTable $node }
        deflist    { validateDeflist $node }
        div        { validateDiv $node }
        default    { addWarning "Unknown Block-Typ '$type'" }
    }

    set path $saved
}

proc mdvalidator::validateHeading {node} {
    variable path
    append path "/heading"

    requireField $node level
    if {[dict exists $node level]} {
        set lvl [dict get $node level]
        if {![string is integer -strict $lvl] || $lvl < 1 || $lvl > 6} {
            addError "level must 1-6 sein, ist '$lvl'"
        }
    }

    if {[requireList $node content]} {
        validateInlineList [dict get $node content] "content"
    }

    # anchor ist optional aber wenn vorhanden, String
    if {[dict exists $node anchor]} {
        set a [dict get $node anchor]
        if {$a eq ""} {
            addWarning "anchor ist leer"
        }
    }
}

proc mdvalidator::validateParagraph {node} {
    variable path
    append path "/paragraph"

    if {[requireList $node content]} {
        set inlines [dict get $node content]
        if {[llength $inlines] == 0} {
            addWarning "paragraph.content ist leer"
        }
        validateInlineList $inlines "content"
    }
}

proc mdvalidator::validateCodeBlock {node} {
    variable path
    append path "/code_block"

    requireField $node language
    requireField $node text
}

proc mdvalidator::validateList {node} {
    variable path
    set saved $path
    append path "/list"

    if {[requireField $node style]} {
        set s [dict get $node style]
        if {$s ni {ordered unordered}} {
            addError "style must 'ordered' oder 'unordered' sein, ist '$s'"
        }
    }

    if {[requireList $node items]} {
        set idx 0
        foreach item [dict get $node items] {
            set path "${saved}/list/items\[$idx\]"
            validateListItem $item
            incr idx
        }
    }

    set path $saved
}

proc mdvalidator::validateListItem {node} {
    variable path
    set saved $path
    append path "/list_item"

    if {[dict exists $node type] && [dict get $node type] ne "list_item"} {
        addError "list_item hat falschen type: [dict get $node type]"
    }
    if {![dict exists $node type]} {
        addError "list_item ohne type-Feld"
    }

    if {[requireList $node blocks]} {
        set blocks [dict get $node blocks]
        if {[llength $blocks] == 0} {
            addWarning "list_item.blocks ist leer"
        }
        set idx 0
        foreach block $blocks {
            set path "${saved}/list_item/blocks\[$idx\]"
            validateBlock $block
            incr idx
        }
    }

    # checked ist optional
    if {[dict exists $node checked]} {
        set c [dict get $node checked]
        if {$c ni {0 1}} {
            addError "checked must 0 oder 1 sein, ist '$c'"
        }
    }

    set path $saved
}

proc mdvalidator::validateBlockquote {node} {
    variable path
    set saved $path
    append path "/blockquote"

    if {[requireList $node blocks]} {
        set idx 0
        foreach block [dict get $node blocks] {
            set path "${saved}/blockquote/blocks\[$idx\]"
            validateBlock $block
            incr idx
        }
    }

    set path $saved
}

proc mdvalidator::validateTable {node} {
    variable path
    append path "/table"

    requireList $node header
    requireList $node alignments
    requireList $node rows
    requireList $node headerInlines
    requireList $node rowsInlines

    if {[dict exists $node alignments]} {
        foreach a [dict get $node alignments] {
            if {$a ni {left center right}} {
                addError "alignment must left/center/right sein, ist '$a'"
            }
        }
    }
}

proc mdvalidator::validateDeflist {node} {
    variable path
    set saved $path
    append path "/deflist"

    if {[requireList $node items]} {
        set idx 0
        foreach item [dict get $node items] {
            set path "${saved}/deflist/items\[$idx\]"
            if {![dict exists $item term]} {
                addError "deflist-Item ohne 'term'"
            } else {
                validateInlineList [dict get $item term] "term"
            }
            if {[dict exists $item definitions]} {
                set di 0
                foreach def [dict get $item definitions] {
                    set path "${saved}/deflist/items\[$idx\]/defs\[$di\]"
                    validateInlineList $def "definition"
                    incr di
                }
            }
            incr idx
        }
    }

    set path $saved
}

proc mdvalidator::validateDiv {node} {
    variable path
    set saved $path
    append path "/div"

    requireString $node class
    if {[dict exists $node class] && [dict get $node class] eq ""} {
        addError "div.class must not be empty"
    }

    if {[requireList $node blocks]} {
        set idx 0
        foreach block [dict get $node blocks] {
            set path "${saved}/div/blocks\[$idx\]"
            validateBlock $block
            incr idx
        }
    }

    set path $saved
}

# --- Inline Nodes ---

proc mdvalidator::validateInlineList {inlines context} {
    variable path
    set saved $path
    set idx 0
    foreach inline $inlines {
        set path "${saved}/${context}\[$idx\]"
        validateInline $inline
        incr idx
    }
    set path $saved
}

proc mdvalidator::validateInline {node} {
    variable path
    set saved $path

    if {![dict exists $node type]} {
        addError "Inline-Node ohne type-Feld"
        set path $saved
        return
    }

    set type [dict get $node type]
    switch -- $type {
        text        { validateText $node }
        emphasis    { validateEmphasis $node }
        strong      { validateStrong $node }
        inline_code { validateInlineCode $node }
        link        { validateLink $node }
        image       { validateImage $node "inline" }
        strike      { validateStrike $node }
        linebreak   { }
        span        { validateSpan $node }
        default     { addWarning "Unknown Inline-Typ '$type'" }
    }

    set path $saved
}

proc mdvalidator::validateText {node} {
    variable path
    append path "/text"
    requireField $node value
    if {[dict exists $node value] && [dict get $node value] eq ""} {
        addWarning "text.value ist leer"
    }
}

proc mdvalidator::validateEmphasis {node} {
    variable path
    append path "/emphasis"
    if {[requireList $node content]} {
        validateInlineList [dict get $node content] "content"
    }
}

proc mdvalidator::validateStrong {node} {
    variable path
    append path "/strong"
    if {[requireList $node content]} {
        validateInlineList [dict get $node content] "content"
    }
}

proc mdvalidator::validateInlineCode {node} {
    variable path
    append path "/inline_code"
    requireField $node value
}

proc mdvalidator::validateLink {node} {
    variable path
    append path "/link"

    requireString $node url
    if {[requireList $node label]} {
        validateInlineList [dict get $node label] "label"
    }
    # title ist optional
}

proc mdvalidator::validateImage {node context} {
    variable path
    append path "/image"
    requireString $node alt
    requireString $node url
    # title ist optional
}

proc mdvalidator::validateStrike {node} {
    variable path
    append path "/strike"
    if {[requireList $node content]} {
        validateInlineList [dict get $node content] "content"
    }
}

proc mdvalidator::validateSpan {node} {
    variable path
    append path "/span"

    requireString $node class
    if {[dict exists $node class] && [dict get $node class] eq ""} {
        addError "span.class must not be empty"
    }

    if {[requireList $node content]} {
        validateInlineList [dict get $node content] "content"
    }
}
