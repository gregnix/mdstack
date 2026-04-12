# mdpdf-0.2.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
# ============================================================
# PDF export for mdstack (pdf4tcllib backend)
# ============================================================
# Exports Markdown AST or Model as PDF file.
#
# Requirements:
#   package require pdf4tcl 0.9.4.11+
#   package require pdf4tcllib 0.2
#
# New options (0.9.4.11):
#   -compress 1|0         zlib compression (default: 1)
#   -pdfa """|1b|2b       PDF/A conformance level (default: "")
#   -userpassword string  AES-128 user password (default: "")
#   -ownerpassword string AES-128 owner password (default: "")
#   package require mdparser 0.2 (optional, for AST)
#   package require mdmodel 0.1 (optional, for Model)
#
# API:
#   mdpdf::export $ast $outputFile ?options?
#   mdpdf::exportModel $doc $outputFile ?options?
#
# Options:
#   -title     ""       Title on first page
#   -pagesize  A4       Page size (A4, Letter)
#   -margin    50       Margin in points
#   -fontsize  11       Base font size
#   -toc       0        Table of contents (0|1)
#   -header    ""       Header text
#   -footer    "- %p -" Footer text (%p = page number)
#   -root      ""       Base path for relative image URLs
#   -fontdir   ""       Directory with TTF files
#   -debug     0        Debug output
#
# Fixes 2026-03-07 (open issues from pdf-fehler-und-fixes.md):
#   - Fix 4: Widow/Orphan Headings: Faktor 2.5 -> 3.5
#             Heading + mind. 2 Zeilen Text vor Seitenumbruch
#   - Fix 5: Code-Block-Padding: 6pt links/rechts (codeX0, codeMaxW)
#             Code-Text sitzt nicht mehr direkt am Rand
#   - Fix 7: Schriftgroessen-Hierarchie: hDeltas {4 2 1 0 0 0} -> {6 4 2 1 0 0}
#             H1=17pt H2=15pt H3=13pt H4=12pt bei fontSize=11
#   - Fix 9: Italic/BoldItalic jetzt via fontSansItalic/fontSansBoldItalic
#             (TTF-Oblique wenn verfuegbar, sonst Helvetica-Oblique)
#             Konsistente Font-Metriken: kein TTF/Type1-Misch mehr
#
# Architecture – Inline rendering (segment system):
#
#   AST-Inlines -> _inlinesToSegments -> [{text style} ...]
#                -> _wrapStyledSegments -> lines of segments
#                -> _renderStyledLine   -> pdf.text per segment (font switching)
#
#   Styles:  normal     -> fontSans     (TTF or Helvetica)
#            bold       -> fontSansBold (TTF or Helvetica-Bold)
#            italic     -> fontSansItalic (TTF-Oblique or Helvetica-Oblique)
#            bolditalic -> fontSansBoldItalic (TTF-BoldOblique or Helvetica-BoldOblique)
#            code       -> fontMono (Courier)
#
#   All four text styles use consistent font metrics (TTF or all Type1).
#   No mixed TTF/Type1 within one document -> correct pdftotext spacing.
#
#   In blockquotes, parentStyle "italic" is passed,
#   so normal text becomes italic, **bold** -> bolditalic.
#
#   _inlinesToPlainText: For headings and TOC (no font switching).
#   Unicode-Sanitization via pdf4tcllib::unicode::sanitize.
#
# Changes v0.2 vs v0.1:
#   - pdf4tcllib as backend (fonts, unicode, text, page)
#   - _loadTrueTypeFonts (105 lines) removed -> fonts::init
#   - _getFontName (55 lines) removed -> _styleToFont uses pdf4tcllib
#   - _sanitizeForPdf (24 lines) removed -> unicode::sanitize
#   - _textWidth (16 lines) removed -> text::width
#   - _wrapCodeLine (31 lines) removed -> text::wrap with codeContinuation
#   - _getPageSize (22 lines) removed -> page::context
#   - fontWidthFactor array removed
#   - useTTF parameter removed from all procs (fonts::hasTtf instead)
#   - Duplicates _stripMarkdown/_alignText removed
#   - New option: -fontdir (passed through to fonts::init)
#   - Option -usettf removed (fonts::init decides automatically)
#   - 1496 -> ~1090 lines (-27%)
#


# Add vendors/tm path (pdf4tcllib)
set _vendorDir [file normalize [file join [file dirname [info script]] .. vendors tm]]
if {[file isdirectory $_vendorDir]} {
    tcl::tm::path add $_vendorDir
}
unset _vendorDir

package provide mdpdf 0.2

namespace eval mdpdf {
    namespace export export exportFile exportModel configure

    # Image counter for unique image names
    variable imgCounter
    set imgCounter 0

    # Configuration
    variable config
    array set config {
        title         ""
        pagesize      A4
        margin        50
        fontsize      11
        toc           0
        header        ""
        footer        "- %p -"
        root          ""
        fontdir       ""
        creator       ""
        debug         0
        compress      1
        pdfa          ""
        userpassword  ""
        ownerpassword ""
        theme         ""
    }
}

# ============================================================
# Configuration
# ============================================================

proc mdpdf::configure {args} {
    variable config
    foreach {opt val} $args {
        set key [string trimleft $opt -]
        if {[info exists config($key)]} {
            set config($key) $val
        }
    }
}

# ============================================================
# Font-Style -> PDF-Fontname
# ============================================================

proc mdpdf::_styleToFont {style} {
    # Mappt Style-Name auf PDF-Font-Name.
    # Alle vier Stile via pdf4tcllib (TTF if available, else Helvetica).
    switch $style {
        normal     { return [::pdf4tcllib::fonts::fontSans] }
        bold       { return [::pdf4tcllib::fonts::fontSansBold] }
        italic     { return [::pdf4tcllib::fonts::fontSansItalic] }
        bolditalic { return [::pdf4tcllib::fonts::fontSansBoldItalic] }
        code       { return [::pdf4tcllib::fonts::fontMono] }
        strike     { return [::pdf4tcllib::fonts::fontSans] }
        url        { return [::pdf4tcllib::fonts::fontSans] }
        default    { return [::pdf4tcllib::fonts::fontSans] }
    }
}

# ============================================================
# Main export functions
# ============================================================

proc mdpdf::exportFile {mdFile outputFile args} {
    # Reads a Markdown file and exports it as PDF.
    #
    # Reads the file in BINARY mode and replaces emoji bytes (4-Byte UTF-8)
    # with ASCII fallbacks BEFORE Tcl corrupts them to U+FFFD.
    #
    # Args:
    #   mdFile      - Input Markdown file
    #   outputFile  - Output PDF file
    #   args        - Options (same as export)
    # Returns:
    #   Number of pages

    if {![file exists $mdFile]} {
        error "File not found: $mdFile"
    }

    # pdf4tcllib for preprocessBytes laden
    if {[catch {package require pdf4tcllib 0.2} err]} {
        error "pdf4tcllib not available: $err"
    }

    # Binary read + emoji preprocessing
    set markdown [::pdf4tcllib::unicode::readFile $mdFile]

    # Generate AST
    if {[catch {package require mdparser 0.2} err]} {
        error "mdparser not available: $err"
    }
    set ast [mdparser::parse $markdown]

    # Delegate to export
    return [mdpdf::export $ast $outputFile {*}$args]
}

proc mdpdf::export {ast outputFile args} {
    # Exports AST as PDF.
    #
    # Args:
    #   ast         - Markdown AST (from mdparser::parse)
    #   outputFile  - Output PDF file
    #   args        - Options (-title, -pagesize, etc.)

    variable config

    # Parse options
    array set opts [array get config]
    foreach {key val} $args {
        set k [string trimleft $key -]
        if {[info exists config($k)]} {
            set opts($k) $val
        }
    }

    # Theme-Optionen anwenden (mdtheme::toPdfOpts)
    if {$opts(theme) ne ""} {
        if {![catch {package require mdtheme 0.1}]} {
            if {![catch {set thopts [mdtheme::toPdfOpts $opts(theme)]}]} {
                foreach {k v} $thopts {
                    if {[info exists opts($k)] && $opts($k) eq [set config($k)]} {
                        set opts($k) $v
                    }
                }
            }
        }
    }

    # Load pdf4tcl and pdf4tcllib
    if {[catch {package require pdf4tcl} err]} {
        error "pdf4tcl not available: $err"
    }
    if {[catch {package require pdf4tcllib 0.2} err]} {
        error "pdf4tcllib not available: $err"
    }

    # Initialize fonts (TTF lookup via pdf4tcllib)
    set fontArgs {}
    if {$opts(fontdir) ne ""} {
        lappend fontArgs -fontdir $opts(fontdir)
    }
    ::pdf4tcllib::fonts::init {*}$fontArgs

    # Create PDF
    set pdfArgs [list -paper $opts(pagesize) -orient true \
        -compress $opts(compress)]
    if {$opts(pdfa) ne ""} {
        lappend pdfArgs -pdfa $opts(pdfa)
    }
    if {$opts(userpassword) ne ""} {
        lappend pdfArgs -userpassword $opts(userpassword)
    }
    if {$opts(ownerpassword) ne ""} {
        lappend pdfArgs -ownerpassword $opts(ownerpassword)
    }
    set pdf [::pdf4tcl::new %AUTO% {*}$pdfArgs]

    # PDF-Metadaten
    set metaTitle [expr {$opts(title) ne "" ? $opts(title) : [file tail $outputFile]}]
    set metaCreator "mdpdf 0.2"
    if {$opts(creator) ne ""} { append metaCreator " / $opts(creator)" }
    $pdf metadata \
        -title    $metaTitle \
        -creator  $metaCreator \
        -producer "pdf4tcl [package require pdf4tcl] / pdf4tcllib 0.2"

    # Page dimensions via page::context
    set ctx [::pdf4tcllib::page::context $opts(pagesize)]
    set pageW [dict get $ctx page_w]
    set pageH [dict get $ctx page_h]

    set margin $opts(margin)
    set fontSize $opts(fontsize)
    set lineH [expr {int(ceil($fontSize * 1.4))}]

    # Textbereich
    set x0 $margin
    set x1 [expr {$pageW - $margin}]
    set yTop [expr {$margin + ($opts(header) ne "" ? 20 : 0)}]
    set yBot [expr {$pageH - $margin - 20}]
    set maxW [expr {$x1 - $x0}]

    # First page
    $pdf startPage
    set pageNo 1

    # Header on first page (if specified)
    if {$opts(header) ne ""} {
        mdpdf::_writeHeader $pdf $pageNo $pageW $pageH $margin $fontSize $opts(header)
    }

    set y $yTop

    # Titel (falls angegeben)
    if {$opts(title) ne ""} {
        $pdf setFont [expr {$fontSize + 4}] [::pdf4tcllib::fonts::fontSansBold]
        $pdf text [::pdf4tcllib::unicode::sanitize $opts(title)] -x $x0 -y $y
        set y [expr {$y + 2 * $lineH}]
    }

    # TOC (falls gewuenscht)
    if {$opts(toc)} {
        set y [mdpdf::_renderTOC $pdf $ast $y $x0 $maxW $fontSize $opts(debug)]
        set y [expr {$y + $lineH}]
    }

    # Build render context dict
    set rctx [dict create \
        pageW          $pageW          \
        pageH          $pageH          \
        margin         $margin         \
        fontSize       $fontSize       \
        root           $opts(root)     \
        debug          $opts(debug)    \
        footerTemplate $opts(footer)   \
        headerTemplate $opts(header)]

    # Render blocks
    if {[dict exists $ast blocks]} {
        foreach block [dict get $ast blocks] {
            set y [mdpdf::_renderBlock $pdf $rctx $block $y $x0 $maxW $yTop $yBot \
                pageNo 0]

            # Check page break
            if {$y > $yBot} {
                mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                    $opts(footer) $opts(header)
                set y $yTop
            }
        }
    }

    # Finish last page
    mdpdf::_writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize $opts(footer)
    $pdf endPage

    # Save PDF
    $pdf write -file $outputFile
    $pdf destroy

    if {$opts(debug)} {
        puts "mdpdf: $pageNo pages written to $outputFile"
    }

    return $pageNo
}

proc mdpdf::exportModel {doc outputFile args} {
    # Exportiert Model als PDF.
    if {[dict exists $doc ast]} {
        set ast [dict get $doc ast]
    } else {
        error "Model enthaelt kein AST"
    }
    return [mdpdf::export $ast $outputFile {*}$args]
}

# ============================================================
# Block-Rendering
# ============================================================

proc mdpdf::_renderBlock {pdf rctx block y x0 maxW yTop yBot pageNoVar {quoteDepth 0}} {
    upvar $pageNoVar pageNo
    set type  [dict get $block type]
    set lineH [expr {int(ceil([dict get $rctx fontSize] * 1.4))}]
    switch -- $type {
        heading {
            return [mdpdf::_render_heading $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        paragraph {
            return [mdpdf::_render_paragraph $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        code_block {
            return [mdpdf::_render_code_block $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        list {
            return [mdpdf::_render_list $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        hr {
            return [mdpdf::_render_hr $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        blockquote {
            return [mdpdf::_render_blockquote $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        table {
            return [mdpdf::_render_table $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        image {
            return [mdpdf::_render_image $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        div {
            return [mdpdf::_render_div $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        footnote_section {
            return [mdpdf::_render_footnote_section $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        deflist {
            return [mdpdf::_render_deflist $pdf $rctx $block $y $x0 $maxW $yTop $yBot $pageNoVar $quoteDepth]
        }
        default {
            if {[dict get $rctx debug]} {
                puts "mdpdf: Unbekannter Block-Typ: $type"
            }
        }
    }
    return $y
}

proc mdpdf::_render_heading {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set level [dict get $block level]
    set text [::pdf4tcllib::unicode::sanitize [mdpdf::_inlinesToPlainText $block]]
    # Scaling: H1 +6pt, H2 +4pt, H3 +2pt, H4 +1pt, H5-H6 = base
    set hDeltas {6 4 2 1 0 0}
    set hDelta [lindex $hDeltas [expr {min($level - 1, 5)}]]
    set hFontSize [expr {$fontSize + $hDelta}]

    # Space before heading (except at page top)
    if {$y > $yTop + $lineH} {
        set y [expr {$y + int($hFontSize * 1.2)}]
    }

    # Check page break (heading + at least 2 lines of text)
    if {$y + $hFontSize * 3.5 > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }

    $pdf setFont $hFontSize [::pdf4tcllib::fonts::fontSansBold]
    $pdf text $text -x $x0 -y $y
    # PDF-Bookmark: level 0=H1, 1=H2, 2=H3 usw. H3+ geschlossen
    set bmLevel [expr {$level - 1}]
    set bmClosed [expr {$level > 2 ? 1 : 0}]
    $pdf bookmarkAdd -title $text -level $bmLevel -closed $bmClosed
    set y [expr {$y + int($hFontSize * 1.6)}]
    return $y
}

proc mdpdf::_render_paragraph {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set baseStyle [expr {$quoteDepth > 0 ? "italic" : "normal"}]

    if {[dict exists $block content]} {
        set segs [mdpdf::_inlinesToSegments [dict get $block content] $baseStyle]
    } else {
        set segs [list [list "" "normal"]]
    }

    set wrappedLines [mdpdf::_wrapStyledSegments $segs $maxW $fontSize]

    foreach lineSegs $wrappedLines {
        if {$y + $lineH > $yBot} {
            mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                $footerTemplate $headerTemplate
        }

        mdpdf::_renderStyledLine $pdf $lineSegs $y $x0 $fontSize
        set y [expr {$y + $lineH}]
    }
    return $y
}

proc mdpdf::_render_code_block {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set code [dict get $block text]

    # Space before code block
    set y [expr {$y + int($lineH * 0.4)}]

    # Check page break
    if {$y + $lineH > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }

    set codeFontName [::pdf4tcllib::fonts::fontMono]
    $pdf setFont $fontSize $codeFontName
    set lines [split $code "\n"]
    set codeLineH [expr {int($fontSize * 1.2)}]
    set codePadding 6
    set codeX0 [expr {$x0 + $codePadding}]
    set codeMaxW [expr {$maxW - 2 * $codePadding}]

    foreach line $lines {
        if {$y + $codeLineH > $yBot} {
            mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                $footerTemplate $headerTemplate
        }

        # text::wrap with codeContinuation for backslash wrapping
        set wrapped [::pdf4tcllib::text::wrap $line $codeMaxW $fontSize $codeFontName 1]
        foreach wline $wrapped {
            if {$y + $codeLineH > $yBot} {
                mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                    $footerTemplate $headerTemplate
            }

            $pdf setFont $fontSize $codeFontName
            $pdf text [::pdf4tcllib::unicode::sanitize $wline -mono 1] -x $codeX0 -y $y
            set y [expr {$y + $codeLineH}]
        }
    }
    # Space after code block
    set y [expr {$y + int($lineH * 0.4)}]
    return $y
}

proc mdpdf::_render_list {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set items [dict get $block items]
    if {[dict exists $block style]} {
        set ordered [expr {[dict get $block style] eq "ordered"}]
    } else {
        set ordered 0
    }

    set baseStyle [expr {$quoteDepth > 0 ? "italic" : "normal"}]
    set num 1
    set numItems [llength $items]
    set itemIdx  0

    # Kompakt-Check: kurze Listen (bis 8 Items) zusammenhalten.
    # Wenn die ganze Liste nicht auf die aktuelle Seite passt
    # aber auf eine neue Seite passen wuerde -> jetzt umbrechen.
    set totalH [expr {$numItems * $lineH}]
    set pageH_usable [expr {$yBot - $yTop}]
    if {$numItems <= 8 && $totalH <= $pageH_usable &&
        $y + $totalH > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }

    foreach item $items {
        # Normaler Seitenumbruch-Check pro Item
        if {$y + $lineH > $yBot} {
            mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                $footerTemplate $headerTemplate
        }

        if {$ordered} {
            set prefix "$num. "
        } elseif {[dict exists $item checked]} {
            # Task-List-Item
            set prefix [expr {[dict get $item checked] ? {[x] } : {[ ] }}]
        } else {
            set prefix "- "
        }

        set indent   0
        set itemX0   $x0
        set itemMaxW $maxW

        set segs [list [list $prefix $baseStyle]]
        # Render first paragraph from item blocks
        set itemBlocks [dict get $item blocks]
        set firstBlock [lindex $itemBlocks 0]
        if {[dict get $firstBlock type] eq "paragraph" &&
            [dict exists $firstBlock content]} {
            lappend segs {*}[mdpdf::_inlinesToSegments \
                [dict get $firstBlock content] $baseStyle]
        }

        # Continuation lines of wrapped text: indent to align after prefix
        set prefixW [::pdf4tcllib::text::width $prefix $fontSize \
            [mdpdf::_styleToFont $baseStyle]]
        set contX [expr {$itemX0 + $prefixW}]
        set contW [expr {$itemMaxW - $prefixW}]

        set wrappedLines [mdpdf::_wrapStyledSegments $segs $itemMaxW $fontSize]

        set lineIdx 0
        foreach lineSegs $wrappedLines {
            if {$y + $lineH > $yBot} {
                mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                    $footerTemplate $headerTemplate
            }
            if {$lineIdx == 0} {
                mdpdf::_renderStyledLine $pdf $lineSegs $y $itemX0 $fontSize
            } else {
                mdpdf::_renderStyledLine $pdf $lineSegs $y $contX $fontSize
            }
            set y [expr {$y + $lineH}]
            incr lineIdx
        }

        # Sub-lists: rekursiv mit tieferer Einrückung
        foreach subBlock [lrange $itemBlocks 1 end] {
            set subType [dict get $subBlock type]
            if {$subType eq "list"} {
                set subIndent [expr {$itemX0 + 12}]
                set subMaxW   [expr {$maxW - ($subIndent - $x0)}]
                set y [mdpdf::_renderBlock $pdf $rctx $subBlock $y \
                    $subIndent $subMaxW $yTop $yBot pageNo $quoteDepth]
            }
        }

        incr num
        incr itemIdx
    }
    return $y
}

proc mdpdf::_render_hr {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    if {$y + $lineH > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }

    set y [expr {$y + $lineH * 0.5}]
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.5
    $pdf line $x0 $y [expr {$x0 + $maxW}] $y
    $pdf setStrokeColor 0 0 0
    set y [expr {$y + $lineH * 1.0}]
    return $y
}

proc mdpdf::_render_blockquote {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set indent [expr {20 + $quoteDepth * 15}]
    set quoteX [expr {$x0 + $indent}]
    set quoteW [expr {$maxW - $indent}]
    set newDepth [expr {$quoteDepth + 1}]

    # Top-Margin vor Blockquote
    set y [expr {$y + int($lineH * 0.5)}]

    if {[dict exists $block blocks]} {
        set subBlocks [dict get $block blocks]
        set numSubs [llength $subBlocks]
        set subIdx 0

        foreach subBlock $subBlocks {
            set y [mdpdf::_renderBlock $pdf $rctx $subBlock $y $quoteX $quoteW \
                $yTop $yBot pageNo $newDepth]

            incr subIdx
            if {$subIdx < $numSubs} {
                set y [expr {$y + int($lineH * 0.3)}]
            }

            if {$y > $yBot} {
                mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                    $footerTemplate $headerTemplate
            }
        }
    } else {
        if {$y + $lineH > $yBot} {
            mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                $footerTemplate $headerTemplate
        }
        set y [expr {$y + $lineH}]
    }
    return $y
}

proc mdpdf::_render_table {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set header [dict get $block header]
    set rows [dict get $block rows]
    set alignments [dict get $block alignments]
    set hasInlines [dict exists $block headerInlines]

    set cols [llength $header]
    set cellPad 4
    set fontSans [::pdf4tcllib::fonts::fontSans]
    set fontBold [::pdf4tcllib::fonts::fontSansBold]

    # Measure column widths and per-column minimum widths.
    # colPixelWidths: max content width per column (for proportional scaling)
    # colMinWidths:   min width = longest single word per column + padding
    #                 (ensures no word is broken mid-token after scaling)
    set colPixelWidths [lrepeat $cols 0]
    set colMinWidths   [lrepeat $cols 0]

    # Header widths (bold)
    for {set c 0} {$c < $cols} {incr c} {
        if {$hasInlines} {
            set cellText [mdpdf::_inlineListToText [lindex [dict get $block headerInlines] $c]]
        } else {
            set cellText [lindex $header $c]
        }
        set pw [::pdf4tcllib::text::width $cellText $fontSize $fontBold]
        if {$pw > [lindex $colPixelWidths $c]} {
            lset colPixelWidths $c $pw
        }
        set mw [mdpdf::_maxWordWidth $cellText $fontSize $fontBold]
        if {$mw > [lindex $colMinWidths $c]} {
            lset colMinWidths $c $mw
        }
    }

    # Data widths (normal)
    set ri 0
    foreach row $rows {
        for {set c 0} {$c < $cols} {incr c} {
            if {$hasInlines} {
                set cellText [mdpdf::_inlineListToText [lindex [lindex [dict get $block rowsInlines] $ri] $c]]
            } else {
                set cellText [string trim [lindex $row $c]]
            }
            set pw [::pdf4tcllib::text::width $cellText $fontSize $fontSans]
            if {$pw > [lindex $colPixelWidths $c]} {
                lset colPixelWidths $c $pw
            }
            set mw [mdpdf::_maxWordWidth $cellText $fontSize $fontSans]
            if {$mw > [lindex $colMinWidths $c]} {
                lset colMinWidths $c $mw
            }
        }
        incr ri
    }

    # Padding hinzurechnen
    set totalNeeded 0
    set colWidthsPt {}
    set colMinPt    {}
    for {set c 0} {$c < $cols} {incr c} {
        set cw [expr {[lindex $colPixelWidths $c] + 2 * $cellPad}]
        lappend colWidthsPt $cw
        set totalNeeded [expr {$totalNeeded + $cw}]
        lappend colMinPt [expr {[lindex $colMinWidths $c] + 2 * $cellPad}]
    }

    # Proportionale Skalierung auf maxW mit Mindestbreiten-Schutz.
    # Algorithmus:
    #   1. Alle Spalten proportional skalieren.
    #   2. Spalten unter colMinPt auf colMinPt klemmen (fixed).
    #   3. Verbleibenden Platz auf freie Spalten proportional verteilen.
    #   4. Wiederholen bis keine neuen fixed-Spalten mehr entstehen.
    if {$totalNeeded > 0} {
        set fixed   [lrepeat $cols 0]
        set widths  {}
        set scale   [expr {double($maxW) / $totalNeeded}]
        for {set c 0} {$c < $cols} {incr c} {
            lappend widths [expr {int([lindex $colWidthsPt $c] * $scale)}]
        }

        for {set iter 0} {$iter < $cols} {incr iter} {
            # Feststellen welche Spalten unter Minimum liegen
            set newFixed 0
            set fixedTotal 0
            set freeTotal  0
            for {set c 0} {$c < $cols} {incr c} {
                if {[lindex $fixed $c]} {
                    set fixedTotal [expr {$fixedTotal + [lindex $widths $c]}]
                } elseif {[lindex $widths $c] < [lindex $colMinPt $c]} {
                    lset fixed $c 1
                    lset widths $c [lindex $colMinPt $c]
                    set fixedTotal [expr {$fixedTotal + [lindex $widths $c]}]
                    incr newFixed
                } else {
                    set freeTotal [expr {$freeTotal + [lindex $colWidthsPt $c]}]
                }
            }
            if {$newFixed == 0} break
            # Freie Spalten auf verbleibenden Platz skalieren
            set remaining [expr {$maxW - $fixedTotal}]
            if {$remaining > 0 && $freeTotal > 0} {
                set s2 [expr {double($remaining) / $freeTotal}]
                for {set c 0} {$c < $cols} {incr c} {
                    if {![lindex $fixed $c]} {
                        lset widths $c [expr {int([lindex $colWidthsPt $c] * $s2)}]
                    }
                }
            } else {
                # Kein Platz mehr: alle freien Spalten auf Minimum
                for {set c 0} {$c < $cols} {incr c} {
                    if {![lindex $fixed $c]} {
                        lset widths $c [lindex $colMinPt $c]
                    }
                }
                break
            }
        }
        set colWidthsPt $widths
    }

    set tableW 0
    foreach cw $colWidthsPt { set tableW [expr {$tableW + $cw}] }

    set hasHeader 0
    foreach h $header {
        if {$h ne ""} { set hasHeader 1; break }
    }

    # Basis-Zeilenhoehe (single line) und Zeilenabstand fuer Wraparound
    set rowH     [expr {int($fontSize * 1.8)}]
    set cellLineH [expr {int($fontSize * 1.3)}]
    set cellTopPad [expr {int($fontSize * 0.85)}]

    # Pre-compute: Zeilen umbrechen und individuelle Zeilenhoehen berechnen
    # wrappedRows: Liste von Zeilen, jede Zeile ist Liste von Zellen,
    #              jede Zelle ist Liste von Textzeilen nach dem Umbrechen
    set wrappedRows {}
    set rowHeights {}
    set ri 0
    foreach row $rows {
        set wrappedRow {}
        set maxLines 1
        for {set c 0} {$c < $cols} {incr c} {
            if {$hasInlines} {
                set cellText [mdpdf::_inlineListToText                             [lindex [lindex [dict get $block rowsInlines] $ri] $c]]
            } else {
                set cellText [string trim [lindex $row $c]]
            }
            set colW [lindex $colWidthsPt $c]
            set cellMaxW [expr {$colW - 2 * $cellPad}]
            set lines [::pdf4tcllib::text::wrap $cellText $cellMaxW $fontSize $fontSans]
            if {[llength $lines] == 0} { set lines [list ""] }
            lappend wrappedRow $lines
            if {[llength $lines] > $maxLines} {
                set maxLines [llength $lines]
            }
        }
        lappend wrappedRows $wrappedRow
        # Zeilenhoehe: single line = rowH, jede weitere Zeile + cellLineH
        lappend rowHeights [expr {$rowH + ($maxLines - 1) * $cellLineH}]
        incr ri
    }

    # Tabelle beginnen: ggf. Seite wechseln wenn kein Platz
    # (mind. Header + 1 Datenzeile muss passen)
    set firstRowH [expr {[llength $rowHeights] > 0 ? [lindex $rowHeights 0] : $rowH}]
    set minH [expr {$hasHeader ? $rowH + $firstRowH : $firstRowH}]
    if {$y + $minH > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }

    # Segment-Tracking: vertikale Linien per Seite
    set segTopY $y

    if {$hasHeader} {
        set y [mdpdf::_drawTableHeader $pdf $x0 $y $tableW $colWidthsPt \
            $alignments $fontSize $fontBold \
            $cellPad $cellTopPad $rowH $cellLineH $hasInlines $block $header]
    } else {
        # Oberer Rand (keine Header-Zeile)
        $pdf setStrokeColor 0.4 0.4 0.4
        $pdf setLineWidth 0.5
        $pdf line $x0 $segTopY [expr {$x0 + $tableW}] $segTopY
    }

    set rowIdx 0
    foreach wrappedRow $wrappedRows {
        set thisRowH [lindex $rowHeights $rowIdx]

        if {$y + $thisRowH > $yBot} {
            # Segment abschliessen: untere Linie + vertikale Linien
            $pdf setStrokeColor 0.7 0.7 0.7
            $pdf setLineWidth 0.3
            $pdf line $x0 $y [expr {$x0 + $tableW}] $y
            mdpdf::_drawTableVLines $pdf $x0 $segTopY $y $colWidthsPt

            # Neue Seite + ggf. Header wiederholen
            mdpdf::_tablePageBreak $pdf pageNo y $yTop $pageW $pageH $margin \
                $fontSize $footerTemplate $headerTemplate \
                $hasHeader $x0 $tableW $colWidthsPt $alignments \
                $cellPad $cellTopPad $rowH $cellLineH $hasInlines $block $header

            set segTopY $y
        }

        set x $x0
        $pdf setFont $fontSize $fontSans
        for {set c 0} {$c < $cols} {incr c} {
            set lines [lindex $wrappedRow $c]
            set colW [lindex $colWidthsPt $c]
            set align [lindex $alignments $c]
            set lineY [expr {$y + $cellTopPad}]
            foreach ln $lines {
                set textW [::pdf4tcllib::text::width $ln $fontSize $fontSans]
                switch -- $align {
                    right  { set cellX [expr {$x + $colW - $cellPad - $textW}] }
                    center { set cellX [expr {$x + ($colW - $textW) / 2}] }
                    default { set cellX [expr {$x + $cellPad}] }
                }
                $pdf text [::pdf4tcllib::unicode::sanitize $ln] -x $cellX -y $lineY
                set lineY [expr {$lineY + $cellLineH}]
            }
            set x [expr {$x + $colW}]
        }
        set y [expr {$y + $thisRowH}]
        incr rowIdx

        $pdf setStrokeColor 0.7 0.7 0.7
        $pdf setLineWidth 0.3
        $pdf line $x0 $y [expr {$x0 + $tableW}] $y
    }

    # Letztes Segment abschliessen: vertikale Linien
    mdpdf::_drawTableVLines $pdf $x0 $segTopY $y $colWidthsPt

    $pdf setStrokeColor 0 0 0
    $pdf setLineWidth 1.0
    set y [expr {$y + $lineH * 0.5}]
    return $y
}

proc mdpdf::_render_image {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    set url [dict get $block url]
    set alt [dict get $block alt]

    set imgPath ""
    if {$root ne "" && ![string match "/*" $url] && ![string match "?:*" $url]} {
        set imgPath [file join $root $url]
    } else {
        set imgPath $url
    }

    set imgH 100
    if {$y + $imgH > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }

    set fontSans [::pdf4tcllib::fonts::fontSans]

    if {[catch {package require Tk} err] == 0} {
        if {[file exists $imgPath]} {
            set ext [string tolower [file extension $imgPath]]
            if {$ext in {.png .gif .jpg .jpeg}} {
                if {[catch {
                    if {$ext eq ".jpg" || $ext eq ".jpeg"} {
                        package require Img
                    }
                    set imgName "mdpdf_img_[clock seconds]_[incr ::mdpdf::imgCounter]"
                    image create photo $imgName -file $imgPath

                    set imgW [image width $imgName]
                    set imgH [image height $imgName]

                    if {$imgW > $maxW} {
                        set scale [expr {double($maxW) / $imgW}]
                        set imgW $maxW
                        set imgH [expr {int($imgH * $scale)}]
                    }

                    if {$y + $imgH > $yBot} {
                        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                            $footerTemplate $headerTemplate
                    }

                    $pdf setFont $fontSize $fontSans
                    $pdf text "\[$alt\]" -x $x0 -y $y
                    set y [expr {$y + $lineH}]

                    image delete $imgName
                } err]} {
                    $pdf setFont $fontSize $fontSans
                    $pdf text "\[$alt\]" -x $x0 -y $y
                    set y [expr {$y + $lineH}]
                }
            } else {
                $pdf setFont $fontSize $fontSans
                $pdf text "\[$alt\]" -x $x0 -y $y
                set y [expr {$y + $lineH}]
            }
        } else {
            $pdf setFont $fontSize $fontSans
            $pdf text "\[$alt\]" -x $x0 -y $y
            set y [expr {$y + $lineH}]
        }
    } else {
        $pdf setFont $fontSize $fontSans
        $pdf text "\[$alt\]" -x $x0 -y $y
        set y [expr {$y + $lineH}]
    }
    return $y
}

proc mdpdf::_render_div {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    # Fenced div ::: .class ... ::: (Pandoc/TIP 700)
    foreach subBlock [dict get $block blocks] {
        set y [mdpdf::_renderBlock $pdf $rctx $subBlock $y $x0 $maxW $yTop $yBot pageNo $quoteDepth]
    }
    return $y
}

proc mdpdf::_render_footnote_section {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    # Separator line
    set y [expr {$y + $lineH * 0.5}]
    if {$y + $lineH * 3 > $yBot} {
        mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
            $footerTemplate $headerTemplate
    }
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.5
    $pdf line $x0 $y [expr {$x0 + $maxW * 0.4}] $y
    $pdf setStrokeColor 0 0 0
    # Genug Abstand: Linie muss ueber dem Ascender liegen
    # Ascender ~ 0.75*fnFontSize; lineH*0.75 sichert ausreichend Platz
    set y [expr {$y + int($lineH * 0.75)}]

    set fnFontSize [expr {$fontSize - 1}]
    set fnLineH [expr {$fnFontSize * 1.4}]
    foreach fn [dict get $block footnotes] {
        set fnNum [dict get $fn num]
        set fnText [mdpdf::_inlineListToText [dict get $fn content]]

        if {$y + $fnLineH > $yBot} {
            mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                $footerTemplate $headerTemplate
        }

        set prefix "$fnNum. "
        set fontSans [::pdf4tcllib::fonts::fontSans]
        set fontBold [::pdf4tcllib::fonts::fontSansBold]
        $pdf setFont $fnFontSize $fontBold
        $pdf text $prefix -x $x0 -y $y
        set prefixW [::pdf4tcllib::text::width $prefix $fnFontSize $fontBold]

        $pdf setFont $fnFontSize $fontSans
        set fnText [::pdf4tcllib::unicode::sanitize $fnText]
        $pdf text $fnText -x [expr {$x0 + $prefixW}] -y $y
        set y [expr {$y + $fnLineH}]
    }
    $pdf setFont $fontSize [::pdf4tcllib::fonts::fontSans]
    return $y
}

proc mdpdf::_render_deflist {pdf rctx block y x0 maxW yTop yBot pageNoVar quoteDepth} {
    upvar $pageNoVar pageNo
    set pageW          [dict get $rctx pageW]
    set pageH          [dict get $rctx pageH]
    set margin         [dict get $rctx margin]
    set fontSize       [dict get $rctx fontSize]
    set root           [dict get $rctx root]
    set debug          [dict get $rctx debug]
    set footerTemplate [dict get $rctx footerTemplate]
    set headerTemplate [dict get $rctx headerTemplate]
    set lineH [expr {int(ceil($fontSize * 1.4))}]
    # Definition List: Term (bold) + Definitionen (eingerückt)
    set dlIndent [expr {$x0 + 16}]
    set dlMaxW   [expr {$maxW - 16}]
    foreach dlItem [dict get $block items] {
        # Term
        if {$y + $lineH > $yBot} {
            mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                $footerTemplate $headerTemplate
        }
        set termSegs [mdpdf::_inlinesToSegments [dict get $dlItem term] "bold"]
        set termLines [mdpdf::_wrapStyledSegments $termSegs $maxW $fontSize]
        foreach lineSegs $termLines {
            mdpdf::_renderStyledLine $pdf $lineSegs $y $x0 $fontSize
            set y [expr {$y + $lineH}]
        }
        # Definitionen (eingerückt mit Doppelpunkt-Prefix)
        foreach defInlines [dict get $dlItem definitions] {
            if {$y + $lineH > $yBot} {
                mdpdf::_newPage $pdf pageNo y $yTop $pageW $pageH $margin $fontSize \
                    $footerTemplate $headerTemplate
            }
            set defSegs [mdpdf::_inlinesToSegments $defInlines "normal"]
            set defLines [mdpdf::_wrapStyledSegments $defSegs $dlMaxW $fontSize]
            foreach lineSegs $defLines {
                mdpdf::_renderStyledLine $pdf $lineSegs $y $dlIndent $fontSize
                set y [expr {$y + $lineH}]
            }
        }
        set y [expr {$y + int($lineH * 0.3)}]
    }
    return $y
}
proc mdpdf::_inlinesToPlainText {block} {
    set result ""
    if {![dict exists $block content]} { return $result }
    return [mdpdf::_inlineListToText [dict get $block content]]
}

# Inline-Liste -> Plain-Text (for table cells from headerInlines/rowsInlines)
proc mdpdf::_inlineListToText {inlines} {
    set result ""
    foreach inline $inlines {
        set type [dict get $inline type]
        switch $type {
            text {
                append result [dict get $inline value]
            }
            strong - emphasis - strike - span {
                if {[dict exists $inline content]} {
                    append result [mdpdf::_inlineListToText [dict get $inline content]]
                } elseif {[dict exists $inline value]} {
                    append result [dict get $inline value]
                }
            }
            inline_code {
                if {[dict exists $inline value]} {
                    append result [dict get $inline value]
                }
            }
            link {
                if {[dict exists $inline label]} {
                    append result [mdpdf::_inlineListToText [dict get $inline label]]
                }
            }
            image {
                if {[dict exists $inline alt]} {
                    append result [dict get $inline alt]
                }
            }
            footnote_ref {
                append result "\[[dict get $inline id]\]"
            }
            linebreak {
                append result " "
            }
            default {
                if {[dict exists $inline value]} {
                    append result [dict get $inline value]
                } elseif {[dict exists $inline content]} {
                    append result [mdpdf::_inlineListToText [dict get $inline content]]
                }
            }
        }
    }
    return $result
}

# ============================================================
# Inline -> Styled Segments (for Paragraph, List)
# ============================================================

proc mdpdf::_inlinesToSegments {inlines {parentStyle normal}} {
    set segs {}

    foreach inline $inlines {
        set type [dict get $inline type]
        switch $type {
            text {
                lappend segs [list [dict get $inline value] $parentStyle]
            }
            strong {
                set s [expr {$parentStyle in {italic bolditalic} ? "bolditalic" : "bold"}]
                if {[dict exists $inline content]} {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] $s]
                } elseif {[dict exists $inline value]} {
                    lappend segs [list [dict get $inline value] $s]
                }
            }
            emphasis {
                set s [expr {$parentStyle in {bold bolditalic} ? "bolditalic" : "italic"}]
                if {[dict exists $inline content]} {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] $s]
                } elseif {[dict exists $inline value]} {
                    lappend segs [list [dict get $inline value] $s]
                }
            }
            inline_code {
                set t ""
                if {[dict exists $inline value]} { set t [dict get $inline value] }
                lappend segs [list $t "code"]
            }
            strike {
                if {[dict exists $inline content]} {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] "strike"]
                } elseif {[dict exists $inline value]} {
                    lappend segs [list [dict get $inline value] "strike"]
                }
            }
            span {
                # Bracketed span [content] .class (Pandoc/TIP 700)
                set cls [dict get $inline class]
                if {$cls in {cmd sub lit optlit ccmd}} {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] "bold"]
                } elseif {$cls in {arg optarg optdot ins cargs}} {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] "italic"]
                } else {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] $parentStyle]
                }
            }
            link {
                if {[dict exists $inline label]} {
                    set url ""
                    if {[dict exists $inline url]} {
                        set url [dict get $inline url]
                    }
                    # Label-Text als klickbares Segment mit URL als drittes Element
                    set labelSegs [mdpdf::_inlinesToSegments \
                        [dict get $inline label] $parentStyle]
                    foreach s $labelSegs {
                        lassign $s t st
                        lappend segs [list $t $st $url]
                    }
                }
                # URL in Grau dahinter nicht mehr nötig -- Hyperlink ersetzt das
                # Nur noch anzeigen wenn URL == Label (pure URL im Text)
                if {[dict exists $inline url]} {
                    set url [dict get $inline url]
                    set labelText [mdpdf::_inlineListToText \
                        [expr {[dict exists $inline label] ? [dict get $inline label] : {}}]]
                    if {$url eq $labelText && $url ne ""} {
                        lappend segs [list $url "url" $url]
                    }
                }
            }
            image {
                set alt "Bild"
                if {[dict exists $inline alt]} { set alt [dict get $inline alt] }
                lappend segs [list "\[$alt\]" $parentStyle]
            }
            linebreak {
                lappend segs [list "\n" "break"]
            }
            default {
                if {[dict exists $inline value]} {
                    lappend segs [list [dict get $inline value] $parentStyle]
                } elseif {[dict exists $inline content]} {
                    lappend segs {*}[mdpdf::_inlinesToSegments [dict get $inline content] $parentStyle]
                }
            }
        }
    }
    return $segs
}

proc mdpdf::_wrapStyledSegments {segments maxW fontSize} {
    # Wraps styled segments into lines.
    # Segment format: {text style ?url?}  -- url wird durchgereicht.

    # 1. Split segments into words with style + url info
    set words {}
    set prevTrailing 0

    foreach seg $segments {
        set text  [lindex $seg 0]
        set style [lindex $seg 1]
        set url   [lindex $seg 2]
        if {$style eq "break"} {
            lappend words [list "\n" "break" 0 ""]
            set prevTrailing 0
            continue
        }
        if {$text eq ""} continue

        set hasLeading  [expr {[string index $text 0] eq " "}]
        set hasTrailing [expr {[string index $text end] eq " "}]
        set text [string trim $text]
        if {$text eq ""} {
            set prevTrailing 1
            continue
        }

        set parts [split $text " "]
        for {set i 0} {$i < [llength $parts]} {incr i} {
            set w [lindex $parts $i]
            if {$w eq ""} continue
            if {$i == 0} {
                set spaced [expr {$hasLeading || $prevTrailing}]
            } else {
                set spaced 1
            }
            # Kein Leerzeichen vor Satzzeichen
            if {[string index $w 0] in {, . : ; ! ? )}} {
                set spaced 0
            }
            lappend words [list $w $style $spaced $url]
        }

        set prevTrailing $hasTrailing
    }

    if {[llength $words] == 0} {
        return [list [list [list "" "normal" ""]]]
    }

    # 2. Accumulate words into lines
    set lines {}
    set curLine {}
    set curWidth 0.0
    set fontSans [::pdf4tcllib::fonts::fontSans]
    set spaceW [::pdf4tcllib::text::width " " $fontSize $fontSans]

    foreach wordInfo $words {
        set word   [lindex $wordInfo 0]
        set style  [lindex $wordInfo 1]
        set spaced [lindex $wordInfo 2]
        set url    [lindex $wordInfo 3]

        if {$style eq "break"} {
            if {[llength $curLine] == 0} {
                lappend lines [list [list "" "normal" ""]]
            } else {
                lappend lines $curLine
            }
            set curLine {}
            set curWidth 0.0
            continue
        }

        set fontName [mdpdf::_styleToFont $style]
        set wordW [::pdf4tcllib::text::width $word $fontSize $fontName]

        set needSpace [expr {[llength $curLine] > 0 && $spaced}]
        if {[llength $curLine] > 0 && !$spaced} {
            set needSpace 0
        } elseif {[llength $curLine] > 0} {
            set needSpace 1
        }
        set extraW [expr {$needSpace ? $spaceW : 0.0}]

        if {$curWidth + $extraW + $wordW > $maxW && [llength $curLine] > 0} {
            lappend lines $curLine
            set curLine [list [list $word $style $url]]
            set curWidth $wordW
        } else {
            set prefix [expr {$needSpace ? " " : ""}]

            if {[llength $curLine] > 0} {
                set lastSeg [lindex $curLine end]
                set lastStyle [lindex $lastSeg 1]
                set lastUrl   [lindex $lastSeg 2]
                # Nur zusammenfassen wenn style UND url identisch
                if {$lastStyle eq $style && $lastUrl eq $url} {
                    set curLine [lreplace $curLine end end \
                        [list "[lindex $lastSeg 0]${prefix}${word}" $style $url]]
                } else {
                    lappend curLine [list "${prefix}${word}" $style $url]
                }
            } else {
                lappend curLine [list $word $style $url]
            }
            set curWidth [expr {$curWidth + $extraW + $wordW}]
        }
    }

    if {[llength $curLine] > 0} {
        lappend lines $curLine
    }

    if {[llength $lines] == 0} {
        return [list [list [list "" "normal" ""]]]
    }

    return $lines
}

proc mdpdf::_renderStyledLine {pdf lineSegments y x0 fontSize} {
    # Renders a line of styled segments with font switching.
    # Segment format: {text style ?url?}
    # Wenn url vorhanden: nach dem Rendern hyperlinkAdd aufrufen.
    set x $x0
    foreach seg $lineSegments {
        set text  [lindex $seg 0]
        set style [lindex $seg 1]
        set url   [lindex $seg 2]
        if {$text eq ""} continue
        set fontName [mdpdf::_styleToFont $style]
        $pdf setFont $fontSize $fontName
        # url-Style in Grau (pure URL ohne Label)
        if {$style eq "url"} {
            $pdf setFillColor 0.4 0.4 0.4
        }
        set sanitized [::pdf4tcllib::unicode::sanitize $text]
        $pdf text $sanitized -x $x -y $y
        if {$style eq "url"} {
            $pdf setFillColor 0 0 0
        }
        # Echte Font-Breite fuer naechste x-Position
        set w [$pdf getStringWidth $sanitized]
        # Durchstreichlinie bei strike
        if {$style eq "strike"} {
            set strikeY [expr {$y - int($fontSize * 0.35)}]
            $pdf setLineWidth 0.6
            $pdf line $x $strikeY [expr {$x + $w}] $strikeY
        }
        # Klickbarer Hyperlink wenn URL vorhanden
        if {$url ne "" && ![string match "mailto:*" $url]} {
            set linkH [expr {int($fontSize * 1.1)}]
            set linkY [expr {$y - int($fontSize * 0.8)}]
            catch {
                $pdf hyperlinkAdd $x $linkY $w $linkH $url
            }
        }
        set x [expr {$x + $w}]
    }
}

# ============================================================
# TOC (Table of Contents)
# ============================================================

proc mdpdf::_renderTOC {pdf ast y x0 maxW fontSize debug} {
    set headings {}

    if {[dict exists $ast blocks]} {
        foreach block [dict get $ast blocks] {
            if {[dict exists $block type] && [dict get $block type] eq "heading"} {
                set level [dict get $block level]
                set text ""
                if {[dict exists $block content]} {
                    set text [mdpdf::_inlinesToPlainText $block]
                }
                if {$text ne ""} {
                    set text [::pdf4tcllib::unicode::sanitize $text]
                    lappend headings [list $level $text]
                } elseif {$debug} {
                    puts "mdpdf: Heading level $level has no text"
                    puts "  Block-Keys: [dict keys $block]"
                }
            }
        }
    }

    if {[llength $headings] == 0} {
        if {$debug} {
            puts "mdpdf: No headings found for TOC"
        }
        return $y
    }

    set lineH [expr {int(ceil($fontSize * 1.4))}]

    $pdf setFont [expr {$fontSize + 2}] [::pdf4tcllib::fonts::fontSansBold]
    $pdf text "Table of Contents" -x $x0 -y $y
    set y [expr {$y + 2 * $lineH}]

    foreach heading $headings {
        if {[llength $heading] >= 2} {
            set level [lindex $heading 0]
            set text [lindex $heading 1]
            set indent [expr {($level - 1) * 20}]
            set tocX [expr {$x0 + $indent}]

            $pdf setFont $fontSize [::pdf4tcllib::fonts::fontSans]
            $pdf text $text -x $tocX -y $y
            set y [expr {$y + $lineH}]
        }
    }

    return $y
}

# ============================================================
# Header / Footer
# ============================================================

# ------------------------------------------------------------
proc mdpdf::_newPage {pdf pageNoVar yVar yTop pageW pageH margin fontSize footerTemplate headerTemplate} {
    # Schliesst aktuelle Seite, startet neue mit Header/Footer.
    # Inkrementiert pageNo und setzt y auf yTop (beides per upvar).
    upvar $pageNoVar pageNo
    upvar $yVar      y
    mdpdf::_writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize $footerTemplate
    $pdf endPage
    incr pageNo
    $pdf startPage
    if {$headerTemplate ne ""} {
        mdpdf::_writeHeader $pdf $pageNo $pageW $pageH $margin $fontSize $headerTemplate
    }
    set y $yTop
}

proc mdpdf::_writeHeader {pdf pageNo pageW pageH margin fontSize headerTemplate} {
    set headerY [expr {$margin * 0.5}]
    set header [string map [list %p $pageNo] $headerTemplate]
    $pdf setFont [expr {$fontSize - 1}] [::pdf4tcllib::fonts::fontSans]
    $pdf text [::pdf4tcllib::unicode::sanitize $header] -x $margin -y $headerY
}

proc mdpdf::_writeFooter {pdf pageNo pageW pageH margin fontSize footerTemplate} {
    set footerY [expr {$pageH - $margin * 0.5}]
    set footerX [expr {$pageW - $margin}]
    set footer [string map [list %p $pageNo] $footerTemplate]
    $pdf setFont [expr {$fontSize - 2}] [::pdf4tcllib::fonts::fontSans]
    $pdf text [::pdf4tcllib::unicode::sanitize $footer] -x $footerX -y $footerY -align right
}

# ============================================================
# Tablen-Helper
# ============================================================

# ============================================================
# Tabellen-Helper (Issue 8: Seitenumbruch)
# ============================================================

proc mdpdf::_drawTableHeader {pdf x0 y tableW colWidthsPt alignments
                               fontSize fontBold cellPad cellTopPad rowH cellLineH
                               hasInlines block header} {
    # Obere Linie + Header-Zeile (mit Wrapping) + Trennlinie zeichnen.
    # Gibt neue y-Position (nach dem Header) zurueck.
    $pdf setStrokeColor 0.4 0.4 0.4
    $pdf setLineWidth 0.5
    $pdf line $x0 $y [expr {$x0 + $tableW}] $y

    set cols [llength $header]

    # Texte umbrechen und maximale Zeilenanzahl ermitteln
    set wrappedCells {}
    set maxLines 1
    for {set c 0} {$c < $cols} {incr c} {
        if {$hasInlines} {
            set cellText [mdpdf::_inlineListToText \
                [lindex [dict get $block headerInlines] $c]]
        } else {
            set cellText [lindex $header $c]
        }
        set colW [lindex $colWidthsPt $c]
        set cellMaxW [expr {$colW - 2 * $cellPad}]
        set lines [::pdf4tcllib::text::wrap $cellText $cellMaxW $fontSize $fontBold]
        if {[llength $lines] == 0} { set lines [list ""] }
        lappend wrappedCells $lines
        if {[llength $lines] > $maxLines} { set maxLines [llength $lines] }
    }
    set thisRowH [expr {$rowH + ($maxLines - 1) * $cellLineH}]

    $pdf setFont $fontSize $fontBold
    set x $x0
    for {set c 0} {$c < $cols} {incr c} {
        set lines [lindex $wrappedCells $c]
        set colW  [lindex $colWidthsPt $c]
        set align [lindex $alignments $c]
        set lineY [expr {$y + $cellTopPad}]
        foreach ln $lines {
            set textW [::pdf4tcllib::text::width $ln $fontSize $fontBold]
            switch -- $align {
                right  { set cellX [expr {$x + $colW - $cellPad - $textW}] }
                center { set cellX [expr {$x + ($colW - $textW) / 2}] }
                default { set cellX [expr {$x + $cellPad}] }
            }
            $pdf text [::pdf4tcllib::unicode::sanitize $ln] -x $cellX -y $lineY
            set lineY [expr {$lineY + $cellLineH}]
        }
        set x [expr {$x + $colW}]
    }
    set newY [expr {$y + $thisRowH}]
    $pdf setStrokeColor 0.3 0.3 0.3
    $pdf setLineWidth 1.0
    $pdf line $x0 $newY [expr {$x0 + $tableW}] $newY
    return $newY
}

proc mdpdf::_drawTableVLines {pdf x0 segTopY segBotY colWidthsPt} {
    # Vertikale Spaltenlinien fuer ein Tabellensegment (eine Seite).
    set tableW 0
    foreach cw $colWidthsPt { set tableW [expr {$tableW + $cw}] }
    $pdf setStrokeColor 0.4 0.4 0.4
    $pdf setLineWidth 0.5
    $pdf line $x0 $segTopY $x0 $segBotY
    set x $x0
    foreach cw $colWidthsPt {
        set x [expr {$x + $cw}]
        $pdf line $x $segTopY $x $segBotY
    }
}

proc mdpdf::_tablePageBreak {pdf pageNoVar yVar yTop pageW pageH margin
                              fontSize footerTemplate headerTemplate
                              hasHeader x0 tableW colWidthsPt alignments
                              cellPad cellTopPad rowH cellLineH hasInlines block header} {
    # Seitenumbruch innerhalb einer Tabelle.
    # Schliesst aktuelle Seite, startet neue, wiederholt ggf. den Header.
    upvar $pageNoVar pageNo
    upvar $yVar y

    mdpdf::_writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize $footerTemplate
    $pdf endPage
    incr pageNo
    $pdf startPage
    if {$headerTemplate ne ""} {
        mdpdf::_writeHeader $pdf $pageNo $pageW $pageH $margin $fontSize $headerTemplate
    }
    set y $yTop

    if {$hasHeader} {
        set y [mdpdf::_drawTableHeader $pdf $x0 $y $tableW $colWidthsPt \
            $alignments $fontSize [::pdf4tcllib::fonts::fontSansBold] \
            $cellPad $cellTopPad $rowH $cellLineH $hasInlines $block $header]
    } else {
        # Oberer Rand fuer headerlose Folgeseite
        $pdf setStrokeColor 0.4 0.4 0.4
        $pdf setLineWidth 0.5
        $pdf line $x0 $y [expr {$x0 + $tableW}] $y
    }
}

proc mdpdf::_maxWordWidth {text fontSize fontName} {
    # Longest single-word pixel width in text (for minimum column width).
    set maxW 0
    foreach word [split $text " "] {
        set w [::pdf4tcllib::text::width $word $fontSize $fontName]
        if {$w > $maxW} { set maxW $w }
    }
    return $maxW
}

proc mdpdf::_truncateToWidth {text maxW fontSize fontName} {
    set tw [::pdf4tcllib::text::width $text $fontSize $fontName]
    if {$tw <= $maxW} { return $text }
    set dotsW [::pdf4tcllib::text::width "..." $fontSize $fontName]
    set target [expr {$maxW - $dotsW}]
    if {$target <= 0} { return "..." }
    # Binary search for fitting length
    set lo 0
    set hi [string length $text]
    while {$lo < $hi} {
        set mid [expr {($lo + $hi + 1) / 2}]
        set tw [::pdf4tcllib::text::width [string range $text 0 $mid-1] $fontSize $fontName]
        if {$tw <= $target} { set lo $mid } else { set hi [expr {$mid - 1}] }
    }
    return "[string range $text 0 $lo-1]..."
}
