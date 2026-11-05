# mdserver::view -- Office- und CSV-Dateien als Seite
# ============================================================================
# CSV als Tabellenseite (--csv-view, tclutils::tucsv), Office-Dateien als
# Seite (--office-view; tudocx, tuodf, tuxlsx), dieselben Seiten in den
# aelteren Stilen, und die Zwischenablage fuer fertige Seiten (--viewcache).
# Die Zeilen einer CSV braucht auch die Suche (_csvRows).
#
# Bis 2026-11-05 Teil von mdserver-0.4.tm. Die Klasse ist ein Mixin von
# mdserver::Server, wie mdserver::Search: ihre Methoden laufen im
# Server-Objekt, teilen dessen Variablen (my variable) und rufen dessen
# Methoden (my cfg, my _esc, ...). Allein ist sie nicht zu gebrauchen.
# ============================================================================

package require Tcl 8.6 9
package provide mdserver::view 0.4

oo::class create mdserver::View {

    # Rows of a CSV file: UTF-8 or cp1252 (see _decodeText), delimiter the
    # one of ";" "," and tab that occurs most often in the first line.
    method _csvRows {f} {
        set fh [open $f rb]
        try { set bytes [read $fh] } finally { close $fh }
        set text [my _decodeText $bytes]
        # the delimiter that occurs most often in the first line: ; , or tab
        set first [lindex [split $text \n] 0]
        set d ,
        set best [regexp -all {,} $first]
        foreach c [list ";" "\t"] {
            set n [regexp -all -- $c $first]
            if {$n > $best} { set d $c ; set best $n }
        }
        return [::tclutils::tucsv::parse $text -delimiter $d -strict 0]
    }

    # A CSV file as a table: the first row is the header, at most csvMax
    # rows, a link to the file itself (?raw=1).
    method _csvBody {f} {
        set csvMax 2000
        set n [file tail $f]
        set raw "[my _esc [string map {" " %20} $n]]?raw=1"
        set body "<h1>[my _esc [file rootname $n]]</h1>"
        if {[catch {my _csvRows $f} rows]} {
            return "$body<p>Die Datei l\u00e4sst sich nicht als CSV lesen: [my _esc $rows]</p>\
<p><a href=\"$raw\">Datei herunterladen</a></p>"
        }
        set total [expr {max(0, [llength $rows] - 1)}]
        append body "<p class=\"mds-lead\">$total Zeilen &middot; <a href=\"$raw\">als CSV herunterladen</a></p>"
        if {![llength $rows]} { return $body }
        append body "<div class=\"mds-csv\"><table><thead><tr>"
        foreach c [lindex $rows 0] { append body "<th>[my _escBr $c]</th>" }
        append body "</tr></thead><tbody>"
        foreach r [lrange $rows 1 $csvMax] {
            append body "<tr>"
            foreach c $r { append body "<td>[my _escBr $c]</td>" }
            append body "</tr>"
        }
        append body "</tbody></table></div>"
        if {$total > $csvMax} {
            append body "<p class=\"mds-note\">Gezeigt: die ersten $csvMax von $total Zeilen.</p>"
        }
        return $body
    }

    # Text of a file whose encoding is not known: UTF-8 if the bytes are
    # valid UTF-8, else cp1252 (Excel and older Windows tools).
    method _decodeText {bytes} {
        if {[package vsatisfies [package provide Tcl] 9-]} {
            if {![catch {encoding convertfrom -profile strict utf-8 $bytes} t]} { return $t }
        } else {
            set t [encoding convertfrom utf-8 $bytes]
            if {[encoding convertto utf-8 $t] eq $bytes} { return $t }
        }
        return [encoding convertfrom cp1252 $bytes]
    }

    # Office files as a page (--office-view auto|0|1): Word (.docx, tudocx)
    # and ODF text/slides (.odt .odp, tuodf) as paragraphs, Excel (.xlsx,
    # tuxlsx) and ODF spreadsheets (.ods, tuodf 0.2 rows) as tables, one per
    # sheet; ?raw=1 sends the file. A dict extension -> kind.
    method _officeViewExts {} {
        my variable _officeV
        if {[info exists _officeV]} { return $_officeV }
        set _officeV [dict create]
        set mode [my cfg officeview]
        if {$mode in {0 off no false}} { return $_officeV }
        my _tclutilsPath
        set missing {}
        foreach {pkg ver map} {
            tclutils::tudocx 0.1 {.docx docx}
            tclutils::tuodf  0.2 {.odt odt .odp odt .ods ods}
            tclutils::tuxlsx 0.1 {.xlsx xlsx}
        } {
            if {[catch {package require $pkg $ver}]} { lappend missing $pkg ; continue }
            foreach {e k} $map {
                if {$k eq "ods" && ![llength [info commands ::tclutils::tuodf::rows]]} continue
                dict set _officeV $e $k
            }
        }
        if {[llength $missing] && $mode ni {auto}} {
            puts stderr "WARNING: --office-view: not found: [join $missing {, }]"
        }
        return $_officeV
    }

    # Text for HTML: escaped, a line break as <br>.
    method _escBr {s} {
        return [string map [list \n <br>] [my _esc $s]]
    }

    # A table of rows (lists of cells), at most max rows; "" for none.
    method _rowsTable {rows max} {
        if {![llength $rows]} { return "" }
        set w 0
        foreach r [lrange $rows 0 [expr {$max - 1}]] { set w [expr {max($w, [llength $r])}] }
        set out "<div class=\"mds-csv\"><table><tbody>"
        foreach r [lrange $rows 0 [expr {$max - 1}]] {
            append out "<tr>"
            for {set i 0} {$i < $w} {incr i} { append out "<td>[my _escBr [lindex $r $i]]</td>" }
            append out "</tr>"
        }
        append out "</tbody></table></div>"
        if {[llength $rows] > $max} {
            append out "<p class=\"mds-note\">Gezeigt: die ersten $max von [llength $rows] Zeilen.</p>"
        }
        return $out
    }

    # An office file as HTML: title, a line with kind and download link,
    # then paragraphs or one table per sheet. A file that cannot be read
    # gives the message and the download link.
    method _officeBody {f} {
        set rowMax 2000
        set kind [dict get [my _officeViewExts] [string tolower [file extension $f]]]
        set n [file tail $f]
        set raw "[my _esc [string map {" " %20} $n]]?raw=1"
        set label [dict get {docx Word-Dokument odt Textdokument odp Pr&auml;sentation xlsx Excel-Mappe ods Tabellendokument} $kind]
        set body "<h1>[my _esc [file rootname $n]]</h1>"
        set err [catch {
            switch -- $kind {
                docx - odt {
                    # if, not expr: expr would turn a paragraph 007 into 7
                    if {$kind eq "docx"} {
                        set ps [::tclutils::tudocx::paragraphs $f]
                    } else {
                        set ps [::tclutils::tuodf::paragraphs $f]
                    }
                    set ps [lmap p $ps {if {[string trim $p] eq ""} continue ; set p}]
                    set main "<div class=\"mds-office\">"
                    foreach p $ps { append main "<p>[my _escBr $p]</p>" }
                    append main "</div>"
                    set info "[llength $ps] Abs&auml;tze"
                }
                xlsx - ods {
                    if {$kind eq "xlsx"} {
                        set names [::tclutils::tuxlsx::sheets $f]
                    } else {
                        set names [::tclutils::tuodf::sheets $f]
                    }
                    set main ""
                    set i 0
                    foreach s $names {
                        incr i
                        if {$kind eq "xlsx"} {
                            set rows [::tclutils::tuxlsx::rows $f -sheet $i]
                        } else {
                            set rows [::tclutils::tuodf::rows $f -sheet $i]
                        }
                        if {[llength $names] > 1} { append main "<h2>[my _esc $s]</h2>" }
                        set t [my _rowsTable $rows $rowMax]
                        if {$t eq ""} { set t "<p><em>leer</em></p>" }
                        append main $t
                    }
                    set info "[llength $names] [expr {[llength $names] == 1 ? "Blatt" : "Bl&auml;tter"}]"
                }
            }
        } msg]
        if {$err} {
            return "$body<p>Die Datei l&auml;sst sich nicht lesen: [my _esc $msg]</p>\
<p><a href=\"$raw\">Datei herunterladen</a></p>"
        }
        append body "<p class=\"mds-lead\">$label &middot; $info &middot; <a href=\"$raw\">herunterladen</a></p>$main"
        return $body
    }

    # The page body for a file shown as a page (CSV, office), or "" when
    # the file is sent as it is (?raw=1, view off, other types).
    method _viewBody {req fsPath} {
        if {[$req param raw ""] ne ""} { return "" }
        set ext [string tolower [file extension $fsPath]]
        if {$ext eq ".csv" && [my _csvOn]} {
            return [my _viewCached $fsPath _csvBody]
        }
        if {[dict exists [my _officeViewExts] $ext]} {
            return [my _viewCached $fsPath _officeBody]
        }
        return ""
    }

    # Office- und CSV-Seiten sind teuer: eine .xlsx mit 20 000 Zeilen
    # kostete 4,5 s, bei jedem Aufruf, und der eine Thread wartete so lange.
    # Darum bleibt der fertige Koerper liegen, solange Aenderungszeit und
    # Groesse der Datei gleich sind. Hoechstens --viewcache MB (Vorgabe 32,
    # 0 = aus); was am laengsten nicht gebraucht wurde, faellt zuerst heraus
    # (ein dict haelt die Einfuegereihenfolge, ein Treffer kommt ans Ende).
    # Die Aenderungszeit hat Sekunden: wer eine Datei in derselben Sekunde
    # auf dieselbe Groesse aendert, sieht bis zur naechsten Aenderung den
    # alten Stand.
    method _viewCached {f macher} {
        my variable _viewC _viewCBytes _viewHit _viewMiss
        if {![info exists _viewC]} { set _viewC [dict create]; set _viewCBytes 0 }
        if {![info exists _viewHit]} { set _viewHit 0; set _viewMiss 0 }
        set max [expr {[my cfg viewcache] * 1048576}]
        if {$max <= 0 || [catch {list [file mtime $f] [file size $f]} key]} {
            return [my $macher $f]
        }
        if {[dict exists $_viewC $f]} {
            lassign [dict get $_viewC $f] k b
            dict unset _viewC $f
            if {$k eq $key} {
                dict set _viewC $f [list $k $b]
                incr _viewHit
                return $b
            }
            incr _viewCBytes [expr {-[string length $b]}]
        }
        set b [my $macher $f]
        incr _viewMiss
        set n [string length $b]
        if {$n <= $max} {
            dict set _viewC $f [list $key $b]
            incr _viewCBytes $n
            while {$_viewCBytes > $max} {
                set alt [lindex [dict keys $_viewC] 0]
                incr _viewCBytes [expr {-[string length [lindex [dict get $_viewC $alt] 1]]}]
                dict unset _viewC $alt
            }
        }
        return $b
    }

    # The same page in the styles other than site: through the Markdown
    # renderer as one HTML block, so theme, style and navigation apply.
    method _viewPage {body theme toc style} {
        my variable _renderer
        set css "<style>.mds-csv{overflow-x:auto}.mds-csv table{border-collapse:collapse}\
.mds-csv td,.mds-csv th{border:1px solid #9998;padding:.25rem .5rem;vertical-align:top}\
.mds-lead{opacity:.8}</style>"
        # an HTML block ends at a blank line: the body has none (_escBr)
        set html [$_renderer markdownText "<div class=\"mds-view\">$css$body</div>\n" \
            $theme $toc [my _styleCss $style]]
        return [my _injectNav $html]
    }

    # CSV files as a table page in style site (--csv-view auto|0|1), with
    # tclutils::tucsv 0.2; ?raw=1 sends the file itself. Their text is in
    # the search as well.
    method _csvOn {} {
        my variable _csvOn
        if {[info exists _csvOn]} { return $_csvOn }
        set mode [my cfg csvview]
        if {$mode in {0 off no false}} { return [set _csvOn 0] }
        my _tclutilsPath
        if {[catch {package require tclutils::tucsv 0.2} err]} {
            if {$mode ni {auto}} {
                puts stderr "WARNING: --csv-view: tclutils::tucsv 0.2 not found -- CSV files are sent as they are: $err"
            }
            return [set _csvOn 0]
        }
        return [set _csvOn 1]
    }
}
