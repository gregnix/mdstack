# test-docir-md.tcl -- Tests for docir-md-0.1.tm
# Runs with tclsh (no Tk needed)

set dir [file dirname [file normalize [info script]]]
source [file join $dir .. lib mdparser-0.2.tm]
source [file join $dir .. lib docir-md-0.1.tm]

# Minimales Test-Framework
set _pass 0; set _fail 0
proc test {name body} {
    if {[catch {uplevel 1 $body} err]} {
        puts "FAIL $name: $err"; incr ::_fail
    } else {
        puts "OK   $name"; incr ::_pass
    }
}
proc assert {cond msg} { if {![uplevel 1 [list expr $cond]]} { error $msg } }
proc eq {a b msg} { if {$a ne $b} { error "$msg: got [list $a] expected [list $b]" } }

proc ir {md} { docir::md::fromAst [mdparser::parse $md] }
proc types {ir} {
    set t {}
    foreach n $ir { lappend t [dict get $n type] }
    return $t
}
proc findFirst {ir type} {
    foreach n $ir { if {[dict get $n type] eq $type} { return $n } }
    return {}
}

# ============================================================
test "basic.doc_header" {
    set r [ir "# Hello"]
    set h [lindex $r 0]
    eq "doc_header" [dict get $h type] "erstes Node = doc_header"
}

test "basic.heading_level" {
    set r [ir "# Titel\n## Sub"]
    set h1 [findFirst $r heading]
    assert {$h1 ne {}} "heading gefunden"
    eq 1 [dict get [dict get $h1 meta] level] "level=1"
}

test "basic.heading_text" {
    set r [ir "## Mein Titel"]
    set h [findFirst $r heading]
    set inlines [dict get $h content]
    set txt [dict get [lindex $inlines 0] text]
    eq "Mein Titel" $txt "heading text"
}

test "basic.paragraph" {
    set r [ir "Einfacher Text."]
    set p [findFirst $r paragraph]
    assert {$p ne {}} "paragraph gefunden"
    set txt [dict get [lindex [dict get $p content] 0] text]
    assert {[string match "*Einfacher*" $txt]} "text vorhanden"
}

test "basic.code_block" {
    set r [ir "```tcl\nputs hello\n```"]
    set pre [findFirst $r pre]
    assert {$pre ne {}} "pre gefunden"
    eq "code" [dict get [dict get $pre meta] kind] "kind=code"
    set txt [dict get [lindex [dict get $pre content] 0] text]
    assert {[string match "*puts hello*" $txt]} "code-text"
}

test "basic.hr" {
    set r [ir "---"]
    assert {"hr" in [types $r]} "hr vorhanden"
}

test "inline.strong" {
    set r [ir "Text **fett** Ende."]
    set p [findFirst $r paragraph]
    set itypes {}
    foreach i [dict get $p content] { lappend itypes [dict get $i type] }
    assert {"strong" in $itypes} "strong-Inline vorhanden"
}

test "inline.emphasis" {
    set r [ir "Text *kursiv* Ende."]
    set p [findFirst $r paragraph]
    set itypes {}
    foreach i [dict get $p content] { lappend itypes [dict get $i type] }
    assert {"emphasis" in $itypes} "emphasis-Inline vorhanden"
}

test "inline.code" {
    set r [ir "Befehl \`puts\` aufrufen."]
    set p [findFirst $r paragraph]
    set itypes {}
    foreach i [dict get $p content] { lappend itypes [dict get $i type] }
    assert {"code" in $itypes} "code-Inline vorhanden"
}

test "inline.link" {
    set r [ir "Siehe \[Tcl\](https://tcl.tk)."]
    set p [findFirst $r paragraph]
    set links {}
    foreach i [dict get $p content] {
        if {[dict get $i type] eq "link"} { lappend links $i }
    }
    assert {[llength $links] > 0} "link vorhanden"
    set href [dict get [lindex $links 0] href]
    eq "https://tcl.tk" $href "href korrekt"
}

test "list.unordered" {
    set r [ir "- Alpha\n- Beta\n- Gamma"]
    set l [findFirst $r list]
    assert {$l ne {}} "list gefunden"
    eq "ul" [dict get [dict get $l meta] kind] "kind=ul"
    set items [dict get $l content]
    eq 3 [llength $items] "3 items"
}

test "list.ordered" {
    set r [ir "1. Eins\n2. Zwei\n3. Drei"]
    set l [findFirst $r list]
    eq "ol" [dict get [dict get $l meta] kind] "kind=ol"
}

test "list.item_is_listItem_node" {
    set r [ir "- Alpha\n- Beta"]
    set l [findFirst $r list]
    set item [lindex [dict get $l content] 0]
    eq "listItem" [dict get $item type] "item hat type=listItem"
    assert {[dict exists $item content]} "content vorhanden"
    assert {[dict exists $item meta]}    "meta vorhanden"
    assert {[dict exists [dict get $item meta] kind]} "meta.kind vorhanden"
}

test "list.item_text" {
    set r [ir "- Hallo Welt"]
    set l [findFirst $r list]
    set item [lindex [dict get $l content] 0]
    set txt [dict get [lindex [dict get $item content] 0] text]
    assert {[string match "*Hallo Welt*" $txt]} "item text korrekt"
}

test "blockquote.class" {
    set r [ir "> Ein Zitat."]
    set p [findFirst $r paragraph]
    assert {$p ne {}} "paragraph aus blockquote"
    set cls [expr {[dict exists [dict get $p meta] class] ? [dict get [dict get $p meta] class] : ""}]
    eq "blockquote" $cls "class=blockquote"
}

test "heading.anchor" {
    set r [ir "## Mein Abschnitt"]
    set h [findFirst $r heading]
    set m [dict get $h meta]
    assert {[dict exists $m id]} "id/anchor vorhanden"
}

test "types.sequence" {
    set md "# Titel\n\nErster Absatz.\n\n## Abschnitt\n\nZweiter Absatz."
    set r [ir $md]
    set t [types $r]
    assert {"doc_header" in $t} "doc_header"
    assert {"heading" in $t}   "heading"
    assert {"paragraph" in $t} "paragraph"
}

test "validate.all_nodes_have_type_content_meta" {
    set md "# H\n\nPara.\n\n- A\n- B\n\n```\ncode\n```\n\n---"
    set r [ir $md]
    set i 0
    foreach n $r {
        incr i
        foreach f {type content meta} {
            assert {[dict exists $n $f]} "node $i: '$f' fehlt (type=[dict get $n type])"
        }
    }
}

test "yaml.frontmatter_title" {
    set md "---\ntitle: Mein Dokument\n---\n\n# Inhalt"
    set r [ir $md]
    set h [lindex $r 0]
    eq "doc_header" [dict get $h type] "doc_header"
    set name [dict get [dict get $h meta] name]
    eq "Mein Dokument" $name "title aus frontmatter"
}

# ============================================================
puts ""
puts "=== Ergebnis: $_pass OK, $_fail FAIL ==="
if {$_fail > 0} { exit 1 }
