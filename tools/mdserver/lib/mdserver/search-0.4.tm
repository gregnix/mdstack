# mdserver::search -- die Volltextsuche von mdserver
# ============================================================================
# Suchindex (schrittweise nach dem Start, je Datei nach Aenderungszeit),
# PDF-, Office- und CSV-Text fuer die Suche, Abfragen, Ergebnisseiten
# (site, andere Stile, JSON), Suchtipps, Hilfe bei "Nichts gefunden" und die
# Titelliste im Kopf.
#
# Bis 2026-11-05 Teil von mdserver-0.4.tm. Die Klasse ist ein Mixin von
# mdserver::Server: ihre Methoden laufen im Server-Objekt, teilen dessen
# Variablen (my variable) und rufen dessen Methoden (my cfg, my _esc, ...).
# Allein ist sie nicht zu gebrauchen.
# ============================================================================

package require Tcl 8.6 9
package provide mdserver::search 0.4

oo::class create mdserver::Search {

    # Titles for the search field in the header (<datalist>, 2026-11-05):
    # up to 200 document titles (Markdown, office, CSV; no PDF pages),
    # those higher up in the tree first. From the search index; a page
    # looks at the tree again at most every 30 s. When PDFs are read in the
    # server process (--pdf-worker 0) a page never builds the index: that
    # waits for the first search, which reads the PDFs anyway.
    method _titleDatalist {} {
        my variable _searchIdx _searchScanAt
        set inlinePdf [expr {[my _pdfOn] && ![my _pdfWorkerOn]}]
        # A page never reads the tree itself: it starts the stepwise build
        # (_indexVorab) and shows what is there.
        if {![info exists _searchIdx]} {
            if {!$inlinePdf} { catch {my _indexVorab} }
            return ""
        } elseif {!$inlinePdf && [info exists _searchScanAt]
                && [clock seconds] - $_searchScanAt > 30} {
            catch {my _indexVorab}
        }
        return [my _perIndex datalist _titleDatalistMake]
    }

    method _titleDatalistMake {} {
        my variable _searchIdx
        set root [my cfg root]
        set all {}
        dict for {f e} $_searchIdx {
            if {[dict exists $e pages]} continue
            set depth [llength [file split [string range $f [string length $root] end]]]
            lappend all [list $depth [dict get $e title]]
        }
        set seen [dict create]
        foreach dt [lsort -integer -index 0 [lsort -dictionary -index 1 $all]] {
            set t [lindex $dt 1]
            if {$t eq "" || [dict exists $seen $t]} continue
            dict set seen $t 1
            if {[dict size $seen] >= 200} break
        }
        if {![dict size $seen]} { return "" }
        set out "<datalist id=\"mds-titles\">"
        foreach t [lsort -dictionary [dict keys $seen]] {
            append out "<option value=\"[my _esc $t]\">"
        }
        return "$out</datalist>"
    }

    # ------------------------------------------------------------------
    # Full-text search (?q=...).
    #
    # All .md under the root, read once and kept with their mtime; a search
    # walks the tree (cheap) and rereads only what changed. Words are ANDed,
    # case-insensitive, umlauts match their ae/oe/ue spelling. Dot folders
    # and symlinks are left out, as for serving.
    #
    # Query syntax (2026-10-30):
    #   "two words"    a phrase: the words in this order
    #   -word -"a b"   leave out entries that contain it
    #   a OR b, a | b  either of the two (binds the neighbours only;
    #                  ODER too, upper case only)
    #   in:dir/sub     only below this folder (relative to the root)
    #   typ:md|pdf|office|csv  only Markdown files, PDF pages, office
    #                  documents (ODF, DOCX, XLSX) or CSV files
    # in and typ also come as URL parameters (?in=...&typ=...); the result
    # page offers both, the folder choice from ?von= (the page the search
    # field was on).
    # ------------------------------------------------------------------

    method _fold {s} {
        return [string map [list \u00e4 ae \u00f6 oe \u00fc ue \u00df ss] [string tolower $s]]
    }

    method _searchFiles {dir} {
        set out {}
        set exts {.md}
        if {[my _pdfOn]} { lappend exts .pdf }
        lappend exts {*}[dict keys [my _officeReaders]]
        if {[my _csvOn]} { lappend exts .csv }
        foreach e [glob -nocomplain -directory $dir *] {
            set n [file tail $e]
            if {[string index $n 0] eq "." && ![my cfg dotfiles]} continue
            if {[catch {file type $e} t] || $t eq "link"} continue
            if {$t eq "directory"} {
                lappend out {*}[my _searchFiles $e]
            } else {
                if {[string tolower [file extension $n]] in $exts} { lappend out $e }
            }
        }
        return $out
    }

    # ------------------------------------------------------------------
    # PDFs in the search (--pdf-search auto|0|1).
    #
    # The text comes from tclutils::tupdftext (pure Tcl, tclutils 0.67.0),
    # found on the module path or through TCLUTILS_TM. "auto" uses it when
    # it loads and stays quiet otherwise; "1" says once why it does not.
    # One hit per page, linked as file.pdf#page=N (pdf.js and Chrome follow
    # it). Reading a PDF takes about 30 ms per page, so the text is kept in
    # a cache directory (--pdf-cache, default ~/.cache/mdserver-pdf), one
    # file per PDF, valid while mtime and size match. Never in the served
    # root.
    #
    # The reading itself runs in a tclsh per PDF, through tclutils::tutask
    # (--pdf-worker 1, default):
    # in the server process it stopped every other request until it was
    # done. Measured 2026-10-21, 16 PDFs with 1804 pages, empty cache: the
    # first search took 36 s, and a page asked for at the same time also
    # 36 s. With the worker the page comes at once; the search answers
    # with what is in the cache and says how many PDFs are still being
    # read. --pdf-worker 0 reads in the server process as before.
    # ------------------------------------------------------------------

    method _pdfOn {} {
        my variable _pdfOn
        if {[info exists _pdfOn]} { return $_pdfOn }
        set mode [my cfg pdfsearch]
        if {$mode in {0 off no false}} { return [set _pdfOn 0] }
        my _tclutilsPath
        if {[catch {package require tclutils::tupdftext 0.1} err]} {
            if {$mode ni {auto}} {
                puts stderr "WARNING: --pdf-search: tclutils::tupdftext not found\
                    (TCLUTILS_TM or module path) -- PDFs are not searched: $err"
            }
            return [set _pdfOn 0]
        }
        return [set _pdfOn 1]
    }

    # Office documents in the search (--office-search auto|0|1): ODF
    # (.odt .ods .odp) with tclutils::tuodf, Word (.docx) with tudocx, Excel
    # (.xlsx) with tuxlsx -- each when its module loads. One hit per file,
    # the text of its paragraphs or cells. Read in the server process (a
    # zip and one or a few XML parts, quick) and kept in the index with the
    # mtime. Returns a dict extension -> command prefix that gives the text.
    method _officeReaders {} {
        my variable _officeR
        if {[info exists _officeR]} { return $_officeR }
        set _officeR [dict create]
        set mode [my cfg officesearch]
        if {$mode in {0 off no false}} { return $_officeR }
        my _tclutilsPath
        set missing {}
        foreach {pkg exts cmd} {
            tclutils::tuodf  {.odt .ods .odp} {apply {{f} {join [::tclutils::tuodf::paragraphs $f] " "}}}
            tclutils::tudocx {.docx}          {apply {{f} {join [::tclutils::tudocx::paragraphs $f] " "}}}
            tclutils::tuxlsx {.xlsx}          {apply {{f} {::tclutils::tuxlsx::text $f}}}
        } {
            if {[catch {package require $pkg 0.1}]} { lappend missing $pkg ; continue }
            foreach e $exts { dict set _officeR $e $cmd }
        }
        if {[llength $missing] && $mode ni {auto}} {
            puts stderr "WARNING: --office-search: not found: [join $missing {, }]"
        }
        return $_officeR
    }

    method _officeStatus {} {
        set r [my _officeReaders]
        if {![dict size $r]} { return "Suche aus" }
        set mods {}
        foreach pkg {tclutils::tuodf tclutils::tudocx tclutils::tuxlsx} {
            if {![catch {package present $pkg} v]} { lappend mods "[namespace tail $pkg] $v" }
        }
        return "Suche an ([join [dict keys $r] { }]; [join $mods {, }])"
    }

    # One line for the start banner: is the PDF search on, and if not, why.
    method _pdfStatus {} {
        if {[my cfg pdfsearch] in {0 off no false}} { return "Suche aus (--pdf-search 0)" }
        if {[my _pdfOn]} {
            return "Suche an (tclutils::tupdftext [package present tclutils::tupdftext],\
                Cache [my _pdfCacheDir])"
        }
        return "Suche aus: tclutils::tupdftext nicht gefunden (TCLUTILS_TM setzen\
            oder tclutils/lib/tm auf den Modulpfad)"
    }

    method _pdfCacheDir {} {
        set d [my cfg pdfcache]
        if {$d eq ""} {
            set home [expr {[info exists ::env(HOME)] ? $::env(HOME) : [pwd]}]
            set d [file join $home .cache mdserver-pdf]
        }
        return $d
    }

    # Cache file for a PDF; the file holds [list path mtime size pages].
    method _pdfCacheFile {f} {
        set key [format %08x [zlib crc32 [encoding convertto utf-8 [file normalize $f]]]]
        return [file join [my _pdfCacheDir] $key.txt]
    }

    # Pages from the cache, if it fits the file: {1 pages}, else {0 {}}.
    method _pdfCached {f mt} {
        set cf [my _pdfCacheFile $f]
        if {[file exists $cf] && ![catch {file size $f} size]
                && ![catch {my _readUtf8 $cf} c]
                && [lrange $c 0 2] eq [list [file normalize $f] $mt $size]} {
            return [list 1 [lindex $c 3]]
        }
        return {0 {}}
    }

    # Pages of a PDF as a list of texts, through the cache, read in this
    # process. A PDF without text (scan, encrypted, damaged) gives {} and
    # is cached as such.
    method _pdfPages {f mt} {
        lassign [my _pdfCached $f $mt] ok pages
        if {$ok} { return $pages }
        if {[catch {::tclutils::tupdftext::pages $f} pages]} { set pages {} }
        my _pdfCacheWrite $f $mt $pages
        return $pages
    }

    # A cache that cannot be written is not an error (the next search reads
    # the PDF again); a failed write leaves the old entry and no open channel
    # (up to 2026-10-30 an error in puts left the channel open).
    method _pdfCacheWrite {f mt pages} {
        set cf [my _pdfCacheFile $f]
        catch {
            file mkdir [file dirname $cf]
            my _writeAtomic $cf [list [file normalize $f] $mt [file size $f] $pages]
        }
    }

    # ---- PDF worker ---------------------------------------------------
    #
    # One tclsh per PDF (lib/pdftext-worker.tcl), started and awaited with
    # tclutils::tutask: a task "pdfReader" takes the queue one PDF at a
    # time, `await [pipe ...] -timeout`. The event loop keeps serving while
    # it waits. tutask comes with the same tclutils as tupdftext. A crash,
    # a timeout or a non-zero exit is an error of the await; the process is
    # killed on timeout and when the server stops.

    method _pdfWorkerOn {} {
        my variable _pdfWOn
        if {[info exists _pdfWOn]} { return $_pdfWOn }
        if {[my cfg pdfworker] in {0 off no false}} { return [set _pdfWOn 0] }
        # a starpack's executable runs its own application, not the script
        if {[info exists ::starkit::topdir]} {
            my _log "pdf worker: starpack -- reading in the server"
            return [set _pdfWOn 0]
        }
        if {![file readable [file join $::mdserver::moduleDir pdftext-worker.tcl]]} {
            my _log "pdf worker: lib/pdftext-worker.tcl missing -- reading in the server"
            return [set _pdfWOn 0]
        }
        if {[catch {package require tclutils::tutask 0.2} err]} {
            my _log "pdf worker: tclutils::tutask not found -- reading in the server"
            return [set _pdfWOn 0]
        }
        return [set _pdfWOn 1]
    }

    method _pdfWorkerClose {} {
        my variable _pdfReader _pdfQ
        if {[info exists _pdfReader] && $_pdfReader ne ""} {
            catch {$_pdfReader cancel}
        }
        set _pdfReader ""
        set _pdfQ {}
    }

    # Queue F for the worker unless it is queued already.
    method _pdfQueue {f mt} {
        my variable _pdfQ _pdfReader
        if {![info exists _pdfQ]} { set _pdfQ {} }
        if {![info exists _pdfReader]} { set _pdfReader "" }
        set nf [file normalize $f]
        if {[dict exists $_pdfQ $nf]} { return }
        if {[catch {file size $f} size]} { return }
        dict set _pdfQ $nf [list $mt $size]
        if {$_pdfReader eq ""} {
            set _pdfReader [::tclutils::tutask::spawn -detach 1 \
                {*}[namespace code [list my _pdfReader]]]
        }
    }

    # The task: one PDF after the other until the queue is empty. A PDF
    # whose worker fails twice gets an empty cache entry and stays out of
    # the search until it changes.
    method _pdfReader {} {
        my variable _pdfQ _pdfReader _pdfFails
        if {![info exists _pdfFails]} { set _pdfFails {} }
        set script [file join $::mdserver::moduleDir pdftext-worker.tcl]
        set exe [info nameofexecutable]
        try {
            while {[dict size $_pdfQ]} {
                set nf [lindex [dict keys $_pdfQ] 0]
                lassign [dict get $_pdfQ $nf] mt size
                set cmd [list $exe $script $nf $mt $size [my _pdfCacheFile $nf] \
                    [tcl::tm::path list]]
                try {
                    set res [::tclutils::tutask::await \
                        [::tclutils::tutask::pipe $cmd -encoding utf-8] -timeout 600000]
                    # cached as empty because the reader failed: say so
                    if {[regexp {\(error: (.*)\)} $res -> why]} {
                        my _log "pdf worker: $nf has no text, reader failed: $why"
                    }
                    dict unset _pdfFails $nf
                } trap {TCLUTILS TUTASK CANCELLED} {} {
                    return
                } on error {msg} {
                    set msg [string trim $msg]
                    if {[string match "*tupdftext not found*" $msg]} {
                        # no PDF is to blame: read in the server from now on
                        my variable _pdfWOn
                        set _pdfWOn 0
                        set _pdfQ {}
                        my _log "pdf worker: $msg -- reading in the server"
                        return
                    }
                    if {[dict exists $_pdfFails $nf]} {
                        my _log "pdf worker failed again on $nf ($msg) -- skipped until it changes"
                        if {![catch {file mtime $nf} m] && $m == $mt} {
                            my _pdfCacheWrite $nf $mt {}
                        }
                        dict unset _pdfFails $nf
                    } else {
                        my _log "pdf worker failed on $nf ($msg) -- the next search tries again"
                        dict set _pdfFails $nf 1
                    }
                }
                if {[dict exists $_pdfQ $nf]} { dict unset _pdfQ $nf }
            }
        } finally {
            set _pdfReader ""
        }
    }

    # PDFs still being read by the worker.
    method _pdfPending {} {
        my variable _pdfQ
        if {![info exists _pdfQ]} { return 0 }
        return [dict size $_pdfQ]
    }

    # Plain text of a Markdown file: markup off, link targets dropped.
    method _plainText {md} {
        regsub -all {\[([^\]]*)\]\([^)]*\)} $md {\1} md
        regsub -all {\[([^\]]*)\]\{[^\}]*\}} $md {\1} md
        regsub -all {<!--.*?-->} $md {} md
        regsub -all {(?n)^\s*([-*_]\s*){3,}$} $md {} md
        regsub -all {(?n)^[\s|:]*-{3,}[-\s|:]*$} $md {} md
        regsub -all {(?n)^\s{0,3}(#+|>|[-*+]|\d+\.)\s+} $md {} md
        regsub -all {[*`|]+} $md { } md
        regsub -all {\s+} $md { } md
        return [string trim $md]
    }

    # The search index: dict file -> entry. _searchGen counts the states of
    # the index (a file read anew, added or gone); what is built from the
    # whole index (word list, tips, title list) is kept per state.
    method _searchIndex {} {
        my variable _searchIdx _searchGen _searchScanAt _vorabFresh _vorabFiles _indexGanz
        if {![info exists _searchIdx]} { set _searchIdx {} }
        if {![info exists _searchGen]} { set _searchGen 0 }
        # During the first, stepwise build a search does not read the rest
        # itself (that took 16 s with 30 000 files): it answers with what is
        # read and says how much is missing (_indexPending). A few hundred
        # files it reads itself, as before (under 0.5 s). Not with PDFs read
        # in the server process: then the search reads them, as before.
        if {![info exists _indexGanz] && ![info exists _vorabFiles]
                && !([my _pdfOn] && ![my _pdfWorkerOn])} {
            catch {my _indexVorab}
        }
        if {![info exists _indexGanz] && [info exists _vorabFiles]
                && [llength $_vorabFiles] > 500} {
            if {[dict size $_vorabFresh] != [dict size $_searchIdx]} {
                set _searchIdx $_vorabFresh
                incr _searchGen
            }
            return $_searchIdx
        }
        set root [my cfg root]
        set fresh {}
        set changed 0
        foreach f [my _searchFiles $root] {
            if {[catch {file mtime $f} mt]} continue
            if {[dict exists $_searchIdx $f] && [dict get $_searchIdx $f mtime] == $mt} {
                dict set fresh $f [dict get $_searchIdx $f]
                continue
            }
            if {[info exists _vorabFresh] && [dict exists $_vorabFresh $f]
                    && [dict get $_vorabFresh $f mtime] == $mt} {
                dict set fresh $f [dict get $_vorabFresh $f]
                incr changed
                continue
            }
            lassign [my _indexEntry $f $mt] ok e
            if {!$ok} continue
            dict set e words [my _entryWords $e]
            dict set fresh $f $e
            incr changed
        }
        if {$changed || [dict size $fresh] != [dict size $_searchIdx]} { incr _searchGen }
        set _searchIdx $fresh
        set _searchScanAt [clock seconds]
        set _indexGanz 1
        return $fresh
    }

    # The distinct words (3 letters and more) of an index entry, for
    # "Meinten Sie". Made when the file is read, in the stepwise build:
    # made on the first search without hits, it took 11 s for 30 000
    # files (2026-11-05).
    method _entryWords {e0} {
        if {[dict exists $e0 pages]} { set entries [dict get $e0 pages] } else { set entries [list $e0] }
        set txt ""
        foreach e $entries { append txt " " [dict get $e ftitle] " " [dict get $e ftext] }
        set ws [lsort -unique [split [regsub -all {[^[:alnum:]_]+} $txt " "] " "]]
        return [lsearch -all -inline -glob $ws ???*]
    }

    # One file for the search index: {1 entry}, or {0 {}} when it is left
    # out (unreadable, or a PDF the worker still reads).
    method _indexEntry {f mt} {
        if {[string tolower [file extension $f]] eq ".pdf"} {
            if {[my _pdfWorkerOn]} {
                lassign [my _pdfCached $f $mt] ok raw
                if {!$ok} {
                    # not in the index yet: the next scan looks again
                    my _pdfQueue $f $mt
                    return {0 {}}
                }
            } else {
                set raw [my _pdfPages $f $mt]
            }
            set pages {}
            set title [file rootname [file tail $f]]
            set n 0
            foreach t $raw {
                incr n
                set t [string trim [regsub -all {\s+} $t " "]]
                if {$t eq ""} continue
                set pt "$title, S. $n"
                lappend pages [dict create page $n title $pt text $t \
                    ftitle [my _fold $pt] ftext [my _fold $t]]
            }
            return [list 1 [dict create mtime $mt kind pdf pages $pages]]
        }
        set ext [string tolower [file extension $f]]
        if {$ext in {.odt .ods .odp .docx .xlsx .csv}} {
            set kind [expr {$ext eq ".csv" ? "csv" : "office"}]
            if {$kind eq "office"} {
                set rd [my _officeReaders]
                if {![dict exists $rd $ext] || [catch {{*}[dict get $rd $ext] $f} text]} {
                    set text ""
                }
            } else {
                if {[catch {my _csvRows $f} rows]} { set rows {} }
                set text [join [lmap r $rows {join $r " "}] " "]
            }
            set text [string trim [regsub -all {\s+} $text " "]]
            set title [file rootname [file tail $f]]
            return [list 1 [dict create mtime $mt kind $kind title $title text $text \
                ftitle [my _fold $title] ftext [my _fold $text]]]
        }
        if {[catch {my _readUtf8 $f} md]} { return {0 {}} }
        set title [my _h1Title $f]
        if {$title eq ""} { set title [file rootname [file tail $f]] }
        set title [my _plainLabel $title]
        set text [my _plainText $md]
        return [list 1 [dict create mtime $mt title $title text $text \
            ftitle [my _fold $title] ftext [my _fold $text]]]
    }

    # Building the index in the server process, all at once, took 15 s for
    # 30 000 Markdown files, and every request waited -- also the first
    # page, because the title list in the header needs the index
    # (2026-11-05). Now it is built in steps of at most 50 ms; between them
    # requests are served. A search before it is done answers with what is
    # read so far and says so (_indexPending).
    method _indexVorab {} {
        my variable _vorabFiles _vorabFresh
        if {[info exists _vorabFiles]} return
        if {[catch {my _searchFiles [my cfg root]} files]} return
        set _vorabFiles $files
        set _vorabFresh [dict create]
        after 1 [namespace code {my _indexSchritt}]
    }

    method _indexSchritt {} {
        my variable _vorabFiles _vorabFresh _searchIdx _searchGen _searchScanAt _vorabNeu
        if {![info exists _vorabFiles]} return
        set neu [expr {[info exists _vorabNeu] && $_vorabNeu}]
        if {![info exists _searchIdx]} { set _searchIdx {} }
        if {![info exists _searchGen]} { set _searchGen 0 }
        set bis [expr {[clock milliseconds] + 50}]
        while {[llength $_vorabFiles] && [clock milliseconds] < $bis} {
            set f [lindex $_vorabFiles end]
            set _vorabFiles [lreplace $_vorabFiles end end]
            if {[catch {file mtime $f} mt]} continue
            if {!$neu && [dict exists $_searchIdx $f] && [dict get $_searchIdx $f mtime] == $mt} {
                dict set _vorabFresh $f [dict get $_searchIdx $f]
                continue
            }
            if {[catch {my _indexEntry $f $mt} r]} continue
            lassign $r ok e
            if {!$ok} continue
            dict set e words [my _entryWords $e]
            dict set _vorabFresh $f $e
        }
        if {[llength $_vorabFiles]} {
            after 1 [namespace code {my _indexSchritt}]
            return
        }
        # done: the new state replaces the old one; gone files leave it
        my variable _indexGanz
        set _searchIdx $_vorabFresh
        incr _searchGen
        set _searchScanAt [clock seconds]
        set _indexGanz 1
        set _vorabNeu 0
        unset _vorabFiles _vorabFresh
    }

    # The result of METHOD ARGS, made once per state of the search index.
    method _perIndex {name args} {
        my variable _searchGen _perIdx
        if {![info exists _searchGen]} { my _searchIndex }
        if {[info exists _perIdx($name)] && [lindex $_perIdx($name) 0] == $_searchGen} {
            return [lindex $_perIdx($name) 1]
        }
        set v [my {*}$args]
        set _perIdx($name) [list $_searchGen $v]
        return $v
    }

    # A query as a dict: groups (list of OR-lists of folded terms, all
    # groups must match), excl (folded terms that must not match), in
    # (folder relative to the root, "" = everywhere), typ (md, pdf, office,
    # csv or ""). gshow and xshow hold the terms of groups and excl as typed
    # (blanks made single), for showing them and for _unparseQuery. lowor:
    # the query with a lower-case "or"/"oder" between two terms written as
    # ODER/OR, "" if there is none (2026-11-05).
    method _parseQuery {query {in ""} {typ ""}} {
        set groups {} ; set excl {} ; set orNext 0
        set gshow {} ; set xshow {}
        set toks {} ; set lowAt -1 ; set lowFix {} ; set lastTerm 0
        foreach {all neg phr word} [regexp -all -inline {(-?)(?:"([^"]*)"?|(\S+))} $query] {
            lappend toks $all
            set isPhrase [expr {[string index $all [string length $neg]] eq "\""}]
            if {!$isPhrase && $neg eq ""} {
                if {$word in {OR ODER |}} { set orNext 1 ; set lastTerm 0 ; continue }
                if {[regexp -nocase {^(in|typ|type):(.*)$} $word -> k v]} {
                    if {[string tolower $k] eq "in"} { set in $v } else { set typ $v }
                    continue
                }
                if {$word in {or oder}} {
                    if {$lastTerm} { set lowAt [expr {[llength $toks] - 1}] }
                } elseif {$lowAt >= 0} {
                    lappend lowFix $lowAt
                    set lowAt -1
                }
            } else {
                set lowAt -1
            }
            set raw [expr {$isPhrase ? $phr : $word}]
            set t [my _fold $raw]
            set t [string trim [regsub -all {\s+} $t " "]]
            set s [string trim [regsub -all {\s+} $raw " "]]
            if {[string length $t] < 2} continue
            if {$neg ne ""} {
                lappend excl $t
                lappend xshow $s
            } elseif {$orNext && [llength $groups]} {
                lset groups end [linsert [lindex $groups end] end $t]
                lset gshow end [linsert [lindex $gshow end] end $s]
            } else {
                lappend groups [list $t]
                lappend gshow [list $s]
            }
            set orNext 0
            set lastTerm [expr {$neg eq ""}]
        }
        set lowor ""
        if {[llength $lowFix]} {
            foreach i $lowFix {
                lset toks $i [expr {[lindex $toks $i] eq "or" ? "OR" : "ODER"}]
            }
            set lowor [join $toks " "]
        }
        return [dict create groups $groups excl $excl \
            in [my _searchScope $in] typ [my _searchTyp $typ] \
            gshow $gshow xshow $xshow lowor $lowor]
    }

    # A term as it goes back into a query: in quotes when it holds a blank
    # or would otherwise be read as something else (-x, OR, in:...).
    method _quoteTerm {s {neg 0}} {
        if {[regexp {\s} $s]} { return "\"$s\"" }
        if {!$neg && ([string index $s 0] in {- \"} || $s in {OR ODER |}
                || [regexp -nocase {^(in|typ|type):} $s])} {
            return "\"$s\""
        }
        return $s
    }

    # The query text of a parsed query PQ (the reverse of _parseQuery):
    # parse -> _unparseQuery -> parse gives the same groups, excl, in and
    # typ. With SCOPE 0 in: and typ: are left out (they go as URL
    # parameters). A folder with a blank in its name cannot be written as
    # in: and is left out.
    method _unparseQuery {pq {scope 1}} {
        set out {}
        foreach g [dict get $pq gshow] {
            lappend out [join [lmap s $g {my _quoteTerm $s}] " OR "]
        }
        foreach s [dict get $pq xshow] {
            lappend out "-[my _quoteTerm $s 1]"
        }
        if {$scope} {
            set in [dict get $pq in]
            if {$in ne "" && ![regexp {[\s"]} $in]} { lappend out "in:$in" }
            if {[dict get $pq typ] ne ""} { lappend out "typ:[dict get $pq typ]" }
        }
        return [join $out " "]
    }

    # A folder for in: relative, "/"-separated, no "." or "..", no dot
    # folder unless --dotfiles; anything else counts as "everywhere".
    method _searchScope {in} {
        set parts [lsearch -all -inline -not [split [string map {\\ /} $in] /] ""]
        foreach p $parts {
            if {$p in {. ..}} { return "" }
            if {[string index $p 0] eq "." && ![my cfg dotfiles]} { return "" }
        }
        return [join $parts /]
    }

    method _searchTyp {typ} {
        switch -- [string tolower $typ] {
            md - markdown        { return md }
            pdf                  { return pdf }
            office - odf - odt - ods - odp - docx - xlsx - word - excel { return office }
            csv                  { return csv }
            default              { return "" }
        }
    }

    method _typLabel {typ} {
        return [dict get {md Markdown pdf PDF office Office csv CSV} $typ]
    }

    # The types the search covers now, in this order.
    method _searchTyps {} {
        set out md
        if {[my _pdfOn]} { lappend out pdf }
        if {[dict size [my _officeReaders]]} { lappend out office }
        if {[my _csvOn]} { lappend out csv }
        return $out
    }

    # Titles of the folders down to D (relative to the root), as a path.
    # Only a real folder is read for its title; a symlink or a name that
    # does not exist shows as it is (D comes from the request).
    method _scopeTitle {d} {
        set titles {}
        set fs [my cfg root]
        set real 1
        foreach p [split $d /] {
            set fs [file join $fs $p]
            if {$real && ([catch {file type $fs} t] || $t ne "directory")} { set real 0 }
            set dt [expr {$real ? [my _dirTitle $fs] : $p}]
            if {[lindex $titles end] ne $dt} { lappend titles $dt }
        }
        return [join $titles " \u203a "]
    }

    # Score of TERM in a title/text pair: 20 for the title, plus the hits
    # in the text (at most 10); 0 if it is in neither.
    # 20 for the term in the title, plus how often it is in the text (at
    # most 10). Counted with string first, not regexp -all: the term is a
    # plain string, and regexp read the whole text even when 10 was long
    # reached -- 30 000 files took 2 s even without a hit (2026-11-05).
    method _termScore {term fh ft} {
        set inTitle [expr {[string first $term $fh] >= 0}]
        set l [string length $term]
        set n 0
        if {$l > 0} {
            set i [string first $term $ft]
            while {$i >= 0 && $n < 10} {
                incr n
                set i [string first $term $ft [expr {$i + $l}]]
            }
        }
        return [expr {$inTitle * 20 + $n}]
    }

    # All hits for the parsed query PQ, best first: dicts {url rel kind
    # title score text}. Path and snippet are made later, for the hits on
    # the page (_hitsShown); up to 2026-11-05 they were made for every hit.
    method _searchHits {pq} {
        set groups [dict get $pq groups]
        if {![llength $groups]} { return {} }
        set excl  [dict get $pq excl]
        set scope [dict get $pq in]
        set typ   [dict get $pq typ]
        set hits {}
        dict for {f e0} [my _searchIndex] {
          set kind [expr {[dict exists $e0 kind] ? [dict get $e0 kind] : "md"}]
          set isPdf [expr {$kind eq "pdf"}]
          if {$typ ne "" && $typ ne $kind} continue
          set url [my _relUrlOf $f]
          if {$scope ne "" && $url ne $scope && ![string match "$scope/*" $url]} continue
          # a Markdown file is one entry, a PDF one entry per page
          # if, not expr: expr looks whether its result is a number and so
          # made the text form of the whole entry -- about 10 KB per file,
          # on every search; with 30 000 files that was 3 s of a search
          # without hits (2026-11-05).
          if {$isPdf} { set entries [dict get $e0 pages] } else { set entries [list $e0] }
          foreach e $entries {
            set ft [dict get $e ftext] ; set fh [dict get $e ftitle]
            set score 0 ; set ok 1
            foreach g $groups {
                set best 0
                foreach t $g { set best [expr {max($best, [my _termScore $t $fh $ft])}] }
                if {$best == 0} { set ok 0 ; break }
                incr score $best
            }
            if {!$ok} continue
            foreach t $excl {
                if {[my _termScore $t $fh $ft] > 0} { set ok 0 ; break }
            }
            if {!$ok} continue
            set u $url
            if {[dict exists $e page]} { append u "#page=[dict get $e page]" }
            set title [dict get $e title]
            lappend hits [list $score $title [dict create url "/$u" rel $url kind $kind \
                title $title score $score text [dict get $e text]]]
          }
        }
        # Best first, equal scores by title. Two sorts instead of one with
        # -command: lsort is stable, and a Tcl comparison per pair cost
        # seconds with 30 000 hits.
        set hits [lsort -index 1 $hits]
        set hits [lsort -integer -decreasing -index 0 $hits]
        return [lmap h $hits { lindex $h 2 }]
    }

    # The path of F below the root with "/", kept per file: made from
    # file split for every file on every search, it was the larger part
    # of a search without hits.
    method _relUrlOf {f} {
        my variable _relUrl
        if {[info exists _relUrl($f)]} { return $_relUrl($f) }
        set rel [string range $f [string length [my cfg root]] end]
        return [set _relUrl($f) [join [lmap p [file split $rel] {
            if {$p eq "/" || $p eq "\\"} continue ; set p }] /]]
    }

    # HITS (from _searchHits) as shown: {url title path snippet score kind}.
    method _hitsShown {hits pq} {
        set words [concat {*}[dict get $pq groups]]
        set root [my cfg root]
        set titles {}
        set out {}
        foreach h $hits {
            set dirTitles {}
            set fs $root
            foreach p [lrange [split [dict get $h rel] /] 0 end-1] {
                set fs [file join $fs $p]
                if {![dict exists $titles $fs]} { dict set titles $fs [my _dirTitle $fs] }
                set dt [dict get $titles $fs]
                # bookkit wrapper and edition share the title: once
                if {[lindex $dirTitles end] ne $dt} { lappend dirTitles $dt }
            }
            lappend out [dict create url [dict get $h url] title [dict get $h title] \
                path [join $dirTitles " \u203a "] score [dict get $h score] \
                kind [dict get $h kind] \
                snippet [my _snippet [dict get $h text] $words]]
        }
        return $out
    }

    # Hits for QUERY: list of dicts {url title path snippet score kind}, best
    # first. IN and TYP narrow the search as in:/typ: in the query (those win).
    method _search {query {max 50} {in ""} {typ ""}} {
        set pq [my _parseQuery $query $in $typ]
        return [my _hitsShown [lrange [my _searchHits $pq] 0 [expr {$max - 1}]] $pq]
    }

    # One search for a result page (2026-11-05): pq, all (the hits in the
    # folder, any type, for the type counts), hits (of the type asked
    # for), total, page and pages (50 hits a page), shown (the hits of
    # this page, with path and snippet).
    method _searchRun {query in typ page} {
        set pq [my _parseQuery $query $in $typ]
        set typ [dict get $pq typ]
        set all [my _searchHits [dict replace $pq typ ""]]
        if {$typ eq ""} {
            set hits $all
        } else {
            set hits [lmap h $all { if {[dict get $h kind] ne $typ} continue ; set h }]
        }
        set per 50
        set total [llength $hits]
        set pages [expr {max(1, ($total + $per - 1) / $per)}]
        if {[regexp {^[0-9]{10,}$} $page]} { set page $pages }
        if {![regexp {^[0-9]{1,9}$} $page] || $page < 1} { set page 1 }
        if {$page > $pages} { set page $pages }
        set from [expr {($page - 1) * $per}]
        set shown [my _hitsShown [lrange $hits $from [expr {$from + $per - 1}]] $pq]
        return [dict create pq $pq all $all hits $hits total $total page $page \
            pages $pages per $per from $from shown $shown]
    }

    method _reQuote {s} {
        return [regsub -all {[][{}()*+?.\\^$|]} $s {\\&}]
    }

    # Regex for a folded search word: each ae/oe/ue/ss also matches its
    # umlaut, so "groesse" finds "Grösse" and "Größe" (use with -nocase).
    method _foldRe {w} {
        set re ""
        set n [string length $w]
        for {set i 0} {$i < $n} {incr i} {
            set two [string range $w $i [expr {$i + 1}]]
            switch -- $two {
                ae { append re "(?:ae|\u00e4)" ; incr i ; continue }
                oe { append re "(?:oe|\u00f6)" ; incr i ; continue }
                ue { append re "(?:ue|\u00fc)" ; incr i ; continue }
                ss { append re "(?:ss|\u00df)" ; incr i ; continue }
            }
            set c [string index $w $i]
            if {$c eq " "} { append re {\s+} ; continue }
            append re [my _reQuote $c]
        }
        return $re
    }

    # About 220 characters around the first hit, hits marked (HTML).
    # Hits are found in the plain text with the fold-aware regex, so mixed
    # spellings are found and marked; escaping happens per piece afterwards.
    method _snippet {text words} {
        set res {}
        foreach w [lsort -unique $words] {
            lappend res [list [string length $w] [my _foldRe $w]]
        }
        # longer words first, so an alternation prefers the longest hit
        set re [join [lmap r [lsort -integer -decreasing -index 0 $res] {
            lindex $r 1 }] |]
        set pos 0
        if {$re ne "" && [regexp -nocase -indices -- $re $text m]} {
            set pos [lindex $m 0]
        }
        set from [expr {max(0, $pos - 80)}]
        set s [string range $text $from [expr {$from + 220}]]
        set out ""
        set at 0
        if {$re ne ""} {
            foreach m [regexp -all -nocase -inline -indices -- $re $s] {
                lassign $m a b
                if {$b < $a} continue
                append out [my _esc [string range $s $at [expr {$a - 1}]]] \
                    "<mark>[my _esc [string range $s $a $b]]</mark>"
                set at [expr {$b + 1}]
            }
        }
        append out [my _esc [string range $s $at end]]
        if {$from > 0} { set out "&hellip; $out" }
        if {$from + 220 < [string length $text]} { append out " &hellip;" }
        return $out
    }

    # ------------------------------------------------------------------
    # Help for people who do not know the search (2026-11-05): tips with
    # examples from the documents, the query as understood (each part with
    # a link without it), help when nothing is found, counts per type and
    # folder, pages of 50 hits. Everything works without JavaScript.
    # ------------------------------------------------------------------

    # Percent-encoding of S (UTF-8) for a URL query value.
    method _urlEnc {s} {
        if {[catch {encoding convertto utf-8 $s} b]} {
            set b [encoding convertto -profile replace utf-8 $s]
        }
        set out ""
        foreach c [split $b ""] {
            if {[string first $c "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"] >= 0} {
                append out $c
            } else {
                append out [format %%%02X [scan $c %c]]
            }
        }
        return $out
    }

    # Text for Markdown (the plain styles): no markup, no HTML.
    method _mdEsc {s} {
        return [string map {\\ \\\\ \[ \\\[ \] \\\] * \\* _ \\_ ` \\` < &lt;} $s]
    }

    # URL of a search: CTX is a dict q in typ von page keep (keep: pairs
    # of parameters to pass on, style/theme/toc), ARGS override it. Empty
    # values and page 1 are left out.
    method _searchUrl {ctx args} {
        set c [dict merge $ctx $args]
        set pairs [list q [dict get $c q]]
        foreach k {in typ von} {
            if {[dict exists $c $k] && [dict get $c $k] ne ""} { lappend pairs $k [dict get $c $k] }
        }
        if {[dict exists $c page] && [dict get $c page] ni {"" 1}} {
            lappend pairs seite [dict get $c page]
        }
        if {[dict exists $c keep]} { lappend pairs {*}[dict get $c keep] }
        set qs {}
        foreach {k v} $pairs { lappend qs "$k=[my _urlEnc $v]" }
        return "/?[join $qs &]"
    }

    # A search URL for the parsed query PQ (q as text, in and typ as
    # parameters), with the rest of CTX.
    method _pqUrl {ctx pq} {
        return [my _searchUrl $ctx q [my _unparseQuery $pq 0] \
            in [dict get $pq in] typ [dict get $pq typ] page ""]
    }

    # The parameters a search passes on: style, theme, toc when the request
    # had them.
    method _searchKeep {req} {
        set keep {}
        foreach k {style theme toc} {
            if {[dict exists [$req params] $k]} { lappend keep $k [$req param $k] }
        }
        return $keep
    }

    # A term to show: a phrase in German quotes.
    method _showTerm {s} {
        if {[string first " " $s] >= 0} { return "\u201e$s\u201c" }
        return $s
    }

    # The parts of a parsed query, to show them: list of {kind label pq},
    # pq being the query without this part. kind: word phrase or not in typ.
    method _queryParts {pq} {
        set out {}
        set gs [dict get $pq gshow]
        set gr [dict get $pq groups]
        for {set i 0} {$i < [llength $gs]} {incr i} {
            set g [lindex $gs $i]
            if {[llength $g] > 1} {
                set kind or
                set label [join [lmap s $g {my _showTerm $s}] " oder "]
            } else {
                set kind [expr {[string first " " [lindex $g 0]] >= 0 ? "phrase" : "word"}]
                set label [my _showTerm [lindex $g 0]]
            }
            lappend out [list $kind $label [dict replace $pq \
                groups [lreplace $gr $i $i] gshow [lreplace $gs $i $i]]]
        }
        set xs [dict get $pq xshow]
        set ex [dict get $pq excl]
        for {set i 0} {$i < [llength $xs]} {incr i} {
            lappend out [list not "ohne [my _showTerm [lindex $xs $i]]" [dict replace $pq \
                excl [lreplace $ex $i $i] xshow [lreplace $xs $i $i]]]
        }
        if {[dict get $pq in] ne ""} {
            lappend out [list in "Bereich: [my _scopeTitle [dict get $pq in]]" [dict replace $pq in ""]]
        }
        if {[dict get $pq typ] ne ""} {
            lappend out [list typ "Typ: [my _typLabel [dict get $pq typ]]" [dict replace $pq typ ""]]
        }
        return $out
    }

    # "Gesucht:" with the parts of the query, each with a link without it.
    method _queryChips {pq ctx} {
        set parts [my _queryParts $pq]
        if {![llength $parts]} { return "" }
        set out "<div class=\"mds-query\"><span class=\"mds-query-label\" id=\"mds-query-label\">Gesucht:</span>\
<ul class=\"mds-chips\" aria-labelledby=\"mds-query-label\">"
        foreach p $parts {
            lassign $p kind label without
            set l [my _esc $label]
            append out "<li class=\"mds-chip mds-chip-$kind\"><span>$l</span>\
<a href=\"[my _esc [my _pqUrl $ctx $without]]\" title=\"Ohne diesen Baustein suchen\"\
 aria-label=\"$l entfernen\">\u00d7</a></li>"
        }
        append out "</ul></div>"
        return $out
    }

    method _queryChipsMd {pq ctx} {
        set parts [my _queryParts $pq]
        if {![llength $parts]} { return "" }
        set out {}
        foreach p $parts {
            lassign $p kind label without
            lappend out "[my _mdEsc $label] \[\u00d7\]([my _pqUrl $ctx $without])"
        }
        return "Gesucht: [join $out { &middot; }]\n\n"
    }

    # Words of the index for "Meinten Sie": dict byLen (length -> words),
    # df (word -> number of files holding it). Folded like the search. The
    # words of a file are in its index entry (_entryWords), made when the
    # file is read; here they are only counted (30 000 files: 0.1 s).
    method _searchWords {} {
        my variable _searchIdx
        set df [dict create]
        dict for {f e0} $_searchIdx {
            if {[dict exists $e0 words]} {
                set ws [dict get $e0 words]
            } else {
                set ws [my _entryWords $e0]
            }
            foreach w $ws { dict incr df $w }
        }
        set byLen [dict create]
        foreach w [dict keys $df] { dict lappend byLen [string length $w] $w }
        return [dict create byLen $byLen df $df]
    }

    # Edit distance of A and B, or MAX+1 when it is larger than MAX.
    method _levenshtein {a b {max 2}} {
        set la [string length $a] ; set lb [string length $b]
        if {abs($la - $lb) > $max} { return [expr {$max + 1}] }
        set prev {}
        for {set j 0} {$j <= $lb} {incr j} { lappend prev $j }
        for {set i 1} {$i <= $la} {incr i} {
            set ca [string index $a [expr {$i - 1}]]
            set cur [list $i]
            set low $i
            for {set j 1} {$j <= $lb} {incr j} {
                set v [expr {min([lindex $prev $j] + 1, [lindex $cur end] + 1,
                    [lindex $prev [expr {$j - 1}]] + ($ca ne [string index $b [expr {$j - 1}]]))}]
                lappend cur $v
                if {$v < $low} { set low $v }
            }
            if {$low > $max} { return [expr {$max + 1}] }
            set prev $cur
        }
        return [lindex $prev end]
    }

    # Up to MAX words of the index near W (folded, edit distance <= 2),
    # nearest and most frequent first. Candidates come from glob patterns
    # (W with one or two of its letters as *; each edit sits at one
    # letter), so only few words get the full distance.
    method _similarWords {w {max 3}} {
        if {![regexp {^[[:alnum:]_]{4,}$} $w]} { return {} }
        set words [my _perIndex words _searchWords]
        set byLen [dict get $words byLen]
        set n [string length $w]
        set pool {}
        for {set l [expr {$n - 2}]} {$l <= $n + 2} {incr l} {
            if {[dict exists $byLen $l]} { lappend pool {*}[dict get $byLen $l] }
        }
        set cand [dict create]
        for {set i 0} {$i < $n} {incr i} {
            for {set j $i} {$j < $n} {incr j} {
                set p [string replace $w $j $j *]
                set p [string replace $p $i $i *]
                foreach c [lsearch -all -inline -glob $pool $p] { dict set cand $c 1 }
            }
        }
        set df [dict get $words df]
        set scored {}
        foreach c [dict keys $cand] {
            if {$c eq $w} continue
            set d [my _levenshtein $w $c 2]
            if {$d <= 2} { lappend scored [list $c $d [dict get $df $c]] }
        }
        set scored [lsort -index 0 $scored]
        set scored [lsort -integer -decreasing -index 2 $scored]
        set scored [lsort -integer -index 1 $scored]
        return [lmap s [lrange $scored 0 [expr {$max - 1}]] { lindex $s 0 }]
    }

    # Is the folded term T anywhere in the index?
    method _termKnown {t} {
        my variable _searchIdx
        dict for {f e0} $_searchIdx {
            if {[dict exists $e0 pages]} { set entries [dict get $e0 pages] } else { set entries [list $e0] }
            foreach e $entries {
                if {[string first $t [dict get $e ftext]] >= 0
                        || [string first $t [dict get $e ftitle]] >= 0} { return 1 }
            }
        }
        return 0
    }

    # Help when RUN found nothing: list of {text links after}, links a list
    # of {label url}; text, labels and after are plain text.
    method _noneHelp {run ctx} {
        set pq [dict get $run pq]
        set out {}
        # (a) narrowed by folder or type: how many everywhere
        if {[dict get $pq in] ne "" || [dict get $pq typ] ne ""} {
            set wide [dict replace $pq in "" typ ""]
            set n [my _searchCount $wide]
            if {$n} {
                lappend out [list "" [list [list "\u00dcberall suchen ($n Treffer)" \
                    [my _pqUrl $ctx $wide]]] ""]
            } else {
                lappend out [list "Auch \u00fcberall nichts." {} ""]
            }
        }
        # (b) without the minus words; phrases as single words
        if {[llength [dict get $pq excl]]} {
            set wo [dict replace $pq excl {} xshow {}]
            set n [my _searchCount $wo]
            if {$n} {
                lappend out [list "" [list [list "Ohne die Minusw\u00f6rter suchen ($n Treffer)" \
                    [my _pqUrl $ctx $wo]]] ""]
            }
        }
        set groups {} ; set gshow {} ; set split 0
        foreach g [dict get $pq groups] s [dict get $pq gshow] {
            if {[llength $g] == 1 && [string first " " [lindex $g 0]] >= 0} {
                foreach t [split [lindex $g 0] " "] w [split [lindex $s 0] " "] {
                    if {[string length $t] < 2} continue
                    lappend groups [list $t] ; lappend gshow [list $w]
                }
                set split 1
            } else {
                lappend groups $g ; lappend gshow $s
            }
        }
        if {$split} {
            set loose [dict replace $pq groups $groups gshow $gshow]
            set n [my _searchCount $loose]
            if {$n} {
                lappend out [list "" [list [list "Die Wortfolgen als einzelne W\u00f6rter suchen ($n Treffer)" \
                    [my _pqUrl $ctx $loose]]] ""]
            }
        }
        # (c) words found nowhere: similar words of the index
        set lowor [dict get $pq lowor]
        set fix {}
        set first ""
        foreach g [dict get $pq groups] {
            foreach t $g {
                if {$lowor ne "" && $t in {or oder}} continue
                if {[dict exists $fix $t] || ![regexp {^[[:alnum:]_]{4,}$} $t]} continue
                if {[my _termKnown $t]} continue
                set sim [my _similarWords $t 3]
                if {![llength $sim]} continue
                dict set fix $t $sim
                if {$first eq ""} { set first $t }
            }
        }
        if {$first ne ""} {
            set links {}
            foreach alt [dict get $fix $first] {
                set groups {} ; set gshow {}
                foreach g [dict get $pq groups] s [dict get $pq gshow] {
                    set ng {} ; set ns {}
                    foreach t $g w $s {
                        if {$t eq $first} {
                            set t $alt ; set w $alt
                        } elseif {[dict exists $fix $t]} {
                            set w [lindex [dict get $fix $t] 0] ; set t $w
                        }
                        lappend ng $t ; lappend ns $w
                    }
                    lappend groups $ng ; lappend gshow $ns
                }
                set apq [dict replace $pq groups $groups gshow $gshow]
                lappend links [list [my _unparseQuery $apq 0] [my _pqUrl $ctx $apq]]
            }
            lappend out [list "Meinten Sie: " $links "?"]
        }
        # (d) a lower-case or/oder between two words is a word
        if {$lowor ne ""} {
            lappend out [list "\u201eor\u201c und \u201eoder\u201c klein geschrieben sind Suchw\u00f6rter;\
                verkn\u00fcpft wird nur mit ODER, OR oder \u201e|\u201c: " \
                [list [list $lowor [my _searchUrl $ctx q $lowor \
                    in [dict get $pq in] typ [dict get $pq typ] page ""]]] ""]
        }
        return $out
    }

    method _searchCount {pq} {
        return [llength [my _searchHits $pq]]
    }

    method _noneHtml {help} {
        if {![llength $help]} { return "" }
        set out "<ul class=\"mds-none\">"
        foreach h $help {
            lassign $h text links after
            append out "<li>[my _esc $text][join [lmap l $links {
                set _ "<a href=\"[my _esc [lindex $l 1]]\">[my _esc [lindex $l 0]]</a>"
            }] ", "][my _esc $after]</li>"
        }
        append out "</ul>"
        return $out
    }

    method _noneMd {help} {
        set out ""
        foreach h $help {
            lassign $h text links after
            append out "- [my _mdEsc $text][join [lmap l $links {
                set _ "\[[my _mdEsc [lindex $l 0]]\]([lindex $l 1])"
            }] ", "][my _mdEsc $after]\n"
        }
        return $out
    }

    # Counts per type (over the hits in the folder, any type) and the three
    # folders below the current one with the most hits, as links.
    method _facets {run ctx} {
        set pq [dict get $run pq]
        set typ [dict get $pq typ]
        set byTyp [dict create]
        foreach h [dict get $run all] { dict incr byTyp [dict get $h kind] }
        set out ""
        if {[dict size $byTyp] > 1 || $typ ne ""} {
            set li ""
            if {$typ ne ""} {
                append li "<li><a href=\"[my _esc [my _pqUrl $ctx [dict replace $pq typ {}]]]\">alle Typen\
                    ([llength [dict get $run all]] Treffer)</a></li>"
            }
            foreach k {md pdf office csv} {
                if {![dict exists $byTyp $k]} continue
                set l "[my _typLabel $k] ([dict get $byTyp $k] Treffer)"
                if {$k eq $typ} {
                    append li "<li><strong aria-current=\"true\">$l</strong></li>"
                } else {
                    append li "<li><a href=\"[my _esc [my _pqUrl $ctx [dict replace $pq typ $k]]]\">$l</a></li>"
                }
            }
            append out "<div class=\"mds-facet\"><span id=\"mds-facet-typ\">Typ:</span>\
<ul aria-labelledby=\"mds-facet-typ\">$li</ul></div>"
        }
        set scope [dict get $pq in]
        set byDir [dict create]
        foreach h [dict get $run hits] {
            set rel [dict get $h rel]
            if {$scope ne ""} { set rel [string range $rel [string length "$scope/"] end] }
            set parts [split $rel /]
            if {[llength $parts] < 2} continue
            set d [lindex $parts 0]
            if {$scope ne ""} { set d "$scope/$d" }
            dict incr byDir $d
        }
        set dirs [lsort -integer -decreasing -index 1 [lsort -index 0 [lmap {d n} $byDir { list $d $n }]]]
        if {[llength $dirs] > 1 || ([llength $dirs] == 1 && [lindex $dirs 0 1] < [dict get $run total])} {
            set li ""
            foreach dn [lrange $dirs 0 2] {
                lassign $dn d n
                set name [my _dirTitle [file join [my cfg root] {*}[split $d /]]]
                append li "<li><a href=\"[my _esc [my _pqUrl $ctx [dict replace $pq in $d]]]\">[my _esc $name]\
                    ($n Treffer)</a></li>"
            }
            append out "<div class=\"mds-facet\"><span id=\"mds-facet-dir\">Ordner:</span>\
<ul aria-labelledby=\"mds-facet-dir\">$li</ul></div>"
        }
        if {$out eq ""} { return "" }
        return "<nav class=\"mds-facets\" aria-label=\"Treffer eingrenzen\">$out</nav>"
    }

    # "1-50 von 213" and back/next, or "" for a single page.
    method _pageNav {run ctx {md 0}} {
        set pages [dict get $run pages]
        if {$pages < 2} { return "" }
        set page [dict get $run page]
        set links {}
        if {$page > 1} {
            set u [my _searchUrl $ctx q [my _unparseQuery [dict get $run pq] 0] \
                in [dict get $run pq in] typ [dict get $run pq typ] page [expr {$page - 1}]]
            lappend links prev "\u00ab zur\u00fcck" $u
        }
        lappend links "" "Seite $page von $pages" ""
        if {$page < $pages} {
            set u [my _searchUrl $ctx q [my _unparseQuery [dict get $run pq] 0] \
                in [dict get $run pq in] typ [dict get $run pq typ] page [expr {$page + 1}]]
            lappend links next "weiter \u00bb" $u
        }
        set out {}
        foreach {rel label u} $links {
            if {$md} {
                lappend out [expr {$u eq "" ? $label : "\[$label\]($u)"}]
            } elseif {$u eq ""} {
                lappend out "<span>$label</span>"
            } else {
                lappend out "<a rel=\"$rel\" href=\"[my _esc $u]\">$label</a>"
            }
        }
        if {$md} { return "[join $out { &middot; }]\n" }
        return "<nav class=\"mds-search-pages\" aria-label=\"Trefferseiten\">[join $out " "]</nav>"
    }

    # "1-50 von 213 Treffern" or "12 Treffer".
    method _countText {run} {
        set total [dict get $run total]
        if {[dict get $run pages] < 2} { return "$total Treffer" }
        set from [expr {[dict get $run from] + 1}]
        set to [expr {[dict get $run from] + [llength [dict get $run shown]]}]
        return "$from\u2013$to von $total Treffern"
    }

    # Words of TITLES, most frequent first (as written, counted folded).
    method _titleWords {titles} {
        set stop {aber alle auch eine einer eines fuer ueber oder sowie und unter
            mit nach ohne von vom zum zur dass with from into that this what your
            about the and}
        set cnt [dict create] ; set orig [dict create]
        foreach t $titles {
            foreach w [lsort -unique [regexp -all -inline {[[:alpha:]]{4,}} $t]] {
                set k [my _fold $w]
                if {$k in $stop} continue
                dict incr cnt $k
                if {![dict exists $orig $k]} { dict set orig $k $w }
            }
        }
        set l [lsort -integer -decreasing -index 1 [lsort -index 0 [lmap {k n} $cnt { list $k $n }]]]
        return [lmap kn $l { dict get $orig [lindex $kn 0] }]
    }

    # Examples for the tips, from the documents: dict word word2 phrase
    # dir dirword, and typ -> word for each type present.
    method _tipExamples {} {
        my variable _searchIdx
        set root [my cfg root]
        set byKind [dict create] ; set byDir [dict create]
        dict for {f e} $_searchIdx {
            set kind [expr {[dict exists $e kind] ? [dict get $e kind] : "md"}]
            set t [expr {$kind eq "pdf" ? [file rootname [file tail $f]] : [dict get $e title]}]
            dict lappend byKind $kind $t
            set parts [file split [string range $f [string length $root] end]]
            set parts [lsearch -all -inline -not -regexp $parts {^[/\\]$}]
            if {[llength $parts] > 1 && [regexp {^[^\s"-][^\s"]*$} [lindex $parts 0]]} {
                dict lappend byDir [lindex $parts 0] $t
            }
        }
        set ex [dict create word "" word2 "" phrase "" dir "" dirword "" typ {}]
        if {[dict exists $byKind md]} {
            set main [dict get $byKind md]
        } else {
            set main [concat {*}[dict values $byKind]]
        }
        set words [my _titleWords $main]
        dict set ex word [lindex $words 0]
        dict set ex word2 [lindex $words 1]
        # two words of a title, as they stand there
        set w1 [my _fold [lindex $words 0]]
        foreach t [lsort -dictionary $main] {
            if {[regexp {\m([[:alpha:]]{3,}) ([[:alpha:]]{3,})\M} $t -> a b]} {
                if {[dict get $ex phrase] eq "" || [string first $w1 [my _fold $t]] >= 0} {
                    dict set ex phrase "$a $b"
                    if {[string first $w1 [my _fold $t]] >= 0} break
                }
            }
        }
        set best "" ; set bn 0
        foreach d [lsort [dict keys $byDir]] {
            if {[llength [dict get $byDir $d]] > $bn} { set best $d ; set bn [llength [dict get $byDir $d]] }
        }
        if {$best ne ""} {
            dict set ex dir $best
            dict set ex dirword [lindex [my _titleWords [dict get $byDir $best]] 0]
        }
        dict for {k ts} $byKind {
            dict set ex typ $k [lindex [my _titleWords $ts] 0]
        }
        return $ex
    }

    # The tips: what can be typed, with an example from the documents.
    method _searchTips {open ctx} {
        set ex [my _perIndex tips _tipExamples]
        set w  [dict get $ex word]
        set w2 [dict get $ex word2]
        set ph [dict get $ex phrase]
        set rows {}
        lappend rows {Wort Wort} "Dokumente mit allen W\u00f6rtern; Gro\u00df/klein egal,\
            ae/oe/ue/ss findet auch \u00e4/\u00f6/\u00fc/\u00df" $w
        lappend rows {"Wort Wort"} "die W\u00f6rter in dieser Reihenfolge" \
            [expr {$ph eq "" ? "" : "\"$ph\""}]
        lappend rows {-Wort  -"Wort Wort"} "ohne Dokumente, die das enthalten" \
            [expr {$w ne "" && $w2 ne "" ? "$w -$w2" : ""}]
        lappend rows {a ODER b  a OR b  a | b} "eins von beiden; nur gro\u00df geschrieben\
            (\u201eoder\u201c ist ein Suchwort)" \
            [expr {$w ne "" && $w2 ne "" ? "$w ODER $w2" : ""}]
        lappend rows {in:ordner} "nur unterhalb dieses Ordners (auch unten als Bereich)" \
            [expr {[dict get $ex dir] ne "" && [dict get $ex dirword] ne ""
                ? "[dict get $ex dirword] in:[dict get $ex dir]" : ""}]
        set what {md "nur Markdown-Dateien" pdf "nur PDF-Seiten"
            office "nur Office-Dateien (Word, Excel, ODF)" csv "nur CSV-Dateien"}
        foreach k [my _searchTyps] {
            set tw [expr {[dict exists $ex typ $k] ? [dict get $ex typ $k] : ""}]
            lappend rows "typ:$k" [dict get $what $k] [expr {$tw eq "" ? "" : "$tw typ:$k"}]
        }
        set body ""
        foreach {in eff e} $rows {
            set ins [join [lmap i [split [string map {"  " \x01} $in] \x01] {
                set _ "<code>[my _esc $i]</code>" }] " "]
            set cell "&ndash;"
            if {$e ne ""} {
                set cell "<a href=\"[my _esc [my _searchUrl $ctx q $e in {} typ {} page {}]]\">[my _esc $e]</a>"
            }
            append body "<tr><td>$ins</td><td>$eff</td><td>$cell</td></tr>"
        }
        set o [expr {$open ? " open" : ""}]
        return "<details class=\"mds-search-tips\"$o><summary>Suchtipps</summary>\
<table><thead><tr><th scope=\"col\">Eingabe</th><th scope=\"col\">Wirkung</th>\
<th scope=\"col\">Beispiel</th></tr></thead><tbody>$body</tbody></table></details>"
    }

    # The results as HTML (site style) ...
    method _searchBody {query {in ""} {typ ""} {von ""} {page 1} {keep {}}} {
        set run [my _searchRun $query $in $typ $page]
        set pq [dict get $run pq]
        set ctx [dict create q $query in $in typ $typ von [my _searchScope $von] page "" keep $keep]
        set q [my _esc $query]
        set hidden ""
        foreach {k v} $keep {
            append hidden "<input type=\"hidden\" name=\"[my _esc $k]\" value=\"[my _esc $v]\">"
        }
        set empty [expr {[string trim $query] eq ""}]
        set body "<h1>Suche</h1>
<form class=\"mds-search-big\" action=\"/\" method=\"get\" role=\"search\">\
<label for=\"mds-q\" class=\"mds-sr\">Suchbegriffe</label>\
<input type=\"search\" id=\"mds-q\" name=\"q\" value=\"$q\" autofocus><button type=\"submit\">Suchen</button>\
[my _searchFilters [dict get $pq in] [dict get $pq typ] $von]$hidden</form>
[my _searchTips $empty $ctx]"
        if {$empty} { return $body }
        append body [my _queryChips $pq $ctx]
        set offen [my _pdfPending]
        if {$offen} {
            append body "<p class=\"mds-note\">[my _pdfPendingText $offen]</p>"
        }
        set offen [my _indexPending]
        if {$offen} {
            append body "<p class=\"mds-note\">[my _indexPendingText $offen]</p>"
        }
        if {![dict get $run total]} {
            append body "<p class=\"mds-lead\" role=\"status\" aria-live=\"polite\">Nichts gefunden f&uuml;r <strong>$q</strong>.</p>"
            append body [my _noneHtml [my _noneHelp $run $ctx]]
            return $body
        }
        append body "<p class=\"mds-lead\" role=\"status\" aria-live=\"polite\">[my _countText $run]\
            f&uuml;r <strong>$q</strong></p>"
        append body [my _facets $run $ctx]
        set start [expr {[dict get $run from] ? " start=\"[expr {[dict get $run from] + 1}]\"" : ""}]
        append body "<ol class=\"mds-hits\"$start>"
        foreach h [dict get $run shown] {
            set path [dict get $h path]
            append body "<li><a href=\"[my _esc [dict get $h url]]\">[my _esc [dict get $h title]]</a>"
            if {$path ne ""} { append body "<div class=\"mds-hit-path\">[my _esc $path]</div>" }
            append body "<p>[dict get $h snippet]</p></li>"
        }
        append body "</ol>"
        append body [my _pageNav $run $ctx]
        return $body
    }

    # The two choices under the search field: folder (everywhere, or one of
    # the folders above the page the search came from, or the current in)
    # and type. Folders are offered only if they exist under the root. A
    # change sends the form (onchange); without JavaScript the button does.
    method _searchFilters {in typ von} {
        set root [my cfg root]
        set dirs {}
        set acc {}
        foreach p [split [my _searchScope $von] /] {
            if {$p eq ""} continue
            lappend acc $p
            set d [join $acc /]
            if {[file isdirectory [file join $root {*}$acc]]} { lappend dirs $d }
        }
        if {$in ne "" && $in ni $dirs && [file isdirectory [file join $root {*}[split $in /]]]} {
            lappend dirs $in
        }
        set out ""
        set submit "onchange=\"this.form.submit()\""
        if {[llength $dirs]} {
            append out "<span><label for=\"mds-in\">Bereich</label>\
<select id=\"mds-in\" name=\"in\" $submit>"
            append out "<option value=\"\"[expr {$in eq "" ? " selected" : ""}]>\u00fcberall</option>"
            foreach d $dirs {
                set sel [expr {$d eq $in ? " selected" : ""}]
                append out "<option value=\"[my _esc $d]\"$sel>[my _esc [my _scopeTitle $d]]</option>"
            }
            append out "</select></span>"
            # keep the origin for the next search from this page
            append out "<input type=\"hidden\" name=\"von\" value=\"[my _esc [my _searchScope $von]]\">"
        }
        append out "<span><label for=\"mds-typ\">Typ</label>\
<select id=\"mds-typ\" name=\"typ\" $submit>"
        set opts [list "" alle]
        foreach k [my _searchTyps] { lappend opts $k [my _typLabel $k] }
        foreach {v l} $opts {
            set sel [expr {$v eq $typ ? " selected" : ""}]
            append out "<option value=\"$v\"$sel>$l</option>"
        }
        append out "</select></span>"
        return "<div class=\"mds-search-filter\">$out</div>"
    }

    # The state of the index for the status: number of files, and whether
    # it is being built or since when it stands.
    method _indexZustand {} {
        my variable _searchIdx _vorabFiles _vorabFresh _indexGanz _searchScanAt
        set n [expr {[info exists _searchIdx] ? [dict size $_searchIdx] : 0}]
        if {[info exists _vorabFiles]} {
            set gelesen [dict size $_vorabFresh]
            set alle [expr {$gelesen + [llength $_vorabFiles]}]
            if {[info exists _indexGanz]} {
                return "$n files, checking in the background ($gelesen of $alle)"
            }
            return "building ($gelesen of $alle files read)"
        }
        if {![info exists _indexGanz]} { return "not built yet" }
        set alt [expr {[clock seconds] - $_searchScanAt}]
        return "$n files, checked $alt s ago"
    }
    # reload: read every file again, in the background. The old index
    # answers until the new one is done.
    method _indexNeu {} {
        my variable _vorabFiles _vorabNeu
        if {[info exists _vorabFiles]} { set _vorabNeu 1; return }
        set _vorabNeu 1
        my _indexVorab
    }

    # Files the first, stepwise build of the index has not read yet
    # (0 once there is a whole index).
    method _indexPending {} {
        my variable _vorabFiles _indexGanz
        if {[info exists _indexGanz] || ![info exists _vorabFiles]} { return 0 }
        return [llength $_vorabFiles]
    }
    method _indexPendingText {n} {
        set was [expr {$n == 1 ? "1 Datei ist" : "$n Dateien sind"}]
        return "Der Suchindex wird nach dem Start noch aufgebaut; $was noch nicht\
            gelesen und fehlen in dieser Liste. Sp\u00e4ter noch einmal suchen."
    }
    method _pdfPendingText {n} {
        set was [expr {$n == 1 ? "1 PDF wird" : "$n PDFs werden"}]
        return "$was noch gelesen; ihre Seiten fehlen in dieser Liste.\
            Sp\u00e4ter noch einmal suchen."
    }

    # ... as JSON (?format=json, any style), with tclutils::tujson:
    #   {"query":..., "pending":N, "total":N, "page":N, "pages":N,
    #    "hits":[{"url","title","path","snippet","score"}]}
    # The snippet is plain text, without <mark>. total, page and pages
    # since 2026-11-05 (?seite=N; hits are the 50 of that page). Without
    # tujson: 501.
    method _searchJson {query in typ {page 1}} {
        my _tclutilsPath
        if {[catch {package require tclutils::tujson 0.1}]} { return "" }
        set J ::tclutils::tujson
        set run [my _searchRun $query $in $typ $page]
        set hits {}
        foreach h [dict get $run shown] {
            set sn [regsub -all {<[^>]*>} [dict get $h snippet] ""]
            set sn [string map {&hellip; \u2026 &lt; < &gt; > &quot; \" &amp; &} $sn]
            lappend hits [${J}::obj [list \
                url     [${J}::str [dict get $h url]] \
                title   [${J}::str [dict get $h title]] \
                path    [${J}::str [dict get $h path]] \
                snippet [${J}::str $sn] \
                score   [${J}::num [dict get $h score]]]]
        }
        return [${J}::toJson [${J}::obj [list \
            query   [${J}::str $query] \
            pending [${J}::num [my _pdfPending]] \
            indexing [${J}::num [my _indexPending]] \
            total   [${J}::num [dict get $run total]] \
            page    [${J}::num [dict get $run page]] \
            pages   [${J}::num [dict get $run pages]] \
            hits    [${J}::arr $hits]]]]
    }

    method _sendSearchJson {chan req} {
        set j [my _searchJson [$req param q ""] [$req param in ""] [$req param typ ""] \
            [$req param seite 1]]
        if {$j eq ""} {
            my _notiz $chan "search json: no tujson"
            my _send $chan "501 Not Implemented" "text/plain; charset=utf-8" \
                "format=json needs tclutils::tujson\n"
            return
        }
        my _notiz $chan "search json"
        my _send $chan "200 OK" "application/json; charset=utf-8" $j
    }

    # ... and as Markdown for the other styles: the query as understood,
    # help when nothing is found, pages of 50.
    method _searchMd {query {in ""} {typ ""} {page 1} {keep {}}} {
        set md "# Suche: [my _mdEsc $query]\n\n"
        if {[string trim $query] eq ""} {
            return "$md*\"Wortfolge\" &middot; -ohne &middot; a ODER b &middot; in:ordner &middot; typ:md*\n"
        }
        set run [my _searchRun $query $in $typ $page]
        set pq [dict get $run pq]
        set ctx [dict create q $query in $in typ $typ von "" page "" keep $keep]
        append md [my _queryChipsMd $pq $ctx]
        set offen [my _pdfPending]
        if {$offen} { append md "*[my _pdfPendingText $offen]*\n\n" }
        set offen [my _indexPending]
        if {$offen} { append md "*[my _indexPendingText $offen]*\n\n" }
        if {![dict get $run total]} {
            append md "*Nichts gefunden.*\n\n"
            append md [my _noneMd [my _noneHelp $run $ctx]]
            return $md
        }
        if {[dict get $run pages] > 1} { append md "*[my _countText $run].*\n\n" }
        foreach h [dict get $run shown] {
            append md "- \[[my _mdEsc [dict get $h title]]\]([dict get $h url])"
            if {[dict get $h path] ne ""} { append md " -- [my _mdEsc [dict get $h path]]" }
            append md "\n"
        }
        set nav [my _pageNav $run $ctx 1]
        if {$nav ne ""} { append md "\n$nav" }
        return $md
    }
}
