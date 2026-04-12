# mdviewer-0.3.tm
#
# Tk widget to render Markdown-AST v1.
#
# Changes v0.3.8 -> v0.3.9:
# - Named Fonts: All font assignments via font create/configure
#   * Eliminates font ambiguity risk (family names with spaces)
#   * setFontSize reduced from ~60 to ~20 lines (font configure propagates)
#   * Per-instance font prefix for independent fontsize per viewer
#   * Automatic font cleanup on widget destroy
# - Spacing Tags: Typographic spacing for headings
#   * h1–h6 with proportional spacing1/spacing3 for visual hierarchy
#   * hr with symmetric spacing
#   * New block-level tags: para, listblock, tableblock (for future use)
#   * Multiline blocks (table, code, list) use \n gap — spacing
#     would break vertical frames / add per-line gaps
# - -insertwidth 0: Cursor hidden in readonly viewer
# - -exportselection 0: Safe for multi-panel use (NotesKit)
# - Tag creation order determines priority (Tablelist pattern)
#   * Reduced tag raise calls from 9 to 3
#   * Only dynamic quote_dN tags still need raise
# - Image cleanup: track all images, delete on clear (fixes memory leak)
# - Scroll-to-top after render (mark set insert 1.0 + yview moveto 0)
# - Codeblock margins (lmargin1/2, rmargin)
# - Code language label (codelabel tag above codeblock)
# - Task list: checked items rendered in grey (taskdone tag)
# - Image alt-text caption below loaded images (imgcaption tag)
# - SVG support via optional tksvg package
# - PDF link detection: [PDF] prefix, pdflink tag, -onpdf callback
# - URL resolution: resolveUrl resolves relative URLs against -root
# - Frame-based tables: -tablemode frame for embedded widget tables
#   * Proportional fonts, zebra stripes, clickable links in cells
#   * Images in cells, alignment via -anchor
#
# Changes v0.2 -> v0.3:
# - ttk::frame + ttk::scrollbar (Regelbuch §3.1)
# - Hard line break support (inline:linebreak)
# - Nested blockquotes (recursive block rendering, italic text)
# - Link hover effects (underline on mouse-over)
# - Anchor-Navigation: gotoAnchor, anchors, #-Link dispatch
# - Fontsize: setFontSize, -fontsize option, proportional scaling
#
# Options:
# -onlink   cmdPrefix   called with one argument (url) on link click
# -onclick  cmdPrefix   called with (x y index tags lineText) on click anywhere
# -root     path        base path for relative image URLs
# -fontsize int         base font size (default 10), scales all tags
#
# API:
#   mdviewer::gotoAnchor $path $anchor  → scrolls to heading anchor (1/0)
#   mdviewer::anchors $path             → list of all anchor names
#   mdviewer::setFontSize $path $size   → reconfigure all tag fonts
#
package require Tk
package provide mdviewer 0.3

namespace eval mdviewer {
    namespace export create widget clear render renderModel configure cget \
        gotoAnchor anchors setFontSize
    variable state
    array set state {}
}

proc mdviewer::create {path args} {
    variable state

    ttk::frame $path
    text $path.t -wrap word -insertwidth 0 -exportselection 0 \
        -yscrollcommand [list $path.sb set]
    ttk::scrollbar $path.sb -command [list $path.t yview]

    grid $path.t  -row 0 -column 0 -sticky nsew
    grid $path.sb -row 0 -column 1 -sticky ns
    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1

    set state($path,text) $path.t
    set state($path,linkCounter) 0
    set state($path,imgCounter) 0
    set state($path,images) {}
    set state($path,quoteDepth) 0
    set state($path,renderContext) "normal"
    set state($path,tableBaseTag) "tablecell"
    set state($path,root) ""
    set state($path,onlink) ""
    set state($path,onhover) ""
    set state($path,onpdf) ""
    set state($path,onclick) ""
    set state($path,fontsize) 10
    set state($path,tablemode) "text"
    set state($path,tableCounter) 0

    # Create named fonts (per instance, for independent font size)
    set fp [mdviewer::fontPrefix $path]
    set state($path,fontPrefix) $fp
    mdviewer::initFonts $path 10

    mdviewer::initTags $path.t $fp
    
    # Clickable tag for onclick callback
    # ButtonRelease-1 so link handlers (Button-1) can fire first
    $path.t tag configure clickable
    $path.t tag bind clickable <ButtonRelease-1> [list mdviewer::dispatchClick $path %x %y]
    
    mdviewer::configure $path {*}$args

    # Font cleanup when widget is destroyed
    bind $path <Destroy> [list mdviewer::deleteFonts $path]

    return $path
}

proc mdviewer::widget {path} {
    variable state
    return $state($path,text)
}

proc mdviewer::configure {path args} {
    variable state
    if {[llength $args] == 0} { return }
    if {[llength $args] % 2 != 0} { error "mdviewer::configure: expected key value pairs" }

    foreach {k v} $args {
        switch -- $k {
            -onlink   { set state($path,onlink) $v }
            -onhover  { set state($path,onhover) $v }
            -onpdf    { set state($path,onpdf) $v }
            -onclick  { set state($path,onclick) $v }
            -root     { set state($path,root) $v }
            -fontsize  { mdviewer::setFontSize $path $v }
            -tablemode { set state($path,tablemode) $v }
            default    { error "mdviewer::configure: unknown option $k" }
        }
    }
}

proc mdviewer::cget {path option} {
    variable state
    switch -- $option {
        -onlink   { return $state($path,onlink) }
        -onhover  { return $state($path,onhover) }
        -onpdf    { return $state($path,onpdf) }
        -onclick  { return $state($path,onclick) }
        -root     { return $state($path,root) }
        -fontsize  { return $state($path,fontsize) }
        -tablemode { return $state($path,tablemode) }
        default    { error "mdviewer::cget: unknown option $option" }
    }
}

proc mdviewer::clear {path} {
    variable state
    set t [mdviewer::widget $path]
    $t configure -state normal
    # Remove anchor marks (otherwise remain after delete)
    foreach m [$t mark names] {
        if {[string match "anchor_*" $m]} {
            $t mark unset $m
        }
    }
    $t delete 1.0 end
    $t configure -state disabled
    mdviewer::clearDynamicLinkTags $path
    # Image cleanup — delete all Tk images of this instance
    foreach img $state($path,images) {
        catch {image delete $img}
    }
    set state($path,images) {}
    set state($path,quoteDepth) 0
}

proc mdviewer::render {path ast} {
    mdviewer::assertAst $ast
    mdviewer::clear $path

    set t [mdviewer::widget $path]
    $t configure -state normal

    foreach block [dict get $ast blocks] {
        mdviewer::renderBlock $path $block
        $t insert end "\n"
    }

    # Apply clickable tag to entire content (for -onclick callback)
    $t tag add clickable 1.0 end
    
    $t configure -state disabled

    # Scroll to top after rendering
    $t mark set insert 1.0
    $t yview moveto 0
}

proc mdviewer::renderModel {path doc} {
    mdviewer::render $path [dict get $doc ast]
}

proc mdviewer::renderBlock {path block} {
    set t [mdviewer::widget $path]
    set type [dict get $block type]

    switch -- $type {
        heading {
            set level [dict get $block level]
            set tag "h$level"
            # Anchor mark for navigation
            if {[dict exists $block anchor]} {
                set anchor [dict get $block anchor]
                $t mark set "anchor_$anchor" "end -1 chars"
                $t mark gravity "anchor_$anchor" left
            }
            # Inline-Formatierung in Headings (bold, italic, code etc.)
            set start [$t index "end -1 chars"]
            mdviewer::renderInlines $path [dict get $block content]
            $t insert end "\n"
            $t tag add $tag $start "end -1 chars"
        }
        paragraph {
            set paraStart [$t index "end -1 chars"]
            mdviewer::renderInlines $path [dict get $block content]
            $t insert end "\n"
            $t tag add para $paraStart "end -1 chars"
        }
        list {
            set ordered [expr {[dict get $block style] eq "ordered"}]
            set idx 1
            set listStart [$t index "end -1 chars"]
            foreach item [dict get $block items] {
                # Task List Support
                if {[dict exists $item checked]} {
                    set checked [dict get $item checked]
                    set check [expr {$checked ? "☑" : "☐"}]
                    set prefix "$check "
                } elseif {$ordered} {
                    set prefix "${idx}. "
                    set checked -1
                } else {
                    set prefix "• "
                    set checked -1
                }
                $t insert end $prefix listprefix
                set itemStart [$t index "end -1 chars"]
                # Render item blocks (first paragraph inline, rest as blocks)
                set first 1
                foreach subBlock [dict get $item blocks] {
                    set subType [dict get $subBlock type]
                    if {$first && $subType eq "paragraph"} {
                        mdviewer::renderInlines $path [dict get $subBlock content]
                        set first 0
                    } else {
                        $t insert end "\n"
                        mdviewer::renderBlock $path $subBlock
                        set first 0
                    }
                }
                # Checked Tasks: Text durchgestrichen + grau
                if {$checked == 1} {
                    $t tag add taskdone $itemStart "end -1 chars"
                }
                $t insert end "\n"
                incr idx
            }
            $t tag add listblock $listStart "end -1 chars"
        }
        code_block {
            if {[dict exists $block language] && [dict get $block language] ne ""} {
                $t insert end "[dict get $block language]\n" codelabel
            }
            set codeStart [$t index "end - 1 char"]
            $t insert end "[dict get $block text]\n" codeblock
            set codeEnd [$t index "end - 1 char"]
            # Syntax-Highlighting anwenden
            set lang ""
            if {[dict exists $block language]} {
                set lang [dict get $block language]
            }
            if {$lang ne ""} {
                mdviewer::highlightCode $t $codeStart $codeEnd $lang
            }
        }
        hr {
            $t insert end "────────────────────────────────────────\n" hr
        }
        blockquote {
            variable state
            if {[dict exists $block blocks]} {
                # Recursive format: sub-blocks with full formatting
                set depth $state($path,quoteDepth)
                incr state($path,quoteDepth)
                # Set context to quote for context-dependent tags
                set prevCtx $state($path,renderContext)
                set state($path,renderContext) "quote"

                set qtag "quote_d${depth}"
                set ptag "quoteprefix_d${depth}"
                set baseIndent [expr {10 + $depth * 20}]
                set fp $state($path,fontPrefix)
                $t tag configure $qtag \
                    -lmargin1 $baseIndent -lmargin2 $baseIndent \
                    -font ${fp}_italic
                $t tag configure $ptag \
                    -foreground #999999

                # Mark the overall blockquote start (right gravity = default;
                # mark stays LEFT of newly inserted text, i.e. at the start)
                $t mark set _bqAll end

                set subBlocks [dict get $block blocks]
                set numSubs   [llength $subBlocks]
                set subIdx    0

                foreach subBlock $subBlocks {
                    # Mark where this sub-block will begin.
                    # Default (right) gravity: mark stays at the START
                    # of whatever renderBlock inserts after it.
                    $t mark set _bqSub end

                    mdviewer::renderBlock $path $subBlock

                    # _bqSub → first char of new content (mark didn't move)
                    # end-1c → last char of new content (the trailing \n)
                    set firstLine [lindex [split [$t index _bqSub] .] 0]
                    set lastLine  [lindex [split [$t index "end-1c"] .] 0]

                    # Insert "│ " at start of every rendered line
                    # (backwards iteration keeps line numbers stable)
                    for {set ln $lastLine} {$ln >= $firstLine} {incr ln -1} {
                        $t insert "$ln.0" "│ " $ptag
                    }

                    # No extra spacer between sub-blocks - Paragraphs already have \n
                    incr subIdx
                }

                # Apply margin tag to entire blockquote
                set bqStartIdx [$t index _bqAll]
                set bqEndIdx   [$t index "end-1c"]
                $t tag add $qtag $bqStartIdx $bqEndIdx

                # IMPORTANT: Remove quote_d tag from format tag ranges,
                # since format tags (strong_q, em_q) already contain the font properties
                # strong_q hat bereits bold+italic, em_q hat bereits italic
                foreach ctxTag {strong_q em_q strike_q} {
                    set ranges [$t tag ranges $ctxTag]
                    foreach {start end} $ranges {
                        if {$start ne "" && $end ne ""} {
                            $t tag remove $qtag $start $end
                        }
                    }
                }

                # Raise context-aware inline tags above quote margin
                # IMPORTANT: After each blockquote rendering, to preserve priorities
                foreach fmtTag {strong_q em_q strike_q codeinline codeblock link
                                h1 h2 h3 h4 h5 h6 listprefix} {
                    catch {$t tag raise $fmtTag $qtag}
                }
                # Additionally: context tags over all quote_d tags
                foreach ctxTag {strong_q em_q strike_q} {
                    for {set d 0} {$d < 5} {incr d} {
                        catch {$t tag raise $ctxTag "quote_d$d"}
                    }
                }

                set state($path,quoteDepth) $depth
                set state($path,renderContext) $prevCtx
            }
        }
        image {
            set alt [dict get $block alt]
            set url [dict get $block url]
            set imgStart [$t index "end -1 chars"]
            # Versuche Bild zu laden
            if {[mdviewer::loadImage $path $url img]} {
                $t image create end -image $img -padx 5 -pady 5
                if {$alt ne ""} {
                    $t insert end "\n"
                    $t insert end $alt imgcaption
                }
                $t insert end "\n"
            } else {
                $t insert end "\[Bild: $alt\]\n" imageblock
            }
            $t tag add imageblock $imgStart "end -1 chars"
        }
        table {
            variable state
            if {$state($path,tablemode) eq "frame"} {
                mdviewer::renderTableFrame $path $block
            } else {
                set tableStart [$t index "end -1 chars"]
                mdviewer::renderTable $path $block
                $t tag add tableblock $tableStart "end -1 chars"
            }
        }
        deflist {
            foreach item [dict get $block items] {
                # Term (bold)
                set termStart [$t index end]
                mdviewer::renderInlines $path [dict get $item term]
                set termEnd [$t index end]
                $t tag add defterm $termStart $termEnd
                $t insert end "\n"

                # Definitions (indented)
                foreach def [dict get $item definitions] {
                    set defStart [$t index end]
                    mdviewer::renderInlines $path $def
                    set defEnd [$t index end]
                    $t tag add defdef $defStart $defEnd
                    $t insert end "\n"
                }
            }
        }
        div {
            # Fenced div ::: .class ... ::: (Pandoc/TIP 700)
            set cls [dict get $block class]
            set divTag "div_${cls}"
            set divStart [$t index "end -1 chars"]
            foreach subBlock [dict get $block blocks] {
                mdviewer::renderBlock $path $subBlock
            }
            set divEnd [$t index "end -1 chars"]
            $t tag add $divTag $divStart $divEnd
        }
        footnote_section {
            # Separator line
            $t insert end "\n"
            $t insert end [string repeat "\u2500" 30] "footnote_hr"
            $t insert end "\n"

            foreach fn [dict get $block footnotes] {
                set fnId [dict get $fn id]
                set fnNum [dict get $fn num]
                set fnContent [dict get $fn content]

                # Nummer als Anker
                set markName "fn_$fnId"
                $t mark set $markName "end -1 chars"
                $t mark gravity $markName left

                $t insert end "$fnNum. " "footnote_num"
                mdviewer::renderInlines $path $fnContent
                $t insert end "\n"
            }
        }
        default {
            # ignore unknown blocks
        }
    }
}

proc mdviewer::renderInlines {path inlines {parentFormatTag ""}} {
    # parentFormatTag: When we are inside a strong/em/strike,
    # this tag name is passed so text nodes know they
    # should not get a quote_d0 tag (the format tag handles that)
    foreach node $inlines {
        mdviewer::renderInline $path $node $parentFormatTag
    }
}

proc mdviewer::renderInline {path node {parentFormatTag ""}} {
    variable state
    set t [mdviewer::widget $path]
    set type [dict get $node type]
    set ctx $state($path,renderContext)
    
    # Check if we are inside a blockquote
    set inQuote [expr {$state($path,quoteDepth) > 0}]
    if {$inQuote} {
        set quoteDepth [expr {$state($path,quoteDepth) - 1}]
        set qtag "quote_d${quoteDepth}"
    } else {
        set qtag ""
    }

    switch -- $type {
        text {
            # If we are inside a format tag (strong_q, em_q, etc.),
            # Format-Tag direkt beim Insert anwenden
            if {$parentFormatTag ne ""} {
                # Inside a format tag: apply format tag directly
                if {$ctx eq "table"} {
                    # In tables: combine base tag AND format tag
                    set btag $state($path,tableBaseTag)
                    $t insert end [dict get $node value] [list $btag $parentFormatTag]
                } elseif {$ctx eq "quote"} {
                    # In Blockquotes: Format-Tag direkt anwenden
                    # For strong_q: font already contains bold+italic
                    # For em_q: font already contains italic
                    $t insert end [dict get $node value] $parentFormatTag
                } else {
                    # Normal context: format tag only
                    $t insert end [dict get $node value] $parentFormatTag
                }
            } elseif {$ctx eq "table"} {
                # Table cells: correct base tag for background + monospace
                set btag $state($path,tableBaseTag)
                $t insert end [dict get $node value] $btag
            } elseif {$qtag ne ""} {
                $t insert end [dict get $node value] $qtag
            } else {
                $t insert end [dict get $node value]
            }
        }
        linebreak {
            $t insert end "\n"
        }
        inline_code {
            # Context tag: code_t in tables, codeinline otherwise
            if {$ctx eq "table"} {
                $t insert end [dict get $node value] code_t
            } else {
                $t insert end [dict get $node value] codeinline
            }
        }
        strong -
        emphasis -
        strike {
            # AST type -> Tk tag name (emphasis -> em for tag configuration)
            set tagBase [expr {$type eq "emphasis" ? "em" : $type}]
            # Choose context-dependent tag
            switch -- $ctx {
                quote  { set tagName "${tagBase}_q" }
                table  { set tagName "${tagBase}_t" }
                default { set tagName $tagBase }
            }
            set start [$t index end]
            # Pass parentFormatTag so text nodes know they don't need quote_d0 tag
            mdviewer::renderInlines $path [dict get $node content] $tagName
            set end [$t index end]
            # Add tag (also in tables, to ensure it covers the entire range)
            $t tag add $tagName $start $end
            
            # IMPORTANT: In blockquotes: quote_d0 tag is already removed during blockquote rendering
            # (strong_q hat bereits bold+italic durch Font-String-Syntax)
        }
        span {
            # Bracketed span [content] .class (Pandoc/TIP 700)
            set cls [dict get $node class]
            set spanTag "span_${cls}"
            set start [$t index end]
            # Render content; cmd/sub/lit/optlit -> bold, arg/optarg/optdot/ins -> italic
            if {$cls in {cmd sub lit optlit ccmd}} {
                mdviewer::renderInlines $path [dict get $node content] "strong"
                set end [$t index end]
                $t tag add strong $start $end
            } elseif {$cls in {arg optarg optdot ins cargs}} {
                mdviewer::renderInlines $path [dict get $node content] "em"
                set end [$t index end]
                $t tag add em $start $end
            } else {
                mdviewer::renderInlines $path [dict get $node content] $parentFormatTag
                set end [$t index end]
            }
            # Class-specific tag for custom styling
            $t tag add $spanTag $start $end
        }
        link {
            incr state($path,linkCounter)
            set ltag "link$state($path,linkCounter)"
            set url   [dict get $node url]
            set resolved [mdviewer::resolveUrl $path $url]

            # PDF-Links: eigener Tag + [PDF] Prefix
            if {[mdviewer::isPdf $resolved]} {
                set start [$t index "end -1 chars"]
                $t insert end "\[PDF\] "
                mdviewer::renderInlines $path [dict get $node label]
                set end [$t index "end -1 chars"]
                $t tag add pdflink $start $end
                $t tag add $ltag $start $end
                $t tag bind $ltag <Button-1> [list mdviewer::dispatchPdf $path $resolved]
            } else {
                set start [$t index "end -1 chars"]
                mdviewer::renderInlines $path [dict get $node label]
                set end [$t index "end -1 chars"]
                $t tag add link $start $end
                $t tag add $ltag $start $end
                $t tag bind $ltag <Button-1> [list mdviewer::dispatchLink $path $resolved]
            }
            $t tag bind $ltag <Enter> [list apply {{t ltag path resolved} {
                $t configure -cursor hand2
                $t tag configure $ltag -underline 1
                set cb [mdviewer::cget $path -onhover]
                if {$cb ne ""} { uplevel #0 [list {*}$cb $resolved] }
            }} $t $ltag $path $resolved]
            $t tag bind $ltag <Leave> [list apply {{t ltag path} {
                $t configure -cursor {}
                $t tag configure $ltag -underline 0
                set cb [mdviewer::cget $path -onhover]
                if {$cb ne ""} { uplevel #0 [list {*}$cb ""] }
            }} $t $ltag $path]
        }
        image {
            set alt [dict get $node alt]
            set url [dict get $node url]
            # Try to load image (small for inline)
            if {[mdviewer::loadImage $path $url img 60]} {
                $t image create end -image $img -padx 2
            } else {
                $t insert end "\[$alt\]" imageinline
            }
        }
        footnote_ref {
            set fnId [dict get $node id]
            # Hochgestellte Nummer als klickbarer Link
            $t insert end "\[$fnId\]" "footnote_ref"
            $t tag bind footnote_ref <Button-1> [list apply {{t fnId} {
                if {[$t mark exists "fn_$fnId"]} {
                    $t see "fn_$fnId"
                }
            }} $t $fnId]
        }
        default {
            # ignore
        }
    }
}

proc mdviewer::isAbsUrl {url} {
    # Erkennt absolute URLs: http://, https://, mailto:, ftp:// etc.
    return [regexp {^[a-zA-Z][a-zA-Z0-9+.-]+:} $url]
}

proc mdviewer::isPdf {url} {
    return [expr {[string tolower [file extension $url]] eq ".pdf"}]
}

proc mdviewer::resolveUrl {path url} {
    # Resolves relative URLs against -root.
    # Absolute URLs and anchors are returned unchanged.
    variable state
    if {[mdviewer::isAbsUrl $url]} { return $url }
    if {[string index $url 0] eq "#"} { return $url }
    set root ""
    if {[info exists state($path,root)]} {
        set root $state($path,root)
    }
    if {$root eq ""} { return $url }
    return [file join $root $url]
}

proc mdviewer::dispatchLink {path url} {
    variable state
    # Interne Anchor-Links (#section) direkt navigieren
    if {[string index $url 0] eq "#"} {
        set anchor [string range $url 1 end]
        mdviewer::gotoAnchor $path $anchor
        return
    }
    set cb $state($path,onlink)
    if {$cb eq ""} {
        return
    }
    uplevel #0 [list {*}$cb $url]
}

proc mdviewer::dispatchPdf {path url} {
    variable state
    set cb $state($path,onpdf)
    if {$cb ne ""} {
        uplevel #0 [list {*}$cb $url]
        return
    }
    # Fallback: wie normaler Link behandeln
    mdviewer::dispatchLink $path $url
}

proc mdviewer::dispatchClick {path x y} {
    variable state
    set cb $state($path,onclick)
    
    set t $state($path,text)
    
    # Text-Index unter Klick ermitteln
    set index [$t index @$x,$y]
    
    # Tags an dieser Position
    set tags [$t tag names $index]
    
    # Line and column
    lassign [split $index .] line col
    
    # Text of the clicked line
    set lineText [$t get "$line.0" "$line.end"]
    
    if {$cb eq ""} {
        # No callback - ignore
        return
    }
    
    # Call callback with all info
    uplevel #0 [list {*}$cb $x $y $index $tags $lineText]
}

# ============================================================
# Anchor-Navigation
# ============================================================

proc mdviewer::gotoAnchor {path anchor} {
    # Scrolls to anchor mark (set by heading).
    # Returns 1 on success, 0 if anchor not found.
    set t [mdviewer::widget $path]
    set mark "anchor_$anchor"
    if {$mark in [$t mark names]} {
        $t see $mark
        return 1
    }
    return 0
}

proc mdviewer::anchors {path} {
    # Returns list of all anchor names.
    set t [mdviewer::widget $path]
    set result {}
    foreach m [$t mark names] {
        if {[string match "anchor_*" $m]} {
            lappend result [string range $m 7 end]
        }
    }
    return $result
}

# ============================================================
# Fontsize-Steuerung
# ============================================================

proc mdviewer::setFontSize {path size} {
    # Sets base font size. Named fonts propagate automatically
    # to all tags and widgets that reference them.
    variable state
    set state($path,fontsize) $size
    set fp $state($path,fontPrefix)
    set t [mdviewer::widget $path]

    # Body-Font (Widget-Default)
    $t configure -font ${fp}_body
    font configure ${fp}_body   -size $size

    # Proportional-Fonts
    font configure ${fp}_bold        -size $size
    font configure ${fp}_italic      -size $size
    font configure ${fp}_bold_italic -size $size
    font configure ${fp}_small       -size [expr {$size - 2}]

    # Headings – proportionale Skalierung
    foreach {tag factor} {h1 1.6  h2 1.4  h3 1.2  h4 1.1  h5 1.0  h6 1.0} {
        font configure ${fp}_$tag -size [expr {int($size * $factor)}]
    }

    # Quote-depth tags (use italic font, don't need font configure,
    # but are set to italic at creation time)
    for {set d 0} {$d < 5} {incr d} {
        catch {$t tag configure "quote_d$d" -font ${fp}_italic}
    }
}

# ============================================================
# Named Fonts
# ============================================================

proc mdviewer::fontPrefix {path} {
    # Creates a unique, font-safe prefix from the widget path.
    # z.B. ".nb.tab.viewer" → "mdv_nb_tab_viewer"
    return "mdv[string map {. _} $path]"
}

proc mdviewer::initFonts {path size} {
    # Creates named fonts for a viewer instance.
    # All tags reference these fonts; setFontSize only changes the fonts.
    variable state
    set fp $state($path,fontPrefix)

    set family [font actual TkDefaultFont -family]
    set monoFamily [font actual TkFixedFont -family]
    set monoSize   [font actual TkFixedFont -size]

    # Proportional-Fonts
    font create ${fp}_body        -family $family -size $size
    font create ${fp}_bold        -family $family -size $size -weight bold
    font create ${fp}_italic      -family $family -size $size -slant italic
    font create ${fp}_bold_italic -family $family -size $size -weight bold -slant italic

    # Heading-Fonts
    foreach {tag factor} {h1 1.6  h2 1.4  h3 1.2  h4 1.1  h5 1.0  h6 1.0} {
        font create ${fp}_$tag -family $family \
            -size [expr {int($size * $factor)}] -weight bold
    }

    # Monospace-Fonts
    font create ${fp}_mono        -family $monoFamily -size $monoSize
    font create ${fp}_mono_bold   -family $monoFamily -size $monoSize -weight bold
    font create ${fp}_mono_italic -family $monoFamily -size $monoSize -slant italic
    font create ${fp}_small       -family $family -size [expr {$size - 2}]
}

proc mdviewer::deleteFonts {path} {
    # Cleans up named fonts when the viewer is destroyed.
    variable state
    if {![info exists state($path,fontPrefix)]} return
    set fp $state($path,fontPrefix)
    foreach suffix {body bold italic bold_italic
                    h1 h2 h3 h4 h5 h6
                    mono mono_bold mono_italic small} {
        catch {font delete ${fp}_$suffix}
    }
}

proc mdviewer::initTags {t fp} {
    # Configure tags – all font assignments via named fonts.
    # fp = font prefix of the instance.
    #
    # IMPORTANT: Creation order determines tag priority!
    # Later created tags have higher priority.
    # → Base tags zuerst, Kontext-Tags danach.

    # Set widget font to named font
    $t configure -font ${fp}_body

    # ── 1. Block-level tags (lowest priority) ──
    #    Base spacing comes from \n in the render loop.
    #    Spacing adds typographic hierarchy ADDITIONALLY.
    $t tag configure para
    $t tag configure listblock
    $t tag configure tableblock

    # ── 2. Headings (spacing = extra space above base spacing) ──
    $t tag configure h1 -font ${fp}_h1 -spacing1 14 -spacing3 2
    $t tag configure h2 -font ${fp}_h2 -spacing1 10 -spacing3 2
    $t tag configure h3 -font ${fp}_h3 -spacing1 8  -spacing3 1
    $t tag configure h4 -font ${fp}_h4 -spacing1 4  -spacing3 1
    $t tag configure h5 -font ${fp}_h5 -spacing1 2
    $t tag configure h6 -font ${fp}_h6 -spacing1 2

    # ── 3. Sonstige Base tags ──
    $t tag configure link       -foreground blue   -underline 0
    $t tag configure pdflink    -foreground #cc6600 -underline 0
    $t tag configure listprefix -foreground #444444
    $t tag configure taskdone   -foreground #999999
    $t tag configure hr         -foreground #777777 -font ${fp}_mono \
        -spacing1 4 -spacing3 4
    $t tag configure quote -foreground #555555 \
        -lmargin1 20 -lmargin2 20 -font ${fp}_italic
    $t tag configure imageblock  -foreground #666666 -font ${fp}_italic
    $t tag configure imgcaption  -foreground #888888 -font ${fp}_italic \
        -justify center
    $t tag configure imageinline -foreground #666666

    # Footnotes
    $t tag configure footnote_hr  -foreground #999999 -spacing1 8
    $t tag configure footnote_num -foreground #336699 -font ${fp}_bold
    $t tag configure footnote_ref -foreground #336699 -font ${fp}_small \
        -offset 4

    # Definition Lists
    $t tag configure defterm -font ${fp}_bold -spacing1 6
    $t tag configure defdef  -lmargin1 24 -lmargin2 24 -spacing3 2

    # ── 4. Table base (BEFORE context tags -> lower priority) ──
    $t tag configure tablecell   -font ${fp}_mono -background #fafafa
    $t tag configure tableheader -font ${fp}_mono -background #e8e8e8 \
        -foreground #333333

    # ── 5. Inline-Formatierung ──
    $t tag configure strong -font ${fp}_bold
    $t tag configure em     -font ${fp}_italic
    $t tag configure strike -overstrike 1

    # ── 6. Context tags: blockquote (above quote_dN via raise) ──
    $t tag configure strong_q -font ${fp}_bold_italic
    $t tag configure em_q     -font ${fp}_italic
    $t tag configure strike_q -overstrike 1

    # ── 7. Context tags: table (after tablecell -> automatically higher priority) ──
    $t tag configure strong_t -font ${fp}_mono_bold   -background #fafafa
    $t tag configure em_t     -font ${fp}_mono_italic -background #fafafa
    $t tag configure strike_t -overstrike 1            -background #fafafa
    $t tag configure code_t   -font ${fp}_mono         -background #e0e0e0

    # ── 8. Code (highest priority) ──
    $t tag configure codeinline -font ${fp}_mono -background #f0f0f0
    $t tag configure codelabel  -font ${fp}_mono -background #e0e0e0 \
        -foreground #666666 -lmargin1 20
    $t tag configure codeblock  -font ${fp}_mono -background #e8e8e8 \
        -lmargin1 20 -lmargin2 20 -rmargin 20

    # ── 8b. Syntax-Highlighting (innerhalb codeblock) ──
    $t tag configure syn_keyword  -foreground #1a5276
    $t tag configure syn_string   -foreground #196f3d
    $t tag configure syn_comment  -foreground #888888
    $t tag configure syn_variable -foreground #7b241c
    $t tag configure syn_option   -foreground #6c3483
    $t tag configure syn_number   -foreground #a04000

    # ── Tag priorities: only needed for dynamic tags ──
    # quote_dN is created dynamically in renderBlock -> raise needed
    foreach ctxTag {strong_q em_q strike_q} {
        for {set d 0} {$d < 5} {incr d} {
            catch {$t tag raise $ctxTag "quote_d$d"}
        }
    }
    # Table context tags no longer need raise:
    # Creation order guarantees priority.
}

proc mdviewer::clearDynamicLinkTags {path} {
    variable state
    set t [mdviewer::widget $path]
    for {set i 1} {$i <= $state($path,linkCounter)} {incr i} {
        set ltag "link$i"
        catch {$t tag bind $ltag <Button-1> {}}
        catch {$t tag bind $ltag <Enter> {}}
        catch {$t tag bind $ltag <Leave> {}}
        catch {$t tag delete $ltag}
    }
    set state($path,linkCounter) 0
}

proc mdviewer::renderTable {path block} {
    set t [mdviewer::widget $path]
    set header [dict get $block header]
    set rows [dict get $block rows]
    set alignments [dict get $block alignments]
    set hasInlines [dict exists $block headerInlines]
    
    # Calculate column widths (based on plain text length)
    set cols [llength $header]
    set widths [lrepeat $cols 0]
    
    # Header widths (from inlines or fallback)
    for {set c 0} {$c < $cols} {incr c} {
        if {$hasInlines} {
            set w [string length [mdviewer::inlinesToText [lindex [dict get $block headerInlines] $c]]]
        } else {
            set w [string length [lindex $header $c]]
        }
        if {$w > [lindex $widths $c]} { lset widths $c $w }
    }
    
    # Row widths
    set ri 0
    foreach row $rows {
        for {set c 0} {$c < $cols} {incr c} {
            if {$hasInlines} {
                set cell [mdviewer::inlinesToText [lindex [lindex [dict get $block rowsInlines] $ri] $c]]
            } else {
                set cell [lindex $row $c]
            }
            set w [string length $cell]
            if {$w > [lindex $widths $c]} { lset widths $c $w }
        }
        incr ri
    }
    
    # Minimum 3, maximum 40 characters per column
    set maxColWidth 40
    for {set c 0} {$c < $cols} {incr c} {
        set w [lindex $widths $c]
        if {$w < 3} { set w 3 }
        if {$w > $maxColWidth} { set w $maxColWidth }
        lset widths $c $w
    }
    
    # Render header (only if not empty)
    set hasHeader 0
    foreach h $header {
        if {$h ne ""} { set hasHeader 1; break }
    }
    
    if {$hasHeader} {
        $t insert end "│" tableheader
        for {set c 0} {$c < $cols} {incr c} {
            set w [lindex $widths $c]
            set align [lindex $alignments $c]
            $t insert end " " tableheader
            if {$hasInlines} {
                mdviewer::renderTableCell $path \
                    [lindex [dict get $block headerInlines] $c] \
                    [lindex $header $c] $w $align tableheader
            } else {
                $t insert end [mdviewer::alignText [lindex $header $c] $w $align] tableheader
            }
            $t insert end " │" tableheader
        }
        $t insert end "\n"
        
        # Separator
        $t insert end "├" hr
        for {set c 0} {$c < $cols} {incr c} {
            set w [lindex $widths $c]
            $t insert end [string repeat "─" [expr {$w + 2}]] hr
            if {$c < $cols - 1} {
                $t insert end "┼" hr
            }
        }
        $t insert end "┤\n" hr
    }
    
    # Rows rendern
    set rowIdx 0
    foreach row $rows {
        $t insert end "│" tablecell
        for {set c 0} {$c < $cols} {incr c} {
            set w [lindex $widths $c]
            set rawCell [string trim [lindex $row $c]]
            set align [lindex $alignments $c]
            $t insert end " " tablecell
            
            # Image-Zelle?
            if {[regexp {^!\[([^\]]*)\]\(([^)]+)\)$} $rawCell -> alt url]} {
                if {[mdviewer::loadImage $path $url img 40]} {
                    $t image create end -image $img
                } else {
                    $t insert end [mdviewer::alignText "\[$alt\]" $w $align] tablecell
                }
            } elseif {$hasInlines} {
                mdviewer::renderTableCell $path \
                    [lindex [lindex [dict get $block rowsInlines] $rowIdx] $c] \
                    $rawCell $w $align tablecell
            } else {
                set cell [mdviewer::inlinesToText [list [dict create type text value $rawCell]]]
                $t insert end [mdviewer::alignText $cell $w $align] tablecell
            }
            $t insert end " │" tablecell
        }
        $t insert end "\n"
        incr rowIdx
    }
}

# ── Frame-based table rendering (RS-style) ──
# Embedded frame + label widgets instead of monospace text.
# Advantages: proportional fonts, zebra stripes, real backgrounds.
# Disadvantage: no copy-paste of table contents.
# Activated via:  mdviewer::configure $path -tablemode frame

proc mdviewer::renderTableFrame {path block} {
    variable state
    set t [mdviewer::widget $path]
    set header [dict get $block header]
    set rows [dict get $block rows]
    set alignments [dict get $block alignments]
    set cols [llength $header]
    set fp [mdviewer::fontPrefix $path]

    incr state($path,tableCounter)
    set tf $t.tbl$state($path,tableCounter)

    # Outer frame as border (1px gray border via padx/pady + bg)
    frame $tf -bg #cccccc -padx 1 -pady 1

    # ── Header ──
    set hasHeader 0
    foreach h $header {
        if {$h ne ""} { set hasHeader 1; break }
    }
    set startRow 0
    set hasInlines [dict exists $block headerInlines]
    if {$hasHeader} {
        for {set c 0} {$c < $cols} {incr c} {
            if {$hasInlines} {
                set text [mdviewer::inlinesToText [lindex [dict get $block headerInlines] $c]]
            } else {
                set text [lindex $header $c]
            }
            set anchor [mdviewer::alignToAnchorFrame [lindex $alignments $c]]
            label $tf.h$c -text $text \
                -font ${fp}_bold -bg #e0e0e0 \
                -padx 8 -pady 4 -anchor $anchor
            grid $tf.h$c -row 0 -column $c -sticky ew -padx 1 -pady 1
        }
        set startRow 1
    }

    # ── Data rows ──
    set r $startRow
    set rowIdx 0
    foreach row $rows {
        set c 0
        foreach cell $row {
            set align [lindex $alignments $c]
            set anchor [mdviewer::alignToAnchorFrame $align]
            # Zebrastreifen
            set bg [expr {($r - $startRow) % 2 == 0 ? "white" : "#f8f8f8"}]

            # Plain text from inlines (if present)
            if {$hasInlines && [dict exists $block rowsInlines]} {
                set cellInlines [lindex [lindex [dict get $block rowsInlines] $rowIdx] $c]
                set text [mdviewer::inlinesToText $cellInlines]
            } else {
                set text $cell
            }

            # Image in cell? (check inline type or fallback to regexp)
            set isImage 0
            set isLink 0
            if {$hasInlines && [dict exists $block rowsInlines]} {
                set firstInline [lindex $cellInlines 0]
                if {[llength $cellInlines] == 1 && [dict get $firstInline type] eq "image"} {
                    set isImage 1
                    set altText [dict get $firstInline alt]
                    set imgUrl [dict get $firstInline url]
                } elseif {[llength $cellInlines] == 1 && [dict get $firstInline type] eq "link"} {
                    set isLink 1
                    set linkText [mdviewer::inlinesToText [dict get $firstInline label]]
                    set linkUrl [dict get $firstInline url]
                }
            } else {
                if {[regexp {^!\[([^\]]*)\]\(([^)]+)\)$} $cell -> altText imgUrl]} {
                    set isImage 1
                } elseif {[regexp {\[([^\]]+)\]\(([^)]+)\)} $cell -> linkText linkUrl]} {
                    set isLink 1
                }
            }

            if {$isImage} {
                set resolved [mdviewer::resolveUrl $path $imgUrl]
                if {[mdviewer::loadImage $path $imgUrl img 120]} {
                    label $tf.c${r}_$c -image $img -bg $bg -padx 4 -pady 4
                } else {
                    set disp [expr {$altText ne "" ? $altText : "(Bild)"}]
                    label $tf.c${r}_$c -text $disp -font ${fp}_italic \
                        -bg $bg -fg #999999 -padx 8 -pady 3 -anchor $anchor
                }
            # Link in Zelle?
            } elseif {$isLink} {
                set resolved [mdviewer::resolveUrl $path $linkUrl]
                label $tf.c${r}_$c -text $linkText -font ${fp}_body \
                    -bg $bg -fg #0066cc -padx 8 -pady 3 -anchor $anchor \
                    -cursor hand2
                if {[mdviewer::isPdf $resolved]} {
                    bind $tf.c${r}_$c <Button-1> \
                        [list mdviewer::dispatchPdf $path $resolved]
                } else {
                    bind $tf.c${r}_$c <Button-1> \
                        [list mdviewer::dispatchLink $path $resolved]
                }
                bind $tf.c${r}_$c <Enter> \
                    [list $tf.c${r}_$c configure -font ${fp}_body]
                bind $tf.c${r}_$c <Leave> \
                    [list $tf.c${r}_$c configure -font ${fp}_body]
            } else {
                # Normale Zelle
                label $tf.c${r}_$c -text $text -font ${fp}_body \
                    -bg $bg -padx 8 -pady 3 -anchor $anchor
            }
            grid $tf.c${r}_$c -row $r -column $c -sticky ew -padx 1 -pady 1
            incr c
        }
        incr r
        incr rowIdx
    }

    # Distribute columns equally
    for {set c 0} {$c < $cols} {incr c} {
        grid columnconfigure $tf $c -weight 1
    }

    # Frame in Text-Widget einbetten
    $t window create end -window $tf -padx 5 -pady 5
    $t insert end "\n"
}

proc mdviewer::alignToAnchorFrame {align} {
    switch -- $align {
        center { return center }
        right  { return e }
        default { return w }
    }
}

# Render table cell with inline formatting
# Calculates padding based on plain text length, renders inlines between
proc mdviewer::renderTableCell {path inlines rawText colWidth align baseTag} {
    variable state
    set t [mdviewer::widget $path]
    set plainText [mdviewer::inlinesToText $inlines]
    set textLen [string length $plainText]
    
    # Truncation: if text too long, fallback to alignText
    if {$textLen > $colWidth} {
        $t insert end [mdviewer::alignText $plainText $colWidth $align] $baseTag
        return
    }
    
    set pad [expr {$colWidth - $textLen}]
    
    # Leading pad (for right/center)
    switch -- $align {
        right {
            $t insert end [string repeat " " $pad] $baseTag
        }
        center {
            set leftPad [expr {$pad / 2}]
            if {$leftPad > 0} {
                $t insert end [string repeat " " $leftPad] $baseTag
            }
        }
    }
    
    # Set context to table for context-dependent tags
    set prevCtx $state($path,renderContext)
    set state($path,renderContext) "table"
    set state($path,tableBaseTag) $baseTag
    
    # Inlines rendern
    mdviewer::renderInlines $path $inlines
    
    # Reset context
    set state($path,renderContext) $prevCtx
    
    # Trailing pad (for left/center)
    switch -- $align {
        left {
            if {$pad > 0} {
                $t insert end [string repeat " " $pad] $baseTag
            }
        }
        center {
            set rightPad [expr {$pad - ($pad / 2)}]
            if {$rightPad > 0} {
                $t insert end [string repeat " " $rightPad] $baseTag
            }
        }
    }
}

# Align text (left, center, right) – with truncation on overflow
proc mdviewer::alignText {text width align} {
    set len [string length $text]
    if {$len > $width} {
        # Truncate with ellipsis
        set text "[string range $text 0 $width-2]\u2026"
        set len $width
    }
    set pad [expr {$width - $len}]
    if {$pad <= 0} {
        return $text
    }
    switch -- $align {
        right {
            return "[string repeat { } $pad]$text"
        }
        center {
            set left [expr {$pad / 2}]
            set right [expr {$pad - $left}]
            return "[string repeat { } $left]$text[string repeat { } $right]"
        }
        default {
            # left
            return "$text[string repeat { } $pad]"
        }
    }
}

# DEPRECATED: Ersetzt durch inlinesToText (Prio 17).
# Only as fallback for ASTs without headerInlines/rowsInlines.
# DEPRECATED: use inlinesToText instead.
proc mdviewer::stripMarkdown {text} {
    # ![alt](url) -> [alt]
    regsub -all {!\[([^\]]*)\]\([^)]+\)} $text {[\1]} text
    # **bold** -> bold
    regsub -all {\*\*([^*]+)\*\*} $text {\1} text
    # *italic* -> italic
    regsub -all {\*([^*]+)\*} $text {\1} text
    # ~~strike~~ -> strike
    regsub -all {~~([^~]+)~~} $text {\1} text
    # `code` -> code
    regsub -all {`([^`]+)`} $text {\1} text
    return $text
}

# Convert inlines to plain text (for blockquotes)
proc mdviewer::inlinesToText {inlines} {
    set result ""
    foreach inline $inlines {
        set type [dict get $inline type]
        switch -- $type {
            text { append result [dict get $inline value] }
            inline_code { append result [dict get $inline value] }
            strong - emphasis - strike - span {
                append result [mdviewer::inlinesToText [dict get $inline content]]
            }
            link { append result [mdviewer::inlinesToText [dict get $inline label]] }
            image { append result [dict get $inline alt] }
            footnote_ref { append result "\[[dict get $inline id]\]" }
        }
    }
    return $result
}

# Load image and optionally scale
# Returns 1 on success, 0 on failure
# imgVar contains the image name
proc mdviewer::loadImage {path url imgVar {maxSize 200}} {
    variable state
    upvar $imgVar img
    
    # Root-Pfad ermitteln
    set root ""
    if {[info exists state($path,root)]} {
        set root $state($path,root)
    }
    
    # Create absolute path
    if {$root ne "" && ![string match "/*" $url] && ![string match "?:*" $url]} {
        set fullPath [file join $root $url]
    } else {
        set fullPath $url
    }
    
    # Check if file exists
    if {![file exists $fullPath]} {
        return 0
    }
    
    # Eindeutigen Image-Namen generieren
    set imgName "mdv_img_[incr state($path,imgCounter)]"
    
    # Versuche Bild zu laden
    set ext [string tolower [file extension $fullPath]]
    if {[catch {
        switch -- $ext {
            .png - .gif {
                image create photo $imgName -file $fullPath
            }
            .jpg - .jpeg {
                if {[catch {package require Img}]} {
                    return 0
                }
                image create photo $imgName -file $fullPath
            }
            .svg {
                if {[catch {package require tksvg}]} {
                    return 0
                }
                image create photo $imgName -file $fullPath -format svg
            }
            default {
                return 0
            }
        }
    } err]} {
        return 0
    }
    
    # Scale if needed
    set w [image width $imgName]
    set h [image height $imgName]
    if {$w > $maxSize} {
        set scale [expr {double($maxSize) / $w}]
        set newW $maxSize
        set newH [expr {int($h * $scale)}]
        set scaled "mdv_scaled_[incr state($path,imgCounter)]"
        image create photo $scaled -width $newW -height $newH
        # Simple scaling (without subsample for better quality)
        $scaled copy $imgName -shrink -subsample [expr {int(1.0/$scale)}]
        image delete $imgName
        set imgName $scaled
    }
    
    set img $imgName
    lappend state($path,images) $imgName
    return 1
}

proc mdviewer::highlightCode {t startIdx endIdx lang} {
    # Einfaches Keyword-basiertes Syntax-Highlighting for Tcl.
    # Andere Sprachen: nur Kommentare und Strings.

    set lang [string tolower $lang]

    # --- Comments: # to end of line (all languages) ---
    set commentPat "(?:^|;\\s*)#"
    set idx $startIdx
    while {1} {
        set idx [$t search -regexp -- $commentPat $idx $endIdx]
        if {$idx eq ""} break
        set lineEnd [$t index "$idx lineend"]
        set ch [$t get $idx]
        if {$ch eq "#"} {
            $t tag add syn_comment $idx $lineEnd
        } else {
            set hashIdx [$t search "#" $idx $lineEnd]
            if {$hashIdx ne ""} {
                $t tag add syn_comment $hashIdx $lineEnd
            }
        }
        set idx "$lineEnd + 1 char"
        if {[$t compare $idx >= $endIdx]} break
    }

    # --- Strings: "..." (alle Sprachen) ---
    set idx $startIdx
    while {1} {
        set idx [$t search "\"" $idx $endIdx]
        if {$idx eq ""} break
        set closeIdx [$t search "\"" "$idx + 1 char" $endIdx]
        if {$closeIdx ne ""} {
            set matchEnd "$closeIdx + 1 char"
            $t tag add syn_string $idx $matchEnd
            set idx $matchEnd
        } else {
            break
        }
        if {[$t compare $idx >= $endIdx]} break
    }

    if {$lang ni {tcl tk}} return

    # --- Tcl-Keywords ---
    set keywords {
        if else elseif for foreach while switch
        return break continue catch try throw
        package namespace variable upvar uplevel global proc
        set expr list lindex lrange lappend lset llength lsort lsearch lmap lassign
        dict array string info regexp regsub
        open close read puts gets flush
        file source after update vwait
        error rename unset apply
        method constructor destructor next self
    }

    set kwPat "(?:^|\\s)(%KW%)(?:\\s|$)"
    foreach kw $keywords {
        set pat [string map [list %KW% $kw] $kwPat]
        set idx $startIdx
        while {1} {
            set idx [$t search -regexp -- $pat $idx $endIdx]
            if {$idx eq ""} break
            set ch [$t get $idx]
            if {$ch eq " " || $ch eq "\t" || $ch eq "\n"} {
                set kwStart "$idx + 1 char"
            } else {
                set kwStart $idx
            }
            set kwEnd "$kwStart + [string length $kw] chars"
            set existingTags [$t tag names $kwStart]
            if {"syn_string" ni $existingTags && "syn_comment" ni $existingTags} {
                $t tag add syn_keyword $kwStart $kwEnd
            }
            set idx $kwEnd
            if {[$t compare $idx >= $endIdx]} break
        }
    }

    # --- Variablen: $name $::name ---
    set varPat "\\\$(?:::)?\\w+(?:::\\w+)*"
    set idx $startIdx
    while {1} {
        set idx [$t search -regexp -- $varPat $idx $endIdx]
        if {$idx eq ""} break
        set lineEnd [$t index "$idx lineend"]
        set rest [$t get $idx $lineEnd]
        if {[regexp "^${varPat}" $rest match]} {
            set varEnd "$idx + [string length $match] chars"
            set existingTags [$t tag names $idx]
            if {"syn_comment" ni $existingTags} {
                $t tag add syn_variable $idx $varEnd
            }
            set idx $varEnd
        } else {
            set idx "$idx + 1 char"
        }
        if {[$t compare $idx >= $endIdx]} break
    }

    # --- Options: -option ---
    set optPat "\\s-\[a-z\]\\w*"
    set optValPat "^-\[a-z\]\\w*"
    set idx $startIdx
    while {1} {
        set idx [$t search -regexp -- $optPat $idx $endIdx]
        if {$idx eq ""} break
        set optStart "$idx + 1 char"
        set rest [$t get $optStart [$t index "$optStart lineend"]]
        if {[regexp $optValPat $rest match]} {
            set optEnd "$optStart + [string length $match] chars"
            set existingTags [$t tag names $optStart]
            if {"syn_string" ni $existingTags && "syn_comment" ni $existingTags} {
                $t tag add syn_option $optStart $optEnd
            }
            set idx $optEnd
        } else {
            set idx "$idx + 1 char"
        }
        if {[$t compare $idx >= $endIdx]} break
    }
}

proc mdviewer::assertAst {ast} {
    if {![dict exists $ast type] || [dict get $ast type] ne "document"} {
        error "mdviewer::render: not a document AST"
    }
    if {![dict exists $ast version] || [dict get $ast version] != 1} {
        error "mdviewer::render: unsupported AST version"
    }
    return 1
}
