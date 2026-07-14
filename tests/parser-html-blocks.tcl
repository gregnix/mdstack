#!/usr/bin/env tclsh
# parser-html-blocks.tcl - CommonMark HTML blocks (parser 0.8.0)
#
# Before 0.8.0 raw block HTML was DROPPED: the tags fell through to the
# paragraph branch, were parsed as inline markup, and <div>/<table>/<script>
# vanished from the AST. Now they survive verbatim in an html_block node.

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

proc blocks {md} {
    set out {}
    foreach b [dict get [mdstack::parser::parse $md] blocks] {
        lappend out [dict get $b type]
    }
    return $out
}
proc firstHtml {md} {
    foreach b [dict get [mdstack::parser::parse $md] blocks] {
        if {[dict get $b type] eq "html_block"} { return [dict get $b content] }
    }
    return ""
}

# --- start conditions -------------------------------------------------------

test html-type1-script {type 1: <script> ... </script>} -body {
    blocks "<script>\nvar x = 1;\n</script>\n\nText."
} -result {html_block paragraph}

test html-type2-comment {type 2: comment} -body {
    firstHtml "<!-- eine\nNotiz -->\n\nText."
} -result "<!-- eine\nNotiz -->"

test html-type4-declaration {type 4: <!DOCTYPE>} -body {
    blocks "<!DOCTYPE html>\n\nText."
} -result {html_block paragraph}

test html-type6-block-tag {type 6: known block tag, blank line ends it} -body {
    firstHtml "<div class=\"note\">\n  *kein* Markdown\n</div>\n\nText."
} -result "<div class=\"note\">\n  *kein* Markdown\n</div>"

test html-type7-any-tag {type 7: any complete tag alone on a line} -body {
    blocks "<custom-element>\ninhalt\n</custom-element>\n\nText."
} -result {html_block paragraph}

test html-closing-tag {a closing tag alone starts a block too} -body {
    blocks "</div>\n\nText."
} -result {html_block paragraph}

# --- what must NOT become a block ------------------------------------------

test html-inline-stays-paragraph {inline HTML inside a paragraph stays inline} -body {
    blocks "Absatz mit <b>fett</b> darin."
} -result {paragraph}

test html-glob-trap {a tag is not a processing instruction} -body {
    # '<?*' as a [string match] pattern matches <div> too: '?' is a glob
    # wildcard. The type must come from a prefix comparison.
    mdstack::parser::htmlBlockType {<div>} 0
} -result 6

test html-indented-code {four spaces make it indented code, not HTML} -body {
    blocks "    <div>\n"
} -result {code_block}

# --- content is verbatim ----------------------------------------------------

test html-content-verbatim {markdown inside the block is not parsed} -body {
    string match {*[*]kein[*]*} [firstHtml "<div>\n  *kein* Markdown\n</div>\n"]
} -result 1

# --- legacy mode ------------------------------------------------------------

test html-mode-default {default mode is raw} -body {
    mdstack::parser::htmlMode
} -result raw

test html-mode-interpret {interpret mode dismantles the block (doctools nav bars)} -body {
    mdstack::parser::setHtmlMode interpret
    set r [blocks "<hr>\n<a href=\"x\">Link</a>\n<hr>\n\nText."]
    mdstack::parser::setHtmlMode raw
    set r
} -result {hr paragraph hr paragraph}

test html-mode-unknown {an unknown mode is an error, not a silent default} -body {
    catch {mdstack::parser::setHtmlMode bogus} err opts
    dict get $opts -errorcode
} -result {MDSTACK PARSER HTMLMODE}

cleanupTests
