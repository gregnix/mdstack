# mdparser-0.2.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
#
# Markdown parser that produces a Tcl-friendly AST (Markdown-AST v1).
#
# Scope (v0.2):
# - Blocks: heading, paragraph, list (ordered/unordered/task), code_block (``` + indented),
#           hr (---), image (standalone), table (GFM), blockquote (>),
#           deflist (Term + : Definition)
# - Inlines: text, strong (**), emphasis (*), strike (~~), inline_code (` and ``),
#            link [t](url "title"), image ![alt](url "title"), linebreak
#            reference link [t][ref], reference image ![alt][ref]
#
# Architecture (v0.2.7 refactoring):
# - parse: public API, Pass 1 (reflinks), delegates to parseBlocks
# - parseBlocks: dispatcher loop with isXxx / parseXxx pattern
# - isXxx: pure recognition (regexp only, no state)
# - parseXxx: block extraction (upvar lines/i, returns AST node)
# - parseInlines: character-level inline parser (unchanged)
#
# History:
# v0.1    Initial release
# v0.2    Indented code, hard breaks, nested blockquotes
# v0.2.1  Backslash-escape, bold+italic, double-backtick, link title
# v0.2.2  Bare URL autolinks, angle-bracket autolinks, heading inlines
# v0.2.3  Reference links/images, collapsed references
# v0.2.4  Nested lists via indentation
# v0.2.5  Multi-line list items
# v0.2.6  Definition lists (PHP Markdown Extra)
# v0.2.7  AST field name alignment (Spec v0.1), structural refactoring
# v0.2.8  Bracketed spans [t]{.c} (TIP 700), shortcut reference links [t]
# v0.2.9  YAML frontmatter, fenced divs (::: {.class} ... :::)
#
package provide mdparser 0.2

namespace eval mdparser {
    namespace export parse validate supports anchorize
    variable reflinks [dict create]
}

# ============================================================
# Public API
# ============================================================

proc mdparser::parse {markdown} {
    variable reflinks
    set markdown [string map {"\r\n" "\n" "\r" "\n"} $markdown]
    set lines [split $markdown "\n"]

    # --- Pass 0: YAML Frontmatter ---
    set meta [dict create]
    set fmEnd -1
    if {[llength $lines] > 0 && [string trim [lindex $lines 0]] eq "---"} {
        set i 1
        set n [llength $lines]
        while {$i < $n} {
            set line [lindex $lines $i]
            if {[string trim $line] eq "---" || [string trim $line] eq "..."} {
                set fmEnd $i
                break
            }
            incr i
        }
        if {$fmEnd > 0} {
            for {set j 1} {$j < $fmEnd} {incr j} {
                set fmLine [lindex $lines $j]
                if {[regexp {^([A-Za-z_][A-Za-z0-9_-]*):\s+(.*\S)\s*$} $fmLine -> key val]} {
                    dict set meta $key $val
                } elseif {[regexp {^([A-Za-z_][A-Za-z0-9_-]*):\s*$} $fmLine -> key]} {
                    dict set meta $key ""
                }
            }
            set lines [lrange $lines [expr {$fmEnd + 1}] end]
        }
    }

    # --- Pass 1: Reference link definitionen + Footnotes sammeln ---
    set savedRefs $reflinks
    set reflinks [dict create]
    set refDefLines [dict create]
    variable footnotes
    variable footnoteOrder
    set savedFootnotes [expr {[info exists footnotes] ? $footnotes : [dict create]}]
    set savedFootnoteOrder [expr {[info exists footnoteOrder] ? $footnoteOrder : {}}]
    set footnotes [dict create]
    set footnoteOrder {}
    set i 0
    set n [llength $lines]
    while {$i < $n} {
        set line [string trimright [lindex $lines $i]]
        # Footnote definition: [^id]: text (ggf. mehrzeilig)
        if {[regexp {^\[\^([A-Za-z0-9_-]+)\]:\s+(.*)} $line -> fnId fnText]} {
            set fnText [string trim $fnText " \t"]
            # Continuation lines with indentation (mind. 2 Spaces) sammeln
            set j [expr {$i + 1}]
            while {$j < $n} {
                set contLine [lindex $lines $j]
                if {[regexp {^  +\S} $contLine]} {
                    append fnText "\n" [string trimleft $contLine]
                    incr j
                } else {
                    break
                }
            }
            set key [string tolower $fnId]
            if {![dict exists $footnotes $key]} {
                set fnNum [expr {[llength $footnoteOrder] + 1}]
                dict set footnotes $key [dict create id $fnId text $fnText num $fnNum]
                lappend footnoteOrder $key
            }
            for {set k $i} {$k < $j} {incr k} {
                dict set refDefLines $k 1
            }
            set i $j
            continue
        }
        # Reference link definition
        if {[regexp {^\[([^\]]+)\]:\s+(\S+)(?:\s+"([^"]*)")?\s*$} $line -> ref url title]} {
            set key [string tolower $ref]
            if {![dict exists $reflinks $key]} {
                dict set reflinks $key [dict create url $url title $title label $ref]
            }
            dict set refDefLines $i 1
        }
        incr i
    }
    set docRefs $reflinks
    dict for {k v} $savedRefs {
        if {![dict exists $reflinks $k]} {
            dict set reflinks $k $v
        }
    }

    # --- Pass 2: Parse blocks ---
    set blocks [mdparser::parseBlocks lines refDefLines]

    # --- Footnote-Bloecke anhaengen (wenn vorhanden) ---
    if {[llength $footnoteOrder] > 0} {
        set fnBlocks {}
        set fnNum 1
        foreach key $footnoteOrder {
            set fn [dict get $footnotes $key]
            set fnId [dict get $fn id]
            set fnText [dict get $fn text]
            lappend fnBlocks [dict create type footnote_def id $fnId \
                num $fnNum content [mdparser::parseInlines $fnText]]
            incr fnNum
        }
        lappend blocks [dict create type footnote_section footnotes $fnBlocks]
    }

    set reflinks $savedRefs
    set footnotes $savedFootnotes
    set footnoteOrder $savedFootnoteOrder
    return [dict create type document version 1 meta $meta blocks $blocks \
        reflinks $docRefs]
}

proc mdparser::validate {ast} {
    if {![dict exists $ast type] || [dict get $ast type] ne "document"} {
        error "mdparser::validate: not a document AST"
    }
    if {![dict exists $ast version] || [dict get $ast version] != 1} {
        error "mdparser::validate: unsupported AST version"
    }
    if {![dict exists $ast blocks]} {
        error "mdparser::validate: missing blocks"
    }
    return 1
}

proc mdparser::supports {ast} {
    return {
        blocks:heading blocks:paragraph blocks:list blocks:code_block
        blocks:code_indented blocks:hr
        blocks:image blocks:table blocks:blockquote blocks:deflist
        inline:text inline:strong inline:emphasis inline:strike
        inline:inline_code inline:link inline:image inline:linebreak
        inline:reflink inline:refimage
    }
}

# ============================================================
# Block recognition (isXxx) -- pure tests, no side effects
# ============================================================

proc mdparser::isFencedCode {line} {
    regexp {^(`{3,}|~{3,})\s*(\S*)\s*$} $line
}

proc mdparser::isHeading {line} {
    regexp {^(#{1,6})[[:space:]]+} $line
}

proc mdparser::isHr {line} {
    set trimmed [string trim $line]
    # Mindestens 3 gleiche Zeichen (-, *, _), optional mit Spaces
    if {[regexp {^[-]{3,}$} $trimmed]} { return 1 }
    if {[regexp {^[*]{3,}$} $trimmed]} { return 1 }
    if {[regexp {^[_]{3,}$} $trimmed]} { return 1 }
    # Mit Spaces dazwischen: "- - -", "* * *", "_ _ _"
    if {[regexp {^([-] ){2,}[-]$} $trimmed]} { return 1 }
    if {[regexp {^([*] ){2,}[*]$} $trimmed]} { return 1 }
    if {[regexp {^([_] ){2,}[_]$} $trimmed]} { return 1 }
    return 0
}

proc mdparser::isStandaloneImage {line} {
    regexp {^!\[([^\]]*)\]\(([^)]+)\)[[:space:]]*$} [string trim $line]
}

proc mdparser::isTableStart {line} {
    regexp {^\|.+\|[[:space:]]*$} $line
}

proc mdparser::isBlockquote {line} {
    regexp {^>[[:space:]]?} $line
}

proc mdparser::isListItem {line} {
    regexp {^([[:space:]]*)(\*|-|[0-9]+\.)[[:space:]]+} $line
}

proc mdparser::isIndentedCode {line} {
    regexp {^(    |\t)} $line
}

# isDefList needs lookahead: current line is text, next starts with ": "
proc mdparser::isDefList {line nextLine} {
    expr {[string trim $line] ne "" &&
          ![regexp {^:[[:space:]]+} $line] &&
          [regexp {^:[[:space:]]+} $nextLine]}
}

proc mdparser::isPandocDiv {line} {
    regexp {^:{3,}} $line
}

# isPandocDivOpen --
#   Returns class name if line opens a fenced div, empty string otherwise.
#   Formats: ::: {.class}   ::: .class   ::: class   :::class
proc mdparser::isPandocDivOpen {line} {
    if {[regexp {^:{3,}\s+\{\.([A-Za-z][A-Za-z0-9_-]*)\}\s*$} $line -> cls]} {
        return $cls
    }
    if {[regexp {^:{3,}\s+\.?([A-Za-z][A-Za-z0-9_-]*)\s*$} $line -> cls]} {
        return $cls
    }
    return ""
}

# isPandocDivClose --
#   True if line is a bare ::: closing marker.
proc mdparser::isPandocDivClose {line} {
    regexp {^:{3,}\s*$} $line
}

proc mdparser::parsePandocDiv {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set line [string trimright [lindex $lines $i]]
    set cls [mdparser::isPandocDivOpen $line]
    set n [llength $lines]
    incr i

    set body {}
    set depth 1
    while {$i < $n} {
        set cur [string trimright [lindex $lines $i]]
        if {[mdparser::isPandocDivOpen $cur] ne ""} {
            incr depth
        } elseif {[mdparser::isPandocDivClose $cur]} {
            incr depth -1
            if {$depth == 0} {
                incr i
                break
            }
        }
        lappend body $cur
        incr i
    }

    # Recursively parse body as blocks
    set emptyRefDefs [dict create]
    set innerBlocks [mdparser::parseBlocks body emptyRefDefs]

    return [dict create type div class $cls blocks $innerBlocks]
}

# ============================================================
# Block dispatcher
# ============================================================

proc mdparser::parseBlocks {linesVar refDefLinesVar} {
    upvar $linesVar lines $refDefLinesVar refDefLines
    set blocks {}
    set i 0
    set n [llength $lines]

    while {$i < $n} {

        # Skip reference definition
        if {[dict exists $refDefLines $i]} {
            incr i
            continue
        }

        set raw [lindex $lines $i]
        set line [string trimright $raw]

        # Skip blank line
        if {[string trim $line] eq ""} {
            incr i
            continue
        }

        # Pandoc fenced divs (::: .class ... :::)
        if {[mdparser::isPandocDiv $line]} {
            if {[mdparser::isPandocDivOpen $line] ne ""} {
                lappend blocks [mdparser::parsePandocDiv lines i]
            } else {
                # Bare closing ::: without matching opener -- skip
                incr i
            }
            continue
        }

        # --- Block-Erkennung in Prioritaetsreihenfolge ---

        if {[mdparser::isFencedCode $line]} {
            lappend blocks [mdparser::parseFencedCode lines i]
            continue
        }

        if {[mdparser::isHeading $line]} {
            lappend blocks [mdparser::parseHeading lines i]
            continue
        }

        if {[mdparser::isHr $line]} {
            lappend blocks [mdparser::parseHr lines i]
            continue
        }

        if {[mdparser::isStandaloneImage $line]} {
            lappend blocks [mdparser::parseStandaloneImage lines i]
            continue
        }

        if {[mdparser::isTableStart $line]} {
            lappend blocks {*}[mdparser::parseTableBlock lines i]
            continue
        }

        if {[mdparser::isBlockquote $line]} {
            lappend blocks [mdparser::parseBlockquote lines i]
            continue
        }

        if {[mdparser::isListItem $line]} {
            lappend blocks [mdparser::parseListBlock lines i]
            continue
        }

        if {[mdparser::isIndentedCode $line]} {
            set node [mdparser::parseIndentedCode lines i]
            if {$node ne ""} {
                lappend blocks $node
                continue
            }
        }

        # DefList: lookahead to next line
        if {($i + 1) < $n} {
            set nextLine [string trimright [lindex $lines [expr {$i + 1}]]]
            if {[mdparser::isDefList $line $nextLine]} {
                lappend blocks [mdparser::parseDefList lines i]
                continue
            }
        }

        # Fallback: Paragraph
        lappend blocks {*}[mdparser::parseParagraph lines i refDefLines]
    }

    return $blocks
}

# ============================================================
# Block parsers (parseXxx) -- each advances i past consumed lines
# ============================================================

proc mdparser::parseFencedCode {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set line [string trimright [lindex $lines $i]]
    set n [llength $lines]

    regexp {^(`{3,}|~{3,})\s*(\S*)\s*$} $line -> fence lang
    set lang [string trim $lang]
    set fenceChar [string index $fence 0]
    set fenceLen [string length $fence]
    incr i

    set body {}
    while {$i < $n} {
        set cur [lindex $lines $i]
        set trimCur [string trimright $cur]
        if {[regexp "^\\${fenceChar}\{${fenceLen},\}\\s*\$" $trimCur]} {
            break
        }
        lappend body $cur
        incr i
    }
    if {$i < $n} { incr i }

    return [dict create type code_block language $lang text [join $body "\n"]]
}

proc mdparser::parseHeading {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set line [string trimright [lindex $lines $i]]

    regexp {^(#{1,6})[[:space:]]+(.*)$} $line -> hashes title
    set level [string length $hashes]
    set title [string trim $title " \t"]
    # Strip optional closing hashes: "## Foo ##" -> "Foo"
    set title [regsub {\s+#+\s*$} $title ""]
    set anchor [mdparser::anchorize $title]
    incr i

    return [dict create type heading level $level \
        anchor $anchor \
        content [mdparser::parseInlines $title]]
}

proc mdparser::parseHr {linesVar iVar} {
    upvar $iVar i
    incr i
    return [dict create type hr]
}

proc mdparser::parseStandaloneImage {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set line [string trim [string trimright [lindex $lines $i]]]

    regexp {^!\[([^\]]*)\]\(([^)]+)\)[[:space:]]*$} $line -> alt url
    incr i

    return [dict create type image alt $alt url $url]
}

proc mdparser::parseTableBlock {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set n [llength $lines]

    # Collect all contiguous table lines
    set tableLines {}
    while {$i < $n} {
        set cur [string trimright [lindex $lines $i]]
        if {![regexp {^\|.+\|[[:space:]]*$} $cur]} { break }
        lappend tableLines $cur
        incr i
    }

    # Parse table (needs at least 2 lines for header + separator)
    if {[llength $tableLines] >= 2} {
        set table [mdparser::parseTable $tableLines]
        if {$table ne ""} {
            return [list $table]
        }
    }

    # Fallback: lines as paragraphs
    set result {}
    foreach tl $tableLines {
        lappend result [dict create type paragraph content [mdparser::parseInlines $tl]]
    }
    return $result
}

proc mdparser::parseBlockquote {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set n [llength $lines]

    set quoteLines {}
    while {$i < $n} {
        set cur [string trimright [lindex $lines $i]]
        if {[regexp {^>[[:space:]]?(.*)$} $cur -> qt]} {
            lappend quoteLines $qt
            incr i
        } elseif {[string trim $cur] eq ""} {
            # Blank line: include if next line continues quote
            if {($i + 1) < $n &&
                [regexp {^>[[:space:]]?} [lindex $lines [expr {$i + 1}]]]} {
                lappend quoteLines ""
                incr i
            } else {
                break
            }
        } else {
            break
        }
    }

    # Recursively parse inner content
    set innerMd [join $quoteLines "\n"]
    set innerAst [mdparser::parse $innerMd]
    return [dict create type blockquote \
        blocks [dict get $innerAst blocks]]
}

proc mdparser::parseListBlock {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set n [llength $lines]

    # Collect all contiguous list lines (any depth).
    # Type-mismatch check (ordered vs unordered) applies only to markers at
    # the same indent level as the first line -- nested markers (deeper indent)
    # are always collected as sublist content.
    set listLines {}

    # Determine type and base indent of first marker
    set firstLine [string trimright [lindex $lines $i]]
    set curOrdered [regexp {^[[:space:]]*[0-9]+\.[[:space:]]+} $firstLine]
    regexp {^([[:space:]]*)} $firstLine -> _ws
    set baseIndent [string length $_ws]

    while {$i < $n} {
        set cur [string trimright [lindex $lines $i]]
        if {[regexp {^([[:space:]]*)(\*|-|[0-9]+\.)[[:space:]]+} $cur -> lineWs]} {
            set lineIndent [string length $lineWs]
            set lineOrdered [regexp {^[[:space:]]*[0-9]+\.[[:space:]]+} $cur]
            # Break on type mismatch only at top-level indent (sublist markers
            # may freely differ from the outer list type)
            if {[llength $listLines] > 0
                    && $lineIndent <= $baseIndent
                    && $lineOrdered != $curOrdered} {
                break
            }
            lappend listLines $cur
            incr i
        } elseif {[string trim $cur] eq ""} {
            # Blank line: continue only if next line is a top-level marker of
            # the same type
            if {($i + 1) < $n} {
                set next [string trimright [lindex $lines [expr {$i + 1}]]]
                if {[regexp {^([[:space:]]*)(\*|-|[0-9]+\.)[[:space:]]+} $next -> nextWs]} {
                    set nextIndent [string length $nextWs]
                    set nextOrdered [regexp {^[[:space:]]*[0-9]+\.[[:space:]]+} $next]
                    if {$nextIndent <= $baseIndent && $nextOrdered != $curOrdered} {
                        break
                    }
                    incr i
                } else {
                    break
                }
            } else {
                break
            }
        } elseif {[regexp {^[[:space:]]{2,}\S} $cur]} {
            # Indented continuation line (no marker)
            lappend listLines $cur
            incr i
        } else {
            break
        }
    }

    return [mdparser::parseListLines $listLines]
}

# parseIndentedCode returns "" if no real code was found
proc mdparser::parseIndentedCode {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set n [llength $lines]
    set savedI $i

    set body {}
    while {$i < $n} {
        set cur [string trimright [lindex $lines $i]]
        if {[string trim $cur] eq ""} {
            lappend body ""
            incr i
            continue
        }
        if {![regexp {^(    |\t)} $cur]} {
            break
        }
        regsub {^(    |\t)} $cur {} stripped
        lappend body $stripped
        incr i
    }

    # Remove trailing blank lines
    while {[llength $body] > 0 && [lindex $body end] eq ""} {
        set body [lrange $body 0 end-1]
    }

    if {[llength $body] > 0} {
        return [dict create type code_block language "" \
            text [join $body "\n"]]
    }

    # Nothing useful found -- restore position
    set i $savedI
    return ""
}

proc mdparser::parseDefList {linesVar iVar} {
    upvar $linesVar lines $iVar i
    set n [llength $lines]

    set dlItems {}
    while {$i < $n} {
        set cur [string trimright [lindex $lines $i]]
        if {[string trim $cur] eq ""} {
            # Leerzeile: weiter wenn danach Term oder Definition folgt
            if {($i + 1) < $n} {
                set peek [string trimright [lindex $lines [expr {$i + 1}]]]
                if {[regexp {^:[[:space:]]+} $peek]} {
                    incr i
                    continue
                }
                if {[string trim $peek] ne "" &&
                    ![regexp {^:[[:space:]]+} $peek] &&
                    ($i + 2) < $n &&
                    [regexp {^:[[:space:]]+} [string trimright [lindex $lines [expr {$i + 2}]]]]} {
                    incr i
                    continue
                }
            }
            break
        }
        if {[regexp {^:[[:space:]]+(.*)$} $cur -> defText]} {
            # Definitions-Zeile -> an letzten Term anhaengen
            if {[llength $dlItems] > 0} {
                set lastIdx [expr {[llength $dlItems] - 1}]
                set lastItem [lindex $dlItems $lastIdx]
                set defs [dict get $lastItem definitions]
                lappend defs [mdparser::parseInlines [string trim $defText " \t"]]
                dict set lastItem definitions $defs
                lset dlItems $lastIdx $lastItem
            }
            incr i
        } else {
            # Term-Zeile
            set termText [string trim $cur " \t"]
            lappend dlItems [dict create \
                term [mdparser::parseInlines $termText] \
                termText $termText \
                definitions {}]
            incr i
        }
    }

    return [dict create type deflist items $dlItems]
}

# parseParagraph returns a list (0 or 1 elements) to handle the
# safety-net case where no lines were consumed.
proc mdparser::parseParagraph {linesVar iVar refDefLinesVar} {
    upvar $linesVar lines $iVar i $refDefLinesVar refDefLines
    set n [llength $lines]

    set buf {}
    while {$i < $n} {
        # Reference-Definitionen unterbrechen Paragraphen
        if {[dict exists $refDefLines $i]} { break }
        set cur [string trimright [lindex $lines $i]]
        if {[string trim $cur] eq ""} { break }
        if {[regexp {^```} $cur] ||
            [mdparser::isPandocDiv $cur] ||
            [mdparser::isHeading $cur] ||
            [mdparser::isHr $cur] ||
            [mdparser::isListItem $cur] ||
            [mdparser::isStandaloneImage $cur] ||
            [mdparser::isTableStart $cur] ||
            [mdparser::isBlockquote $cur]} {
            break
        }
        set trimmed [string trim $cur]
        # Hard break: two trailing spaces or trailing backslash
        set raw [lindex $lines $i]
        if {[regexp {  $} $raw]} {
            lappend buf "${trimmed}\x00BR"
        } elseif {[regexp {\\$} $trimmed]} {
            regsub {\\$} $trimmed {} trimmed
            lappend buf "${trimmed}\x00BR"
        } else {
            lappend buf $trimmed
        }
        incr i
    }

    set joined [join $buf " "]
    if {$joined eq ""} {
        # Sicherheitsnetz: Zeile passt auf keinen Block-Typ und
        # immediately breaks the paragraph collector -> skip
        incr i
        return {}
    }

    return [list [dict create type paragraph content [mdparser::parseInlines $joined]]]
}

# ============================================================
# List parsing (nested) -- unchanged
# ============================================================

proc mdparser::parseListLines {lines} {
    variable reflinks

    if {[llength $lines] == 0} {
        return [dict create type list style unordered items {}]
    }

    regexp {^([[:space:]]*)} [lindex $lines 0] -> baseWs
    set baseIndent [string length $baseWs]

    regexp {^[[:space:]]*(\*|-|[0-9]+\.)[[:space:]]+} [lindex $lines 0] -> firstMarker
    set ordered [expr {[regexp {^[0-9]+\.$} $firstMarker]}]

    set items {}
    set currentText ""
    set currentChecked ""
    set subLines {}
    set hasItem 0
    set seenSubItem 0

    foreach line $lines {
        regexp {^([[:space:]]*)} $line -> ws
        set lineIndent [string length $ws]
        set hasMarker [regexp {^[[:space:]]*(\*|-|[0-9]+\.)[[:space:]]+} $line]

        if {$lineIndent <= $baseIndent && $hasMarker &&
            [regexp {^[[:space:]]*(\*|-|[0-9]+\.)[[:space:]]+(.*)$} $line -> _m itemText]} {
            if {$hasItem} {
                set itemBlocks [list [dict create type paragraph \
                    content [mdparser::parseInlines [string trim $currentText " \t"]]]]
                if {[llength $subLines] > 0} {
                    lappend itemBlocks [mdparser::parseListLines $subLines]
                }
                set item [dict create type list_item blocks $itemBlocks]
                if {$currentChecked ne ""} { dict set item checked $currentChecked }
                lappend items $item
            }
            set currentChecked ""
            if {[regexp {^\[([ xX])\][[:space:]]+(.*)$} $itemText -> checkMark rest]} {
                set currentChecked [expr {$checkMark ne " "}]
                set itemText $rest
            }
            set currentText $itemText
            set subLines {}
            set hasItem 1
            set seenSubItem 0
        } elseif {!$seenSubItem && !$hasMarker} {
            append currentText " " [string trim $line " \t"]
        } else {
            if {$hasMarker} { set seenSubItem 1 }
            lappend subLines $line
        }
    }

    if {$hasItem} {
        set itemBlocks [list [dict create type paragraph \
            content [mdparser::parseInlines [string trim $currentText " \t"]]]]
        if {[llength $subLines] > 0} {
            lappend itemBlocks [mdparser::parseListLines $subLines]
        }
        set item [dict create type list_item blocks $itemBlocks]
        if {$currentChecked ne ""} { dict set item checked $currentChecked }
        lappend items $item
    }

    set style [expr {$ordered ? "ordered" : "unordered"}]

    return [dict create type list style $style items $items]
}

# ============================================================
# Table parsing -- unchanged
# ============================================================

proc mdparser::parseTable {lines} {
    if {[llength $lines] < 1} { return "" }

    set hasSeparator 0
    if {[llength $lines] >= 2} {
        if {[regexp {^\|[-:| ]+\|[[:space:]]*$} [lindex $lines 1]]} {
            set hasSeparator 1
        }
    }

    if {$hasSeparator} {
        set header [mdparser::parseTableRow [lindex $lines 0]]
        if {[llength $header] == 0} { return "" }
        set alignments [mdparser::parseTableAlignment [lindex $lines 1]]
        set startRow 2
    } else {
        set firstRow [mdparser::parseTableRow [lindex $lines 0]]
        set numCols [llength $firstRow]
        if {$numCols == 0} { return "" }
        set header [lrepeat $numCols ""]
        set alignments [lrepeat $numCols left]
        set startRow 0
    }

    set headerInlines {}
    foreach cell $header {
        lappend headerInlines [mdparser::parseInlines $cell]
    }

    set rows {}
    set rowsInlines {}
    for {set i $startRow} {$i < [llength $lines]} {incr i} {
        set row [mdparser::parseTableRow [lindex $lines $i]]
        while {[llength $row] < [llength $header]} { lappend row "" }
        set row [lrange $row 0 [expr {[llength $header] - 1}]]
        lappend rows $row
        set rowInlines {}
        foreach cell $row {
            lappend rowInlines [mdparser::parseInlines $cell]
        }
        lappend rowsInlines $rowInlines
    }

    return [dict create type table header $header alignments $alignments \
        rows $rows headerInlines $headerInlines rowsInlines $rowsInlines]
}

proc mdparser::parseTableRow {line} {
    set line [string trim $line]
    if {[string index $line 0] eq "|"} { set line [string range $line 1 end] }
    if {[string index $line end] eq "|"} { set line [string range $line 0 end-1] }
    set cells {}
    foreach cell [split $line "|"] { lappend cells [string trim $cell " \t"] }
    return $cells
}

proc mdparser::parseTableAlignment {sepLine} {
    set cells [mdparser::parseTableRow $sepLine]
    set alignments {}
    foreach cell $cells {
        set cell [string trim $cell]
        set left [string match ":*" $cell]
        set right [string match "*:" $cell]
        if {$left && $right} {
            lappend alignments center
        } elseif {$right} {
            lappend alignments right
        } else {
            lappend alignments left
        }
    }
    return $alignments
}

# ============================================================
# Inline parsing -- unchanged
# ============================================================

# findMatchingBracket --
#   Find the position of the closing ] that matches an opening [ at pos 0,
#   accounting for nested [...] pairs. Returns -1 if unmatched.
proc mdparser::findMatchingBracket {s} {
    set depth 0
    set len [string length $s]
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $s $i]
        if {$c eq "\\"} {
            incr i
            continue
        }
        if {$c eq "\["} {
            incr depth
        } elseif {$c eq "\]"} {
            incr depth -1
            if {$depth == 0} {
                return $i
            }
        }
    }
    return -1
}

# ============================================================
# Inline-Parser (Prio 15: aufgeteilt in Einzelprocs)
# ============================================================
# Konvention: mdparser::_tryX {s idx ...} -> {newIdx node} bei Match, {} sonst.

proc mdparser::_tryLineBreak {s idx} {
    if {[string range $s $idx [expr {$idx + 3}]] eq "\x00BR "} {
        return [list [expr {$idx + 4}] [dict create type linebreak]]
    }
    if {[string range $s $idx [expr {$idx + 2}]] eq "\x00BR"} {
        return [list [expr {$idx + 3}] [dict create type linebreak]]
    }
    return {}
}

proc mdparser::_tryBackslash {s idx len} {
    if {[string index $s $idx] ne "\\"} { return {} }
    if {$idx + 1 >= $len} { return {} }
    set next [string index $s [expr {$idx + 1}]]
    if {$next in {* _ ` ~ \[ \] \( \) \\ ! \# + - . \{ \} |}} {
        return [list [expr {$idx + 2}] [dict create type text value $next]]
    }
    return {}
}

proc mdparser::_tryImage {rest idx} {
    if {[regexp -indices {^!\[([^\]]*)\]\(([^)\s"]+)(?:\s+"([^"]*)")?\s*\)} $rest matchRange]} {
        regexp {^!\[([^\]]*)\]\(([^)\s"]+)(?:\s+"([^"]*)")?\s*\)} $rest -> alt url title
        set d [dict create type image alt $alt url $url]
        if {$title ne ""} { dict set d title $title }
        return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
    }
    return {}
}

proc mdparser::_tryLink {rest idx} {
    if {[regexp -indices {^\[([^\]]+)\]\(([^)\s"]+)(?:\s+"([^"]*)")?\s*\)} $rest matchRange]} {
        regexp {^\[([^\]]+)\]\(([^)\s"]+)(?:\s+"([^"]*)")?\s*\)} $rest -> label url title
        set d [dict create type link label [mdparser::parseInlines $label] url [string trim $url]]
        if {$title ne ""} { dict set d title $title }
        return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
    }
    return {}
}

proc mdparser::_tryRefImage {rest idx} {
    variable reflinks
    if {[regexp -indices {^!\[([^\]]*)\]\[([^\]]*)\]} $rest matchRange]} {
        regexp {^!\[([^\]]*)\]\[([^\]]*)\]} $rest -> alt ref
        if {$ref eq ""} { set ref $alt }
        set key [string tolower $ref]
        if {[dict exists $reflinks $key]} {
            set def [dict get $reflinks $key]
            set d [dict create type image alt $alt url [dict get $def url]]
            if {[dict get $def title] ne ""} { dict set d title [dict get $def title] }
            return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
        }
    }
    return {}
}

proc mdparser::_tryRefLink {rest idx} {
    variable reflinks
    if {[regexp -indices {^\[([^\]]+)\]\[([^\]]*)\]} $rest matchRange]} {
        regexp {^\[([^\]]+)\]\[([^\]]*)\]} $rest -> label ref
        if {$ref eq ""} { set ref $label }
        set key [string tolower $ref]
        if {[dict exists $reflinks $key]} {
            set def [dict get $reflinks $key]
            set d [dict create type link label [mdparser::parseInlines $label] url [dict get $def url]]
            if {[dict get $def title] ne ""} { dict set d title [dict get $def title] }
            return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
        }
    }
    return {}
}

proc mdparser::_trySpan {s rest idx} {
    if {[string index $s $idx] ne "\["} { return {} }
    set closePos [mdparser::findMatchingBracket $rest]
    if {$closePos < 0} { return {} }
    set afterClose [string range $rest [expr {$closePos + 1}] end]
    if {[regexp {^\{\.([A-Za-z][A-Za-z0-9_-]*)\}} $afterClose -> cls]} {
        set inner [string range $rest 1 [expr {$closePos - 1}]]
        set spanLen [expr {$closePos + 1 + [string length $cls] + 3}]
        set d [dict create type span class $cls \
            content [mdparser::parseInlines $inner]]
        return [list [expr {$idx + $spanLen}] $d]
    }
    return {}
}

proc mdparser::_tryShortcutRef {s rest idx} {
    variable reflinks
    if {[regexp -indices {^\[([^\]\[]+)\]} $rest matchRange]} {
        set afterMatch [string index $s [expr {$idx + [lindex $matchRange 1] + 1}]]
        if {$afterMatch ni {( \[ \{}} {
            regexp {^\[([^\]\[]+)\]} $rest -> label
            set key [string tolower $label]
            if {[dict exists $reflinks $key]} {
                set def [dict get $reflinks $key]
                set d [dict create type link label [mdparser::parseInlines $label] \
                    url [dict get $def url]]
                if {[dict get $def title] ne ""} { dict set d title [dict get $def title] }
                return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
            }
        }
    }
    return {}
}

proc mdparser::_tryCode {s rest idx} {
    # Double-backtick
    if {[string range $s $idx [expr {$idx + 1}]] eq "``"} {
        set closePos [string first "``" $s [expr {$idx + 2}]]
        if {$closePos >= 0} {
            set code [string range $s [expr {$idx + 2}] [expr {$closePos - 1}]]
            return [list [expr {$closePos + 2}] [dict create type inline_code value $code]]
        }
    }
    # Single backtick
    if {[regexp {^`([^`]+)`} $rest -> code]} {
        return [list [expr {$idx + [string length $code] + 2}] \
            [dict create type inline_code value $code]]
    }
    return {}
}

proc mdparser::_tryEmphasis {rest idx} {
    # Bold+Italic
    if {[regexp {^\*\*\*(.+?)\*\*\*} $rest -> inner]} {
        set d [dict create type strong content [list \
            [dict create type emphasis content [mdparser::parseInlines $inner]]]]
        return [list [expr {$idx + [string length $inner] + 6}] $d]
    }
    # Strong
    if {[regexp {^\*\*(.+?)\*\*} $rest -> inner]} {
        set d [dict create type strong content [mdparser::parseInlines $inner]]
        return [list [expr {$idx + [string length $inner] + 4}] $d]
    }
    # Emphasis
    if {[regexp {^\*(.+?)\*} $rest -> inner]} {
        set d [dict create type emphasis content [mdparser::parseInlines $inner]]
        return [list [expr {$idx + [string length $inner] + 2}] $d]
    }
    return {}
}

proc mdparser::_tryStrike {rest idx} {
    if {[regexp {^~~(.+?)~~} $rest -> inner]} {
        set d [dict create type strike content [mdparser::parseInlines $inner]]
        return [list [expr {$idx + [string length $inner] + 4}] $d]
    }
    return {}
}

proc mdparser::_tryFootnoteRef {rest idx} {
    variable footnotes
    if {![info exists footnotes]} { return {} }
    if {[regexp -indices {^\[\^([A-Za-z0-9_-]+)\]} $rest matchRange]} {
        regexp {^\[\^([A-Za-z0-9_-]+)\]} $rest -> fnId
        set key [string tolower $fnId]
        if {[dict exists $footnotes $key]} {
            set fn [dict get $footnotes $key]
            
            # Nummer wird spaeter im Rendering aufgeloest
            set d [dict create type footnote_ref id $fnId]
            return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
        }
    }
    return {}
}

proc mdparser::_tryAutolink {s rest idx} {
    # Angle-bracket URL
    if {[regexp -indices {^<(https?://[^>\s]+)>} $rest matchRange]} {
        regexp {^<(https?://[^>\s]+)>} $rest -> url
        set d [dict create type link label [list [dict create type text value $url]] url $url]
        return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
    }
    # Angle-bracket mailto
    if {[regexp -indices {^<([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})>} $rest matchRange]} {
        regexp {^<([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})>} $rest -> email
        set d [dict create type link label [list [dict create type text value $email]] url "mailto:$email"]
        return [list [expr {$idx + [lindex $matchRange 1] + 1}] $d]
    }
    # Bare URL
    if {[regexp -indices {^https?://[^\s<>"]+} $rest matchRange]} {
        set url [string range $rest 0 [lindex $matchRange 1]]
        while {[string length $url] > 10 && [string index $url end] in {. , ; : ! ? \)}} {
            set url [string range $url 0 end-1]
        }
        set d [dict create type link label [list [dict create type text value $url]] url $url]
        return [list [expr {$idx + [string length $url]}] $d]
    }
    return {}
}

# -- Dispatcher --

proc mdparser::parseInlines {s} {
    variable reflinks
    if {![info exists reflinks]} { set reflinks [dict create] }
    set s [string trim $s]
    set out {}
    set len [string length $s]
    set idx 0

    while {$idx < $len} {
        set rest [string range $s $idx end]
        set c [string index $s $idx]

        # Dispatch: first match wins
        set match {}

        if {$c eq "\x00"} {
            set match [mdparser::_tryLineBreak $s $idx]
        }
        if {$match eq {} && $c eq "\\"} {
            set match [mdparser::_tryBackslash $s $idx $len]
        }
        if {$match eq {} && $c eq "!"} {
            set match [mdparser::_tryImage $rest $idx]
            if {$match eq {}} { set match [mdparser::_tryRefImage $rest $idx] }
        }
        if {$match eq {} && $c eq "\["} {
            set match [mdparser::_tryFootnoteRef $rest $idx]
            if {$match eq {}} { set match [mdparser::_tryLink $rest $idx] }
            if {$match eq {}} { set match [mdparser::_tryRefLink $rest $idx] }
            if {$match eq {}} { set match [mdparser::_trySpan $s $rest $idx] }
            if {$match eq {}} { set match [mdparser::_tryShortcutRef $s $rest $idx] }
        }
        if {$match eq {} && $c eq "`"} {
            set match [mdparser::_tryCode $s $rest $idx]
        }
        if {$match eq {} && $c eq "*"} {
            set match [mdparser::_tryEmphasis $rest $idx]
        }
        if {$match eq {} && $c eq "~"} {
            set match [mdparser::_tryStrike $rest $idx]
        }
        if {$match eq {} && $c eq "<"} {
            set match [mdparser::_tryAutolink $s $rest $idx]
        }
        if {$match eq {} && $c eq "h"} {
            set match [mdparser::_tryAutolink $s $rest $idx]
        }

        if {$match ne {}} {
            lassign $match idx node
            lappend out $node
            continue
        }

        # Plain text: advance to next special character
        set plainEnd $idx
        while {$plainEnd < $len} {
            set pc [string index $s $plainEnd]
            if {$pc in {! \[ ` * ~ \x00 \\ <}} { break }
            if {$pc eq "h" && [string range $s $plainEnd [expr {$plainEnd + 6}]] in {http:// https:/}} {
                break
            }
            incr plainEnd
        }
        if {$plainEnd > $idx} {
            lappend out [dict create type text value [string range $s $idx [expr {$plainEnd - 1}]]]
            set idx $plainEnd
        } else {
            lappend out [dict create type text value [string index $s $idx]]
            incr idx
        }
    }
    return $out
}

# ============================================================
# Utilities
# ============================================================

proc mdparser::anchorize {s} {
    set a [string tolower $s]
    regsub -all {[^a-z0-9]+} $a "-" a
    set a [string trim $a "-"]
    if {$a eq ""} { return "section" }
    return $a
}
