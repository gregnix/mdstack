# mdhtml-0.1.tm -- Markdown AST zu HTML Renderer
#
# Wandelt den von mdparser-0.2 erzeugten AST in sauberes HTML um.
#
# Public API:
#   mdhtml::render  ast ?options?   --> HTML-String
#   mdhtml::export  ast outFile ?options?
#   mdhtml::exportFile mdFile outFile ?options?
#
# Optionen (als -key value Paare):
#   -title    string    Dokument-Titel (Standard: aus H1)
#   -css      path      Pfad zu externer CSS-Datei (Standard: eingebettetes CSS)
#   -toc      bool      Inhaltsverzeichnis erzeugen (Standard: 0)
#   -lang     string    HTML lang-Attribut (Standard: de)
#   -encoding string    Ausgabe-Encoding (Standard: utf-8)
#
# Unterstuetzte Block-Typen:
#   heading, paragraph, code_block, hr, blockquote, list,
#   deflist, table, image, footnote_section
#
# Unterstuetzte Inline-Typen:
#   text, strong, emphasis, strike, inline_code, link, image,
#   linebreak, span (TIP-700)

package provide mdhtml 0.1

namespace eval mdhtml {
    namespace export render export exportFile
}

# ============================================================
# Public API
# ============================================================

proc mdhtml::exportFile {mdFile outFile args} {
    if {![file exists $mdFile]} {
        error "mdhtml::exportFile: file not found: $mdFile"
    }
    set fh [open $mdFile r]
    fconfigure $fh -encoding utf-8
    set markdown [read $fh]
    close $fh

    # mdparser laden
    if {[catch {package require mdparser 0.2} err]} {
        error "mdparser not available: $err"
    }
    set ast [mdparser::parse $markdown]
    mdhtml::export $ast $outFile {*}$args
}

proc mdhtml::export {ast outFile args} {
    set html [mdhtml::render $ast {*}$args]
    set enc "utf-8"
    foreach {k v} $args {
        if {$k eq "-encoding"} { set enc $v }
    }
    set fh [open $outFile w]
    fconfigure $fh -encoding $enc
    puts -nonewline $fh $html
    close $fh
}

proc mdhtml::render {ast args} {
    # Optionen parsen
    array set opts {
        -title    ""
        -css      ""
        -theme    ""
        -toc      0
        -lang     "de"
        -encoding "utf-8"
    }
    foreach {k v} $args {
        if {[info exists opts($k)]} { set opts($k) $v }
    }

    # AST: document-Dict oder direkte blocks-Liste
    set blocks {}
    set meta   {}
    if {[dict exists $ast type] && [dict get $ast type] eq "document"} {
        set blocks [dict get $ast blocks]
        if {[dict exists $ast meta]} { set meta [dict get $ast meta] }
    } else {
        set blocks $ast
    }

    # Titel: Option > YAML-Meta > erster H1
    set title $opts(-title)
    if {$title eq "" && [dict exists $meta title]} {
        set title [dict get $meta title]
    }
    if {$title eq ""} {
        foreach block $blocks {
            if {[dict get $block type] eq "heading" && [dict get $block level] == 1} {
                set title [mdhtml::_inlinesToText [dict get $block content]]
                break
            }
        }
    }
    if {$title eq ""} { set title "Document" }

    # TOC aufbauen
    set toc ""
    if {$opts(-toc)} {
        set toc [mdhtml::_buildToc $blocks]
    }

    # Body rendern
    set body ""
    foreach block $blocks {
        append body [mdhtml::_renderBlock $block]
    }

    # CSS: Theme als Basis + optionale externe Overrides
    set css ""
    if {$opts(-theme) ne ""} {
        if {[catch {package require mdtheme 0.1}] == 0} {
            catch {set css [mdtheme::toCSS $opts(-theme)]}
        }
    }
    if {$css eq "" && $opts(-css) eq ""} {
        # Kein Theme, keine externe Datei -- eingebettetes Default
        set css [mdhtml::_defaultCss]
    } elseif {$css eq ""} {
        # Nur externe Datei, kein Theme
        if {[file exists $opts(-css)]} {
            set fh [open $opts(-css) r]
            fconfigure $fh -encoding utf-8
            set css [read $fh]
            close $fh
        } else {
            set css [mdhtml::_defaultCss]
        }
    } elseif {$opts(-css) ne "" && [file exists $opts(-css)]} {
        # Theme + externe Datei: zusammenfuehren
        set fh [open $opts(-css) r]
        fconfigure $fh -encoding utf-8
        set extra [read $fh]
        close $fh
        append css "\n/* -- custom overrides -- */\n$extra"
    }

    return [mdhtml::_wrapDocument $title $toc $body $css $opts(-lang)]
}

# ============================================================
# Block-Renderer
# ============================================================

proc mdhtml::_renderBlock {block} {
    set type [dict get $block type]
    switch $type {
        heading {
            set level [dict get $block level]
            set text  [mdhtml::_inlinesToHtml [dict get $block content]]
            set plain [mdhtml::_inlinesToText [dict get $block content]]
            set id    [mdhtml::_makeId $plain]
            return "<h${level} id=\"$id\">$text</h${level}>\n"
        }

        paragraph {
            if {![dict exists $block content]} { return "<p></p>\n" }
            set html [mdhtml::_inlinesToHtml [dict get $block content]]
            return "<p>$html</p>\n"
        }

        code_block {
            set code [mdhtml::escapeHtml [dict get $block text]]
            set lang ""
            if {[dict exists $block lang] && [dict get $block lang] ne ""} {
                set lang " class=\"language-[mdhtml::escapeAttr [dict get $block lang]]\""
            }
            return "<pre><code${lang}>$code</code></pre>\n"
        }

        hr {
            return "<hr>\n"
        }

        blockquote {
            set inner ""
            foreach sub [dict get $block blocks] {
                append inner [mdhtml::_renderBlock $sub]
            }
            return "<blockquote>\n$inner</blockquote>\n"
        }

        list {
            return [mdhtml::_renderList $block]
        }

        deflist {
            return [mdhtml::_renderDefList $block]
        }

        table {
            return [mdhtml::_renderTable $block]
        }

        image {
            set src [mdhtml::escapeAttr [dict get $block url]]
            set alt [mdhtml::escapeHtml [dict get $block alt]]
            return "<figure><img src=\"$src\" alt=\"$alt\"><figcaption>$alt</figcaption></figure>\n"
        }

        footnote_section {
            return [mdhtml::_renderFootnotes $block]
        }

        default {
            return ""
        }
    }
}

# ============================================================
# Listen
# ============================================================

proc mdhtml::_renderList {block} {
    set ordered [expr {[dict exists $block style] && [dict get $block style] eq "ordered"}]
    set tag     [expr {$ordered ? "ol" : "ul"}]
    set html    "<${tag}>\n"

    foreach item [dict get $block items] {
        set checked ""
        # Task-Liste
        if {[dict exists $item checked]} {
            set c [dict get $item checked]
            if {$c eq "1" || $c eq "true"} {
                set checked "<input type=\"checkbox\" checked disabled> "
            } else {
                set checked "<input type=\"checkbox\" disabled> "
            }
        }

        set content ""
        if {[dict exists $item blocks]} {
            foreach sub [dict get $item blocks] {
                # Erstes Paragraph ohne <p>-Tags (inline)
                if {[dict get $sub type] eq "paragraph" && $content eq ""} {
                    set content [mdhtml::_inlinesToHtml [dict get $sub content]]
                } else {
                    append content [mdhtml::_renderBlock $sub]
                }
            }
        } elseif {[dict exists $item content]} {
            set content [mdhtml::_inlinesToHtml [dict get $item content]]
        }
        append html "<li>${checked}${content}</li>\n"
    }
    append html "</${tag}>\n"
    return $html
}

# ============================================================
# Definitionslisten
# ============================================================

proc mdhtml::_renderDefList {block} {
    set html "<dl>\n"
    foreach item [dict get $block items] {
        # term ist inline-Liste
        if {[dict exists $item term]} {
            set termHtml [mdhtml::_inlinesToHtml [dict get $item term]]
            append html "<dt>$termHtml</dt>\n"
        }
        # definitions: Liste von Listen von Inlines
        if {[dict exists $item definitions]} {
            foreach defInlines [dict get $item definitions] {
                set defHtml [mdhtml::_inlinesToHtml $defInlines]
                append html "<dd>$defHtml</dd>\n"
            }
        } elseif {[dict exists $item def]} {
            foreach defBlock [dict get $item def] {
                if {[dict get $defBlock type] eq "paragraph"} {
                    set defHtml [mdhtml::_inlinesToHtml [dict get $defBlock content]]
                    append html "<dd>$defHtml</dd>\n"
                } else {
                    append html "<dd>[mdhtml::_renderBlock $defBlock]</dd>\n"
                }
            }
        }
    }
    append html "</dl>\n"
    return $html
}

# ============================================================
# Tabellen
# ============================================================

proc mdhtml::_renderTable {block} {
    set html "<table>\n"
    set aligns [expr {[dict exists $block alignments] ? [dict get $block alignments] : {}}]

    # Header -- headerInlines nutzen falls vorhanden
    if {[dict exists $block headerInlines]} {
        append html "<thead>\n<tr>\n"
        set i 0
        foreach cell [dict get $block headerInlines] {
            set align [lindex $aligns $i]
            set astyle [expr {$align ne "" ? " style=\"text-align:$align\"" : ""}]
            set cellHtml [mdhtml::_inlinesToHtml $cell]
            append html "<th${astyle}>$cellHtml</th>\n"
            incr i
        }
        append html "</tr>\n</thead>\n"
    } elseif {[dict exists $block header]} {
        append html "<thead>\n<tr>\n"
        set i 0
        foreach cell [dict get $block header] {
            set align [lindex $aligns $i]
            set astyle [expr {$align ne "" ? " style=\"text-align:$align\"" : ""}]
            append html "<th${astyle}>[mdhtml::escapeHtml $cell]</th>\n"
            incr i
        }
        append html "</tr>\n</thead>\n"
    }

    # Rows -- rowsInlines nutzen falls vorhanden
    if {[dict exists $block rowsInlines]} {
        append html "<tbody>\n"
        foreach row [dict get $block rowsInlines] {
            append html "<tr>\n"
            set i 0
            foreach cell $row {
                set align [lindex $aligns $i]
                set astyle [expr {$align ne "" ? " style=\"text-align:$align\"" : ""}]
                append html "<td${astyle}>[mdhtml::_inlinesToHtml $cell]</td>\n"
                incr i
            }
            append html "</tr>\n"
        }
        append html "</tbody>\n"
    } elseif {[dict exists $block rows]} {
        append html "<tbody>\n"
        foreach row [dict get $block rows] {
            append html "<tr>\n"
            set i 0
            foreach cell $row {
                set align [lindex $aligns $i]
                set astyle [expr {$align ne "" ? " style=\"text-align:$align\"" : ""}]
                append html "<td${astyle}>[mdhtml::escapeHtml $cell]</td>\n"
                incr i
            }
            append html "</tr>\n"
        }
        append html "</tbody>\n"
    }

    append html "</table>\n"
    return $html
}

# ============================================================
# Fussnoten
# ============================================================

proc mdhtml::_renderFootnotes {block} {
    set html "<section class=\"footnotes\">\n<hr>\n<ol>\n"
    foreach fn [dict get $block footnotes] {
        set num [dict get $fn num]
        set inner ""
        foreach sub [dict get $fn content] {
            append inner [mdhtml::_renderBlock $sub]
        }
        append html "<li id=\"fn${num}\">\n$inner"
        append html "<a href=\"#fnref${num}\" class=\"footnote-backref\">&#8617;</a></li>\n"
    }
    append html "</ol>\n</section>\n"
    return $html
}

# ============================================================
# Inline-Renderer
# ============================================================

proc mdhtml::_inlinesToHtml {inlines} {
    set html ""
    foreach inline $inlines {
        set type [dict get $inline type]
        switch $type {
            text {
                append html [mdhtml::escapeHtml [dict get $inline value]]
            }
            strong {
                set inner [mdhtml::_inlinesToHtml [dict get $inline content]]
                append html "<strong>$inner</strong>"
            }
            emphasis {
                set inner [mdhtml::_inlinesToHtml [dict get $inline content]]
                append html "<em>$inner</em>"
            }
            strike {
                set inner [mdhtml::_inlinesToHtml [dict get $inline content]]
                append html "<s>$inner</s>"
            }
            inline_code {
                set code [mdhtml::escapeHtml [dict get $inline value]]
                append html "<code>$code</code>"
            }
            link {
                set url   [mdhtml::escapeAttr [dict get $inline url]]
                set label [mdhtml::_inlinesToHtml [dict get $inline label]]
                set title ""
                if {[dict exists $inline title] && [dict get $inline title] ne ""} {
                    set title " title=\"[mdhtml::escapeAttr [dict get $inline title]]\""
                }
                append html "<a href=\"$url\"${title}>$label</a>"
            }
            image {
                set src [mdhtml::escapeAttr [dict get $inline url]]
                set alt [mdhtml::escapeHtml \
                    [mdhtml::_inlinesToText \
                        [expr {[dict exists $inline alt] ? [dict get $inline alt] : {}}]]]
                append html "<img src=\"$src\" alt=\"$alt\">"
            }
            linebreak {
                append html "<br>\n"
            }
            span {
                # TIP-700: [text]{.cmd} etc.
                set cls   [dict get $inline class]
                set inner [mdhtml::_inlinesToHtml [dict get $inline content]]
                append html "<span class=\"$cls\">$inner</span>"
            }
            footnote_ref {
                set id [dict get $inline id]
                set num [expr {[dict exists $inline num] ? [dict get $inline num] : $id}]
                append html "<sup><a href=\"#fn${num}\" id=\"fnref${num}\">$num</a></sup>"
            }
            default {
                if {[dict exists $inline value]} {
                    append html [mdhtml::escapeHtml [dict get $inline value]]
                }
            }
        }
    }
    return $html
}

proc mdhtml::_inlinesToText {inlines} {
    set text ""
    foreach inline $inlines {
        set type [dict get $inline type]
        switch $type {
            text        { append text [dict get $inline value] }
            strong -
            emphasis -
            strike      { append text [mdhtml::_inlinesToText [dict get $inline content]] }
            inline_code { append text [dict get $inline value] }
            link        { append text [mdhtml::_inlinesToText [dict get $inline label]] }
            span        { append text [mdhtml::_inlinesToText [dict get $inline content]] }
            default     {
                if {[dict exists $inline value]} { append text [dict get $inline value] }
            }
        }
    }
    return $text
}

# ============================================================
# TOC
# ============================================================

proc mdhtml::_buildToc {blocks} {
    set items {}
    foreach block $blocks {
        set type [dict get $block type]
        if {$type eq "heading"} {
            set level [dict get $block level]
            if {$level <= 3} {
                set text [mdhtml::_inlinesToText [dict get $block content]]
                set id   [mdhtml::_makeId $text]
                lappend items [list $level $text $id]
            }
        }
    }
    if {[llength $items] == 0} { return "" }

    set html "<nav class=\"toc\">\n<ul>\n"
    foreach item $items {
        lassign $item level text id
        set esc   [mdhtml::escapeHtml $text]
        set class [expr {$level == 1 ? "" : " class=\"toc-h$level\""}]
        append html "  <li${class}><a href=\"#$id\">$esc</a></li>\n"
    }
    append html "</ul>\n</nav>\n"
    return $html
}

# ============================================================
# Hilfsprozeduren
# ============================================================

proc mdhtml::escapeHtml {text} {
    set text [string map {& &amp; < &lt; > &gt; \" &quot;} $text]
    return $text
}

proc mdhtml::escapeAttr {text} {
    set text [string map {& &amp; \" &quot; ' &#39;} $text]
    return $text
}

proc mdhtml::_makeId {text} {
    set id [string tolower $text]
    set id [regsub -all {[^a-z0-9-]} $id "-"]
    set id [regsub -all -- {-{2,}} $id "-"]
    set id [string trim $id "-"]
    if {$id eq ""} { set id "section" }
    return $id
}

# ============================================================
# HTML-Dokument zusammenbauen
# ============================================================

proc mdhtml::_wrapDocument {title toc body css lang} {
    set esc [mdhtml::escapeHtml $title]
    set tocHtml [expr {$toc ne "" ? "<div class=\"toc-container\">\n$toc\n</div>\n" : ""}]

    return "<!DOCTYPE html>
<html lang=\"$lang\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>$esc</title>
<style>
$css
</style>
</head>
<body>
<article>
${tocHtml}${body}</article>
</body>
</html>
"
}

proc mdhtml::_defaultCss {} {
    return {
        body {
            font-family: Georgia, 'Times New Roman', serif;
            font-size: 16px;
            line-height: 1.6;
            color: #222;
            max-width: 860px;
            margin: 0 auto;
            padding: 2rem 1.5rem;
            background: #fff;
        }
        h1, h2, h3, h4, h5, h6 {
            font-family: Helvetica, Arial, sans-serif;
            margin-top: 2rem;
            margin-bottom: 0.5rem;
            line-height: 1.2;
        }
        h1 { font-size: 2rem; border-bottom: 2px solid #ddd; padding-bottom: 0.3rem; }
        h2 { font-size: 1.5rem; border-bottom: 1px solid #eee; padding-bottom: 0.2rem; }
        h3 { font-size: 1.2rem; }
        p { margin: 0.8rem 0; }
        code {
            font-family: 'Courier New', Courier, monospace;
            font-size: 0.9em;
            background: #f4f4f4;
            padding: 0.1em 0.3em;
            border-radius: 3px;
        }
        pre {
            background: #f4f4f4;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 1rem;
            overflow-x: auto;
            margin: 1rem 0;
        }
        pre code { background: none; padding: 0; }
        blockquote {
            border-left: 4px solid #ccc;
            margin: 1rem 0;
            padding: 0.5rem 1rem;
            color: #555;
            background: #fafafa;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1rem 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 0.5rem 0.75rem;
            text-align: left;
        }
        th { background: #f0f0f0; font-weight: bold; }
        tr:nth-child(even) { background: #f9f9f9; }
        ul, ol { padding-left: 1.5rem; margin: 0.5rem 0; }
        li { margin: 0.25rem 0; }
        dl { margin: 1rem 0; }
        dt { font-weight: bold; margin-top: 0.5rem; }
        dd { margin-left: 1.5rem; color: #444; }
        a { color: #0057b8; text-decoration: none; }
        a:hover { text-decoration: underline; }
        img { max-width: 100%; height: auto; }
        figure { margin: 1rem 0; text-align: center; }
        figcaption { font-size: 0.9em; color: #666; margin-top: 0.3rem; }
        hr { border: none; border-top: 1px solid #ddd; margin: 2rem 0; }
        .toc-container {
            background: #f8f8f8;
            border: 1px solid #e0e0e0;
            border-radius: 4px;
            padding: 1rem 1.5rem;
            margin-bottom: 2rem;
        }
        .toc ul { list-style: none; padding-left: 0; margin: 0; }
        .toc li { margin: 0.25rem 0; }
        .toc-h2 { padding-left: 1rem; }
        .toc-h3 { padding-left: 2rem; }
        .footnotes { font-size: 0.9em; color: #555; margin-top: 3rem; }
        .footnotes ol { padding-left: 1.5rem; }
        sup a { font-size: 0.75em; }
        span.cmd { font-family: monospace; font-weight: bold; }
        span.arg { font-style: italic; }
        span.lit { font-family: monospace; }
        span.opt { color: #666; }
        input[type="checkbox"] { margin-right: 0.3em; }
    }
}
