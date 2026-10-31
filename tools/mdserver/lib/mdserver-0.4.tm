# mdserver-0.4.tm -- Markdown-Web-Server Modul (coroutine/non-blocking)
# ============================================================================
# HTTP/HTTPS server for Markdown documents.
# No Tk, no fonts, no display. Requires only Tcl 8.6+.
#
# Classes:
#   mdserver::Request  -- parse an HTTP request
#   mdserver::Renderer -- Markdown + index -> HTML
#   mdserver::Server   -- HTTP/HTTPS server
#
# Requires: mdstack::parser 0.2, mdstack::html 0.1
# Optional: mdstack::theme 0.1, tls (for HTTPS)
# ============================================================================

package provide mdserver 0.4

# Der Server-Kopf kommt aus der Paketfassung, nicht aus drei getippten Zahlen.
# Bis 0.3 stand in derselben Datei zweimal "mdserver/0.5", einmal
# "mdserver/0.4" und einmal "mdserver 0.4" -- bei Paketfassung 0.3. Keine der
# Angaben stimmte, und keine stimmte mit einer anderen ueberein.
namespace eval ::mdserver {
    variable serverHeader "mdserver/[package provide mdserver]"
}

package require Tcl 8.6 9
# ============================================================
# Load modules
# ============================================================

if {[catch {package require mdstack::parser 0.2} err]} {
    puts stderr "ERROR: mdparser 0.2 not found: $err"
    exit 1
}
if {[catch {package require mdstack::html 0.1} err]} {
    puts stderr "ERROR: mdhtml 0.1 not found: $err"
    exit 1
}
if {[catch {package require mdstack::theme 0.1} err]} {
    # Optional: without it the pages fall back to the docir default CSS,
    # i.e. --theme has no effect.
    puts stderr "WARNING: mdstack::theme 0.1 not found -- themes disabled: $err"
}

# ============================================================
# MIME types (global, immutable)
# ============================================================

namespace eval mdserver {
    variable moduleDir [file dirname [file normalize [info script]]]
    # Options for every channel that reads a document: under Tcl 9 invalid
    # UTF-8 becomes U+FFFD, as under 8.6, instead of a read error (a
    # Markdown file with one bad byte answered 500, a folder holding it
    # could not be listed). Added 2026-10-30.
    variable readOpts [expr {[package vsatisfies [package provide Tcl] 9-] ? {-profile replace} : {}}]
    variable mimeTypes {
        .html  "text/html; charset=utf-8"
        .htm   "text/html; charset=utf-8"
        .css   "text/css; charset=utf-8"
        .js    "application/javascript; charset=utf-8"
        .json  "application/json"
        .txt   "text/plain; charset=utf-8"
        .md    "text/plain; charset=utf-8"
        .png   "image/png"
        .jpg   "image/jpeg"
        .jpeg  "image/jpeg"
        .gif   "image/gif"
        .svg   "image/svg+xml"
        .ico   "image/x-icon"
        .pdf   "application/pdf"
        .xml   "application/xml"
        .csv   "text/csv; charset=utf-8"
        .odt   "application/vnd.oasis.opendocument.text"
        .ods   "application/vnd.oasis.opendocument.spreadsheet"
        .odp   "application/vnd.oasis.opendocument.presentation"
        .docx  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        .xlsx  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }
}

# ============================================================
# Coroutine-aware, non-blocking gets.
# Returns the line length, -1 on EOF/timeout. Yields until a
# complete line is available -- the readable event (or the timeout)
# resumes the coroutine. A slow connection never blocks the others.
# ============================================================
# max > 0: bricht ab, sobald mehr als max Bytes ohne Zeilenende im Puffer
# liegen -- Rueckgabe -2. Die Pruefung muss VOR dem Warten stehen und am
# Puffer haengen, nicht an der fertigen Zeile: eine Zeile ohne \n waechst
# sonst unbegrenzt, und genau das soll die Grenze verhindern.
proc mdserver::coGets {chan _line {max 0}} {
    upvar 1 $_line line
    while {1} {
        set n [gets $chan line]
        if {$n >= 0} {
            if {$max > 0 && $n > $max} { return -2 }
            return $n
        }
        if {[eof $chan]} { return -1 }
        if {$max > 0 && [chan pending input $chan] > $max} { return -2 }
        if {[yield] eq "TIMEOUT"} { return -1 }
    }
}

# ============================================================
# mdserver::Request -- parse an HTTP request
# ============================================================

oo::class create mdserver::Request {

    variable _method _path _query _headers _params

    # maxline: Bytes je Zeile (Anfragezeile und jede Kopfzeile).
    # maxheader: Summe aller Kopfzeilen. 0 heisst ohne Grenze.
    # Beide mit Vorgabe, damit vorhandene Aufrufe unveraendert bleiben.
    constructor {chan {maxline 8190} {maxheader 16384}} {
        set _method  ""
        set _path    ""
        set _query   ""
        set _headers {}
        set _params  {}
        my _parse $chan $maxline $maxheader
    }

    # Public accessors
    method method  {} { return $_method  }
    method path    {} { return $_path    }
    method query   {} { return $_query   }
    method headers {} { return $_headers }
    method params  {} { return $_params  }

    method header {name} {
        set key [string tolower $name]
        if {[dict exists $_headers $key]} {
            return [dict get $_headers $key]
        }
        return ""
    }

    method param {name {default ""}} {
        if {[dict exists $_params $name]} {
            return [dict get $_params $name]
        }
        return $default
    }

    # Private: read request line + headers
    method _parse {chan maxline maxheader} {
        # Request line (coroutine, non-blocking)
        set n [mdserver::coGets $chan requestLine $maxline]
        if {$n == -2} { throw {MDDOCS URITOOLONG} "request line over $maxline bytes" }
        if {$n < 0}   { throw {MDDOCS BADREQUEST} {connection closed/timeout} }

        # Headers until blank line
        set summe 0
        while {1} {
            set n [mdserver::coGets $chan line $maxline]
            if {$n == -2} { throw {MDDOCS HEADERTOOBIG} "header line over $maxline bytes" }
            if {$n < 0} break
            set line [string trimright $line]
            if {$line eq ""} break
            incr summe [string length $line]
            if {$maxheader > 0 && $summe > $maxheader} {
                throw {MDDOCS HEADERTOOBIG} "headers over $maxheader bytes"
            }
            if {[regexp {^([^:]+):\s*(.*)$} $line -> k v]} {
                dict set _headers [string tolower $k] $v
            }
        }

        # Method + URL
        #
        # Zwei verschiedene Faelle, die bis 0.3.1 beide gleich endeten -- die
        # Verbindung wurde ohne Antwort geschlossen, der Klient sah "empty
        # reply". Ein POST ist aber kein kaputter Aufruf, sondern ein
        # verstandener mit einer Methode, die es hier nicht gibt: 405 mit
        # "Allow: GET, HEAD" (RFC 9110 15.5.6).
        if {![regexp {^(GET|HEAD)\s+(/[^\s]*)\s+HTTP} $requestLine \
                -> _method rawUrl]} {
            if {[regexp {^([A-Z]+)\s+(/[^\s]*)\s+HTTP} $requestLine -> m u]} {
                set _method $m
                set _path $u
                # Die Methode steht im Fehlercode, der Pfad in der Meldung:
                # geworfen wird hier im Konstruktor, also gibt es noch kein
                # Request-Objekt, an dem der Aufrufer den Pfad ablesen koennte.
                throw [list MDDOCS METHOD $m] $u
            }
            throw {MDDOCS BADREQUEST} "Invalid request line: $requestLine"
        }

        # Split URL and query
        if {[string first ? $rawUrl] >= 0} {
            regexp {^([^?]*)(\?(.*))?$} $rawUrl -> _path _ _query
        } else {
            set _path $rawUrl
        }
        try {
            set _path [my _urlDecode $_path 0 1]
        } trap {MDDOCS BADURL} {m} {
            # thrown in the constructor: method and URL go with the error
            throw [list MDDOCS BADURL $_method $m] $rawUrl
        }
        set _params [my _parseQuery $_query]
    }

    # %XX to bytes, then UTF-8. Without subst: up to 2026-10-30 the %XX
    # became "[binary format H2 XX]" and the whole string went through
    # subst -- a request like /x[exec+...] ran Tcl commands in the server.
    # "+" is a space only in the query (form encoding), not in the path.
    # strict 1 (path): a % without two hex digits and NUL are an error
    # {MDDOCS BADURL} (400); strict 0 (query): such a % stays as text,
    # a typed "?q=50%" still searches. Invalid UTF-8 stays as the bytes
    # (iso8859-1), as Tcl 8.6 did.
    method _urlDecode {str {plus 0} {strict 0}} {
        if {$plus} { set str [string map {+ " "} $str] }
        # The request line is read as UTF-8: raw characters (curl sends
        # them unencoded) back to bytes, so they and the %XX bytes are one
        # byte string.
        set str [encoding convertto utf-8 $str]
        set out ""
        while {[set i [string first % $str]] >= 0} {
            append out [string range $str 0 [expr {$i - 1}]]
            set hex [string range $str [expr {$i + 1}] [expr {$i + 2}]]
            if {[regexp {^[0-9A-Fa-f]{2}$} $hex] && $hex ne "00"} {
                append out [binary format H2 $hex]
                set str [string range $str [expr {$i + 3}] end]
            } elseif {$strict} {
                throw {MDDOCS BADURL} "invalid percent encoding"
            } else {
                append out %
                set str [string range $str [expr {$i + 1}] end]
            }
        }
        append out $str
        if {$strict && [string first \0 $out] >= 0} {
            throw {MDDOCS BADURL} "NUL in path"
        }
        if {[package vsatisfies [package provide Tcl] 9-]} {
            if {[catch {encoding convertfrom -profile strict utf-8 $out} t]} { return $out }
            return $t
        }
        set t [encoding convertfrom utf-8 $out]
        if {[encoding convertto utf-8 $t] ne $out} { return $out }
        return $t
    }

    method _parseQuery {query} {
        set result {}
        foreach pair [split $query &] {
            if {$pair eq ""} continue
            set kv [split $pair =]
            set k [my _urlDecode [lindex $kv 0] 1]
            set v [my _urlDecode [join [lrange $kv 1 end] =] 1]
            dict set result $k $v
        }
        return $result
    }
}

# ============================================================
# mdserver::Renderer -- Markdown + index -> HTML
# ============================================================

oo::class create mdserver::Renderer {

    variable _title
    variable _docKinds

    constructor {title} {
        set _title $title
        set _docKinds [dict create .pdf PDF]
    }

    # Which files besides .md the site index lists: a dict extension ->
    # label (PDF, Word, ...). The server sets it from what it can show.
    method setDocKinds {kinds} { set _docKinds $kinds }

    method markdown {path theme toc {cssFile ""}} {
        return [my markdownText [my _readFile $path] $theme $toc $cssFile]
    }

    # The same for Markdown text (a generated page, e.g. a book landing).
    method markdownText {md theme toc {cssFile ""}} {
        set ast [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc $toc -lang de]
        set html [my _injectTheme $html $theme]
        return [my _injectCss $html $cssFile]
    }

    # Insert the theme CSS as an extra <style> after the default one.
    #
    # The theme name is passed down to docir::html, but that only knows its own
    # default CSS ("manpage" | "none" | default) -- hell / dunkel / solarized
    # mean nothing to it, so every page would come out identical. The theme's
    # own CSS (mdstack::theme::toCSS) is therefore appended here: same
    # specificity, later rule wins.
    #
    # Degrades silently: no mdstack::theme package, or an unknown theme name,
    # leaves the page with the default CSS instead of throwing.
    method _injectTheme {html theme} {
        if {$theme eq "" || $theme eq "none"} { return $html }
        set css ""
        if {[catch { set css [mdstack::theme::toCSS $theme] }]} { return $html }
        if {[string trim $css] eq ""} { return $html }
        return [my _insertStyle $html "<style>\n$css\n</style>\n"]
    }

    # Insert the chosen style as an extra <style> after the theme --
    # render has no -css; the style rules win via the CSS cascade.
    method _injectCss {html cssFile} {
        if {$cssFile eq "" || ![file exists $cssFile]} { return $html }
        set css ""
        catch { set css [my _readFile $cssFile] }
        if {$css eq ""} { return $html }
        return [my _insertStyle $html "<style>\n$css\n</style>\n"]
    }

    # Put a <style> block at the end of <head> (else before </body>, else last).
    method _insertStyle {html block} {
        set idx [string first "</head>" $html]
        if {$idx < 0} { set idx [string first "</body>" $html] }
        if {$idx >= 0} {
            return "[string range $html 0 [expr {$idx - 1}]]$block[string range $html $idx end]"
        }
        return "$html$block"
    }

    # Directory listing (when a directory has no index.md): build a small
    # Markdown document and render it through mdstack -- the same path every
    # other page uses, so the look stays consistent (no hand-built HTML).
    method index {dirPath urlPath theme {cssFile ""}} {
        set base [string trimright $urlPath /]
        set h1 [expr {$base eq "" ? $_title : "[file tail $base]/"}]

        set items {}
        if {$urlPath ne "/"} {
            lappend items "- \[..\](../)"
        }
        foreach d [lsort [glob -nocomplain -directory $dirPath -type d *]] {
            set name [file tail $d]
            if {$name in {. ..}} continue
            lappend items "- \[$name/\]($name/)"
        }
        foreach f [lsort [glob -nocomplain -directory $dirPath *.md]] {
            lappend items "- \[[my _mdTitle $f]\]([file tail $f])"
        }

        set md "# $h1

"
        if {[llength $items] == 0} {
            append md "_No documents found._
"
        } else {
            append md [join $items "
"] "
"
        }

        set ast  [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc 0 -lang de]
        set html [my _injectTheme $html $theme]
        return [my _injectCss $html $cssFile]
    }

    # Site index: all .md under rootDir as a recursive tree.
    method siteIndex {rootDir theme {cssFile ""}} {
        set md "# Alle Dokumente\n\n"
        set tree [my _tree $rootDir $rootDir 0]
        if {[string trim $tree] eq ""} {
            append md "_Keine Markdown-Dokumente gefunden._\n"
        } else {
            append md $tree
        }
        set ast [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc 0 -lang de]
        set html [my _injectTheme $html $theme]
        return [my _injectCss $html $cssFile]
    }

    # Recursive Markdown list (directories bold, .md as links).
    method _tree {rootDir dir depth} {
        set out ""
        set pad [string repeat "  " $depth]
        foreach sub [lsort [glob -nocomplain -type d -directory $dir *]] {
            if {[file tail $sub] in {. ..}} continue
            append out "$pad- **[file tail $sub]/**\n"
            append out [my _tree $rootDir $sub [expr {$depth + 1}]]
        }
        foreach fpath [lsort [glob -nocomplain -type f -directory $dir *.md]] {
            set rel   [my _relUrl $rootDir $fpath]
            set title [my _mdTitle $fpath]
            append out "$pad- \[$title\]\($rel\)\n"
        }
        # PDFs and the other documents the server shows, marked as such
        foreach fpath [lsort -dictionary [glob -nocomplain -type f -directory $dir *]] {
            set ext [string tolower [file extension $fpath]]
            if {![dict exists $_docKinds $ext]} continue
            set rel [string map {" " %20} [my _relUrl $rootDir $fpath]]
            append out "$pad- \[[file rootname [file tail $fpath]]\]\($rel\) ([dict get $_docKinds $ext])\n"
        }
        return $out
    }

    # Server URL of a file relative to the root.
    method _relUrl {rootDir fpath} {
        set rel [string range $fpath [string length $rootDir] end]
        return "/[string trimleft $rel /]"
    }

    # Title = first H1, else file name.
    method _mdTitle {fpath} {
        set title [file tail $fpath]
        if {![catch {open $fpath r} fh]} {
            fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
            while {[gets $fh line] >= 0} {
                if {[regexp {^#\s+(.+)$} $line -> t]} {
                    set title [string trim $t]; break
                }
            }
            close $fh
        }
        return $title
    }

    method _readFile {path} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
        try {
            return [read $fh]
        } finally {
            close $fh
        }
    }
}

# ============================================================
# mdserver::Server -- HTTP/HTTPS server
# ============================================================

oo::class create mdserver::Server {

    variable _cfg _renderer _httpSock _httpsSock _connSeq _conns _ctrlSock

    constructor {args} {
        # Defaults
        array set opts {
            port    8080
            bind    ""
            dotfiles 0
            pdfsearch auto
            pdfcache  ""
            pdfworker 1
            officesearch auto
            csvview   auto
            officeview auto
            trustedproxy ""
            maxline    8190
            maxheader  16384
            healthpath "/__mdserver/health"

            root    "."
            theme   "hell"
            title   "mdserver"
            index   "index.md"
            nav     1
            toc     1
            log     1
            cert    ""
            key     ""
            tlsport 8443
            timeout 15000
            control ""
            style      "site"
            stylesdir  ""
            navbg      "#2c3e50"
            navfg      "#ffffff"
            navlinks   {{{&#127968; Start} /} {{&#128218; Alle Dokumente} /?nav=index}}
            navsections 1
            navmax      6
            navmore     "&#128193; Bereiche"
            chapternav  1
        }
        # Read arguments
        foreach {k v} $args {
            set opts([string trimleft $k -]) $v
        }
        set opts(root) [file normalize $opts(root)]
        set opts(tls)  0
        set _cfg [array get opts]

        set _renderer [mdserver::Renderer new [my cfg title]]
        set _httpSock  ""
        set _httpsSock ""
        set _connSeq   0
        set _conns     {}
        set _ctrlSock  ""
        set ::mdserver::running 1
    }

    destructor {
        my stop
        $_renderer destroy
    }

    # Config accessor
    method cfg {key} {
        return [dict get $_cfg $key]
    }

    # Start the server
    method start {} {
        # Load TLS optionally
        if {[my cfg cert] ne "" && [my cfg key] ne ""} {
            if {[catch {package require tls} err]} {
                puts stderr "WARNING: tls not available -- HTTPS disabled: $err"
            } else {
                dict set _cfg tls 1
            }
        }

        # HTTP
        #
        # bind: an welche Adresse. Leer heisst alle Schnittstellen -- das war
        # bis 0.3.1 die einzige Moeglichkeit, und der Steuerport war die
        # einzige Stelle mit -myaddr. Steht mdserver hinter einem nginx, das
        # die Anmeldung macht, muss der HTTP-Port auf 127.0.0.1 liegen: sonst
        # ist er von aussen offen UND unangemeldet, und die Anmeldung haengt
        # allein an der Firewall. (Ein LAN-Konzept vom 28.09.2026 nannte eine
        # Option --bind, die es damals nicht gab.)
        set myaddr {}
        if {[my cfg bind] ne ""} { set myaddr [list -myaddr [my cfg bind]] }
        try {
            set _httpSock [socket -server [list [self object] handleRequest] \
                {*}$myaddr [my cfg port]]
        } on error {err} {
            set wo [expr {[my cfg bind] eq "" ? "" : " on [my cfg bind]"}]
            error "Cannot bind to HTTP port [my cfg port]$wo: $err"
        }

        # HTTPS
        if {[my cfg tls]} {
            if {![file exists [my cfg cert]]} {
                error "Certificate not found: [my cfg cert]"
            }
            if {![file exists [my cfg key]]} {
                error "Key not found: [my cfg key]"
            }
            try {
                tls::init \
                    -certfile [my cfg cert] \
                    -keyfile  [my cfg key]  \
                    -ssl2 0 -ssl3 0 -tls1 0 -tls1.2 1

                set _httpsSock [tls::socket \
                    -server [list [self object] handleRequest] \
                    -command [list [self object] tlsEvent] \
                    {*}$myaddr [my cfg tlsport]]
            } on error {err} {
                error "Cannot start HTTPS on port [my cfg tlsport]: $err"
            }
        }

        # Control port (localhost only) -- clean stop/reload without PID lookup
        if {[my cfg control] ne ""} {
            if {[catch {
                set _ctrlSock [socket -server [list [self object] controlAccept] \
                    -myaddr 127.0.0.1 [my cfg control]]
            } err]} {
                puts stderr "WARNING: control port [my cfg control] not bound: $err"
            }
        }

        my _printStatus
        # Read the PDFs not yet in the cache now, in the background, so the
        # first search does not find them missing.
        if {[my _pdfOn] && [my _pdfWorkerOn]} {
            after 300 [namespace code {catch {my _searchIndex}}]
        }
    }

    method stop {} {
        catch { close $_httpSock  }
        catch { close $_httpsSock }
        catch { close $_ctrlSock  }
        foreach ch [dict keys $_conns] { catch { close $ch } }
        set _conns {}
        my _pdfWorkerClose
    }

    # Style name (?style=) -> path to a CSS file in styles/, or "" (default).
    # sidebar | sticky | collapsible ; anything else = no extra CSS (plain).
    method _styleCss {style} {
        set dir [my cfg stylesdir]
        if {$dir eq ""} { set dir [file join $::mdserver::moduleDir .. styles] }
        switch -- $style {
            site        { set f site.css }
            sidebar     { set f sidebar.css }
            sticky      { set f sticky-top.css }
            collapsible { set f collapsible.css }
            default     { return "" }
        }
        set p [file normalize [file join $dir $f]]
        return [expr {[file exists $p] ? $p : ""}]
    }

    # Insert the nav bar (Start + site index) at the top of every page.
    # Top-level sections of the doc root as {label url} pairs, for the nav bar.
    # A section is shown if it (transitively) contains any .md; the label is the
    # section index.md H1, else the folder name.
    method _sectionLinks {} {
        set out {}
        set root [my cfg root]
        foreach d [lsort -dictionary [glob -nocomplain -directory $root -type d *]] {
            set name [file tail $d]
            if {[string index $name 0] eq "."} continue
            if {![my _dirHasAnyMd $d]} continue
            set label $name
            set idx [file join $d index.md]
            if {[file exists $idx]} {
                set t [my _h1Title $idx]
                if {$t ne ""} { set label $t }
            }
            set label [string map {& &amp; < &lt; > &gt;} $label]
            lappend out [list $label "/$name/"]
        }
        return $out
    }

    # True if $dir contains any .md file or another document (PDF, and the
    # office and CSV files the server shows, see _docKinds) -- transitively.
    # A folder of PDFs is a folder of documents too (up to 2026-10-20 it was
    # hidden from the navigation, the sidebar and the folder cards); one of
    # Word or Excel files was hidden up to 2026-10-30.
    method _dirHasAnyMd {dir} {
        if {[llength [glob -nocomplain -directory $dir *.md]] > 0} { return 1 }
        if {[llength [my _pdfsIn $dir]] > 0} { return 1 }
        foreach d [glob -nocomplain -directory $dir -type d *] {
            if {[string index [file tail $d] 0] eq "."} continue
            if {[my _dirHasAnyMd $d]} { return 1 }
        }
        return 0
    }

    # The documents of a folder besides .md (any case of the extension),
    # sorted: PDFs and the kinds of _docKinds.
    method _pdfsIn {dir} {
        set kinds [my _docKinds]
        set out {}
        foreach f [glob -nocomplain -directory $dir -type f *] {
            if {[dict exists $kinds [string tolower [file extension $f]]]
                && [string index [file tail $f] 0] ne "."} { lappend out $f }
        }
        return [lsort -dictionary $out]
    }

    # Extension -> label of the documents shown besides .md: PDF always,
    # office files with --office-view, CSV with --csv-view.
    method _docKinds {} {
        set k [dict create .pdf PDF]
        foreach {ext kind} [my _officeViewExts] {
            dict set k $ext [dict get {docx Word odt Text odp Folien xlsx Excel ods Tabelle} $kind]
        }
        if {[my _csvOn]} { dict set k .csv CSV }
        return $k
    }

    # Label of a document for cards: "PDF, 820 KB", "Word, 36 KB".
    method _docLabel {f} {
        set kinds [my _docKinds]
        set ext [string tolower [file extension $f]]
        if {[dict exists $kinds $ext]} {
            set l [dict get $kinds $ext]
        } else {
            set l [string toupper [string range $ext 1 end]]
        }
        return "$l, [my _sizeLabel $f]"
    }

    # Size for a listing: "820 KB", "2,8 MB".
    method _sizeLabel {f} {
        set b [file size $f]
        if {$b < 1024 * 1024} { return "[expr {($b + 1023) / 1024}] KB" }
        return "[string map {. ,} [format %.1f [expr {$b / 1048576.0}]]] MB"
    }

    # First "# H1" of a Markdown file, or "" if none.
    method _h1Title {file} {
        set title ""
        set cmdName ""
        set nameLine ""
        if {![catch {open $file r} fh]} {
            fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
            set n 0
            set inYaml 0
            set afterName 0
            while {[gets $fh line] >= 0} {
                incr n
                # YAML head of a Tcl manual page (TIP 700): CommandName
                if {$n == 1 && $line eq "---"} { set inYaml 1; continue }
                if {$inYaml} {
                    if {$line eq "---"} { set inYaml 0; continue }
                    regexp {^CommandName:\s*(\S.*?)\s*$} $line -> cmdName
                    continue
                }
                if {$afterName} {
                    if {[string trim $line] eq ""} continue
                    set nameLine [string trim $line]
                    break
                }
                if {[regexp {^#\s+(.+)$} $line -> t]} {
                    set title [string trim $t]
                    if {![my _isManSection $title]} break
                    set afterName 1
                }
            }
            close $fh
        }
        if {[my _isManSection $title]} {
            set t [my _manTitle $cmdName $nameLine]
            if {$t ne ""} { return $t }
        }
        return $title
    }

    # A manual page converted to Markdown starts with "# NAME" (or the
    # German "# NAME"/"# BEZEICHNUNG"). Then every page would be called
    # NAME in the sidebar and in the title. Gemessen 2026-10-21 an den
    # deutschen Tcl/Tk-Handbuchseiten: 645 Seiten, alle hiessen "NAME".
    method _isManSection {t} {
        return [expr {[string toupper $t] in {NAME BEZEICHNUNG}}]
    }

    # Title of a manual page: CommandName from the YAML head, else the
    # part of the NAME line before " - " ("canvas - Erstellt ..." -> canvas).
    method _manTitle {cmdName nameLine} {
        if {$cmdName ne ""} { return $cmdName }
        regsub -all {[*`\\]} $nameLine {} nameLine
        if {[regexp {^(.+?)\s+[-\u2013\u2014]\s} $nameLine -> t]} { return [string trim $t] }
        return ""
    }

    # Chapter list of a bookkit book (dir with book.tcl): the "chapters" list
    # from book.tcl (safe interp), else numeric-prefix order.
    method _bookChapters {dir} {
        set chapters {}
        set bt [file join $dir book.tcl]
        if {[file exists $bt]} {
            set ip [interp create -safe]
            interp eval $ip {set chapters {}}
            catch {
                set fh [open $bt r]; fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
                set script [read $fh]; close $fh
                interp eval $ip $script
                set chapters [interp eval $ip {set chapters}]
            }
            interp delete $ip
        }
        if {[llength $chapters] == 0} {
            # bookkit web-index block in index.md: reuse its chapter links.
            set idx [file join $dir index.md]
            if {[file exists $idx]} {
                set fh [open $idx r]; fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
                set text [read $fh]; close $fh
                if {[regexp {<!-- bookkit:toc:begin -->(.*?)<!-- bookkit:toc:end -->} $text -> blk]} {
                    foreach {full url} [regexp -all -inline {\]\(([^)]+\.md)\)} $blk] {
                        if {![string match "*/*" $url] && ![string match "http*" $url]} {
                            lappend chapters $url
                        }
                    }
                }
            }
        }
        if {[llength $chapters] == 0} { set chapters [my _prefixOrdered $dir] }
        return $chapters
    }

    # A directory is treated as a book if it has book.tcl or its index.md
    # carries a bookkit web-index block.
    method _isBookDir {dir} {
        if {[file exists [file join $dir book.tcl]]} { return 1 }
        set idx [file join $dir index.md]
        if {[file exists $idx]} {
            set fh [open $idx r]; fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
            set text [read $fh]; close $fh
            if {[string first "<!-- bookkit:toc:begin -->" $text] >= 0} { return 1 }
        }
        return 0
    }

    # Sidebar book navigation: the full chapter list (current one highlighted).
    # Only in sidebar style and inside a book.
    method _injectBookNav {html fsPath style} {
        if {$style ne "sidebar"} { return $html }
        set dir [file dirname $fsPath]
        if {![my _isBookDir $dir]} { return $html }
        set chapters [my _bookChapters $dir]
        if {[llength $chapters] == 0} { return $html }
        set cur [file tail $fsPath]
        set items ""
        foreach ch $chapters {
            set label [my _chapterLabel [file join $dir $ch]]
            set cls [expr {$ch eq $cur ? " class=\"cur\"" : ""}]
            append items "<li$cls><a href=\"$ch\">$label</a></li>"
        }
        set nav "<nav class=\"mdserver-booknav\">\
<input type=\"checkbox\" id=\"mdserver-booknav-toggle\" class=\"booknav-toggle\">\
<label for=\"mdserver-booknav-toggle\" class=\"booknav-toggle-label\">&#128214; Kapitel</label>\
<div class=\"booknav-title\"><a href=\"index.md\">&uarr; &Uuml;bersicht</a></div>\
<ul>$items</ul></nav>\n"
        if {[regexp -indices {<body[^>]*>} $html m]} {
            set e [lindex $m 1]
            return "[string range $html 0 $e]\n$nav[string range $html [expr {$e+1}] end]"
        }
        return "$nav$html"
    }

    # *.md ordered by numeric prefix (index.md / indexsub.md excluded).
    method _prefixOrdered {dir} {
        set withNum {}; set noNum {}
        foreach fp [glob -nocomplain -directory $dir *.md] {
            set name [file tail $fp]
            if {$name in {index.md indexsub.md}} continue
            if {[regexp {^(\d+)} $name -> p]} {
                lappend withNum [list [scan $p %d] $name]
            } else {
                lappend noNum $name
            }
        }
        set out {}
        foreach pair [lsort -integer -index 0 $withNum] { lappend out [lindex $pair 1] }
        foreach fp [lsort $noNum] { lappend out $fp }
        return $out
    }

    # Chapter link label: cleaned H1, else file base name (HTML-escaped).
    method _chapterLabel {file} {
        set t [my _h1Title $file]
        if {$t eq ""} { set t [file rootname [file tail $file]] }
        regsub -all {\[([^\]]*)\]\{[^\}]*\}} $t {\1} t
        regsub -all {\[([^\]]*)\]\([^)]*\)} $t {\1} t
        regsub -all {\{[^\}]*\}} $t {} t
        return [string map {& &amp; < &lt; > &gt;} [string trim $t]]
    }

    # In a book (dir with book.tcl), append a prev / up / next chapter bar to a
    # chapter page. index.md and non-chapter files are left unchanged.
    method _injectChapterNav {html fsPath} {
        if {![my cfg chapternav]} { return $html }
        set dir  [file dirname $fsPath]
        set name [file tail $fsPath]
        if {$name eq "index.md"} { return $html }
        if {![my _isBookDir $dir]} { return $html }
        set chapters [my _bookChapters $dir]
        set i [lsearch -exact $chapters $name]
        if {$i < 0} { return $html }

        set link {color:#0055aa;text-decoration:none;}
        if {$i > 0} {
            set p [lindex $chapters [expr {$i - 1}]]
            set prev "<a href=\"$p\" style=\"$link\">&larr; [my _chapterLabel [file join $dir $p]]</a>"
        } else { set prev "<span></span>" }
        if {$i < [expr {[llength $chapters] - 1}]} {
            set n [lindex $chapters [expr {$i + 1}]]
            set next "<a href=\"$n\" style=\"$link\">[my _chapterLabel [file join $dir $n]] &rarr;</a>"
        } else { set next "<span></span>" }
        set up "<a href=\"index.md\" style=\"$link\">&uarr; &Uuml;bersicht</a>"

        set bar "<nav class=\"mdserver-chapnav\" style=\"display:flex;\
justify-content:space-between;align-items:center;gap:1em;\
margin:2.5em 0 0;padding:0.8em 0;border-top:1px solid #ccc;font-size:0.95em;\">\
$prev$up$next</nav>\n"

        set idx [string first "</body>" $html]
        if {$idx >= 0} {
            return "[string range $html 0 [expr {$idx - 1}]]$bar[string range $html $idx end]"
        }
        return "$html$bar"
    }

    # One nav bar link. Never wraps inside itself -- a label breaks the bar
    # between links, not inside a title.
    method _navLink {label url fg} {
        return "<a href=\"$url\" style=\"color:$fg;text-decoration:none;white-space:nowrap;\">$label</a>"
    }

    # Sections folded into one CSS-only dropdown (no JavaScript: details/summary).
    method _navDropdown {sections bg fg} {
        set items ""
        foreach link $sections {
            lassign $link label url
            append items [my _navLink $label $url $fg]
        }
        set label [my cfg navmore]
        return "<details class=\"mdserver-navmore\">\
<summary style=\"color:$fg;\">$label</summary>\
<div class=\"mdserver-navmore-items\">$items</div></details>"
    }

    # Stylesheet for the nav bar: wrapping as a safety net, plus the dropdown.
    method _navCss {bg fg} {
        set css {
.mdserver-nav { flex-wrap: wrap; row-gap: 0.4em; }
.mdserver-navmore { position: relative; }
.mdserver-navmore > summary { cursor: pointer; list-style: none; white-space: nowrap; }
.mdserver-navmore > summary::-webkit-details-marker { display: none; }
.mdserver-navmore-items { display: none; position: absolute; top: 1.8em; left: 0;
    z-index: 100; flex-direction: column; gap: 0.5em; padding: 0.7em 1em;
    min-width: 14em; border-radius: 0 0 4px 4px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.28);
    background: __BG__; color: __FG__; }
.mdserver-navmore[open] > .mdserver-navmore-items { display: flex; }
}
        return "<style>[string map [list __BG__ $bg __FG__ $fg] $css]</style>"
    }

    method _injectNav {html} {
        if {![my cfg nav]} { return $html }
        set bg [my cfg navbg]
        set fg [my cfg navfg]
        # Links from config: a list of {label url} pairs.
        set links ""
        foreach link [my cfg navlinks] {
            lassign $link label url
            append links [my _navLink $label $url $fg]
        }
        # Top-level sections, auto-derived from the document root. More than
        # navmax of them are folded into a single dropdown, so the bar stays
        # one line however many sections the root grows. navmax 0 = never fold.
        set css ""
        if {[my cfg navsections]} {
            set sections [my _sectionLinks]
            set max      [my cfg navmax]
            if {![string is integer -strict $max]} { set max 0 }
            if {$max > 0 && [llength $sections] > $max} {
                append links [my _navDropdown $sections $bg $fg]
                set css [my _navCss $bg $fg]
            } else {
                foreach link $sections {
                    lassign $link label url
                    append links [my _navLink $label $url $fg]
                }
            }
        }
        set style "background:$bg;color:$fg;padding:0.5em 1em;\
margin:0 calc(50% - 50vw) 1em;width:100vw;box-sizing:border-box;\
font-size:0.95em;display:flex;gap:1.4em;align-items:center;align-self:start;\
flex-wrap:wrap;row-gap:0.4em;"
        set bar "$css<nav class=\"mdserver-nav\" style=\"$style\">$links</nav>
"
        if {[regexp -indices {<body[^>]*>} $html m]} {
            set e [lindex $m 1]
            return "[string range $html 0 $e]
$bar[string range $html [expr {$e + 1}] end]"
        }
        return "$bar$html"
    }

    # Clean shutdown: close listeners + open connections, end the loop.
    # Sauber beenden: nur die HORCHSOCKETS zu, damit keine neue Verbindung
    # mehr dazukommt. Laufende Antworten bleiben stehen -- auf die wartet
    # _beendeSanft.
    #
    # Bis 0.4 rief shutdown my stop, und das schliesst alle offenen
    # Verbindungen sofort und leert _conns. Danach kann kein Warten mehr
    # greifen: wer gerade eine grosse PDF holte, bekam sie mitten im Byte
    # abgeschnitten, und zwar bei jedem systemctl restart.
    method shutdown {} {
        catch { close $_httpSock  }
        catch { close $_httpsSock }
        catch { close $_ctrlSock  }
        set _httpSock  ""
        set _httpsSock ""
        set _ctrlSock  ""
        catch { set ::mdserver::running 0 }
        # a PDF being read for the search: kill the worker (tutask cancel)
        catch { my _pdfWorkerClose }
    }

    # Eine Antwort auf den Steuerport -- blockierend geschrieben.
    #
    # Das ist eine Haertung, KEINE Fehlerbehebung: 0.3.4 hat hier schon
    # richtig geantwortet. Dass es zunaechst anders aussah, lag am Klienten,
    # nicht am Server -- OpenBSD-netcat, das Standard-nc auf Debian, schliesst
    # die Senderichtung nach EOF auf stdin nicht und wartet weiter:
    #
    #     echo ping | nc    127.0.0.1 8099   -> leer, laeuft in den Timeout
    #     echo ping | nc -N 127.0.0.1 8099   -> pong
    #
    # Deshalb liegt mdctl.tcl daneben, und deshalb steht in der Startmeldung
    # nicht mehr "echo stop | nc". Hier sind es wenige Bytes auf eine
    # Loopback-Verbindung und der Steuerport ist kein Lastpfad, also ist
    # blockierend einfacher und ohne Nachteil.
    method _ctrlAntwort {chan text} {
        catch {
            fconfigure $chan -blocking 1
            puts $chan $text
            flush $chan
        }
        catch {close $chan}
    }

    # Laufende Antworten zu Ende bringen, dann beenden. Ein hartes exit mitten
    # in einer grossen PDF liefert dem Leser eine halbe Datei.
    method _beendeSanft {{restMs 5000}} {
        if {[dict size $_conns] == 0} {
            my _log "shutdown: fertig"
            exit 0
        }
        if {$restMs <= 0} {
            my _log "shutdown: [dict size $_conns] Verbindung(en) abgeschnitten"
            my stop
            exit 0
        }
        # namespace code, nicht [list [self object] _beendeSanft ...]: eine
        # private Methode ist von aussen nicht aufrufbar, und ein after-Skript
        # laeuft aussen. Gemessen als
        #   Background error: unknown method "_beendeSanft"
        after 100 [namespace code [list my _beendeSanft [expr {$restMs - 100}]]]
    }

    # Control connection (localhost): one line, one command (stop|ping).
    method controlAccept {chan addr port} {
        fconfigure $chan -blocking 0 -buffering line -translation crlf
        fileevent $chan readable [list [self object] controlRead $chan]
    }
    method controlRead {chan} {
        if {[catch {gets $chan line} n] || $n < 0} {
            if {[eof $chan]} { catch {close $chan} }
            return
        }
        set cmd [string tolower [string trim $line]]
        switch -- $cmd {
            stop {
                my _ctrlAntwort $chan "stopping"
                my _log "control: stop"
                my shutdown
                my _beendeSanft
            }
            ping    { my _ctrlAntwort $chan "pong" }
            default { my _ctrlAntwort $chan "commands: stop ping" }
        }
    }

    # Accept callback -- one coroutine per connection (non-blocking)
    method handleRequest {chan addr port} {
        coroutine ::mdserver::conn[incr _connSeq] [self object] serveConn $chan $addr $port
    }

    # TLS events: silently drop handshake errors from broken connections
    # (e.g. non-TLS clients on the HTTPS port), no stderr noise.
    method tlsEvent {command args} {
        switch -- $command {
            verify  { return 1 }
            error   -
            info    -
            default { return }
        }
    }

    # Serve the connection -- runs as a coroutine
    method serveConn {chan addr port} {
        # Tcl 9: invalid bytes in the request line would be a read error
        # (connection closed without an answer); replaced, they give 404.
        chan configure $chan -blocking 0 -buffering full \
            -translation crlf -encoding utf-8 {*}$::mdserver::readOpts
        dict set _conns $chan 1
        # readable event resumes this coroutine; timeout guards against slow-loris
        chan event $chan readable [info coroutine]
        set tid [after [my cfg timeout] [list catch [list [info coroutine] TIMEOUT]]]

        # Fuer die Protokollzeile, die am Ende entsteht. Ohne verstandene
        # Anfragezeile bleibt es bei "- -".
        set woher   $addr
        set methode "-"
        set pfad    "-"

        try {
            set req [mdserver::Request new $chan [my cfg maxline] [my cfg maxheader]]
            after cancel $tid
            chan event $chan readable {}

            # HEAD: derselbe Kopf wie bei GET, aber kein Koerper (RFC 9110
            # 9.3.2). Der Merker haengt am Kanal, siehe _koerper.
            variable _nurKopf
            set _nurKopf($chan) [expr {[$req method] eq "HEAD"}]

            set xff [string trim [my _woher $addr $req]]
            if {$xff ne ""} { set woher $xff }
            set methode [$req method]
            set pfad    [$req path]

            set theme [$req param theme [my cfg theme]]
            set toc   [$req param toc   [my cfg toc]]
            set style [$req param style [my cfg style]]
            set path  [$req path]

            my _dispatch $chan $req $path $theme $toc $style

        } trap {MDDOCS METHOD} {u opts} {
            set methode [lindex [dict get $opts -errorcode] 2]
            set pfad    $u
            my _send $chan "405 Method Not Allowed" "text/html; charset=utf-8" \
                "<html><body><h1>405 Method Not Allowed</h1><p>mdserver liest nur: GET, HEAD.</p></body></html>" \
                {Allow {GET, HEAD}}
        } trap {MDDOCS BADURL} {u opts} {
            set methode [lindex [dict get $opts -errorcode] 2]
            set pfad    $u
            my _notiz $chan [lindex [dict get $opts -errorcode] 3]
            my _send $chan "400 Bad Request" "text/html; charset=utf-8" \
                "<html><body><h1>400 Bad Request</h1></body></html>"
        } trap {MDDOCS URITOOLONG} {m} {
            if {$methode eq "-"} { set methode "?" }
            # Eine ueberlange Anfragezeile: der Klient soll es erfahren, nicht
            # raten. 414, und der Puffer waechst nicht weiter (RFC 9110 15.5.15).
            my _notiz $chan $m
            my _send $chan "414 URI Too Long" "text/html; charset=utf-8" \
                "<html><body><h1>414 URI Too Long</h1></body></html>"
        } trap {MDDOCS HEADERTOOBIG} {m} {
            if {$methode eq "-"} { set methode "?" }
            my _notiz $chan $m
            my _send $chan "431 Request Header Fields Too Large" "text/html; charset=utf-8" \
                "<html><body><h1>431 Request Header Fields Too Large</h1></body></html>"
        } trap {MDDOCS BADREQUEST} {} {
            # Broken connection / timeout / invalid request -- ignore silently
        } on error {msg} {
            my _notiz $chan "bgerror: $msg"
            puts stderr "mdserver bgerror: $msg"
        } finally {
            after cancel $tid
            # Eine Zeile je Anfrage, erst hier: vorher sind Status und Bytes
            # nicht bekannt. Eine Verbindung ohne verstandene Anfragezeile
            # (BADREQUEST) bekommt keine -- da gibt es nichts zu protokollieren.
            if {$methode ne "-"} { my _zeile $chan $woher $methode $pfad }
            my _zeileWeg $chan
            variable _nurKopf
            unset -nocomplain _nurKopf($chan)
            my _flushClose $chan
        }
    }

    # Wer hat geholt? Hinter einem Proxy steht als Gegenstelle immer dessen
    # Adresse, also braucht man X-Forwarded-For -- aber den setzt der Proxy
    # nur DAVOR, anhaengen kann ihn jeder. Bis 0.3.1 glaubte mdserver ihn
    # ungeprueft: ein direktes
    #
    #     curl -H "X-Forwarded-For: 9.9.9.9" http://server:8080/
    #
    # schrieb 9.9.9.9 ins Protokoll. Eine falsche Angabe ist schlechter als
    # keine. Seit 0.3.2 wird der Kopf nur gelesen, wenn die GEGENSTELLE in
    # --trusted-proxy steht; Vorgabe leer heisst: gar nicht.
    #
    # Verglichen wird auf genaue Uebereinstimmung, keine Netzmasken -- ein
    # halb verstandenes CIDR waere hier schlimmer als keins. Wer dem Loopback
    # traut, traut damit allem, was auf demselben Rechner laeuft.
    method _woher {addr req} {
        if {[lsearch -exact [my cfg trustedproxy] $addr] < 0} { return "" }
        set woher ""
        catch {
            set xff [$req header X-Forwarded-For]
            if {$xff ne ""} {
                # Nur der ERSTE Eintrag: alles dahinter hat der Klient selbst
                # mitgebracht, der Proxy haengt seinen Teil hinten an.
                set erste [string trim [lindex [split $xff ,] 0]]
                if {[regexp {^[0-9a-fA-F.:]+$} $erste]} { set woher "$erste " }
            }
        }
        return $woher
    }

    # Drain output buffer non-blocking, then close (never blocks the loop)
    method _flushClose {chan} {
        catch {
            chan configure $chan -blocking 0
            while {1} {
                flush $chan
                if {[chan pending output $chan] <= 0} break
                chan event $chan writable [info coroutine]
                yield
                chan event $chan writable {}
            }
        }
        catch {close $chan}
        catch {dict unset _conns $chan}
    }

    # Routing
    # ------------------------------------------------------------------
    # Style "site": one layout instead of stacked stylesheets.
    #
    # The other styles put a stylesheet over docir's page and make <body>
    # a grid -- every body child became a grid cell, so a long sidebar
    # pushed the text below a gap the height of the sidebar. "site" takes
    # only the rendered body and builds the page itself: header, sidebar
    # (book chapters or the folder), main column with breadcrumbs, an
    # "on this page" column for long pages. CSS-only, no JavaScript.
    # ------------------------------------------------------------------

    method _esc {s} {
        return [string map {& &amp; < &lt; > &gt; \" &quot;} $s]
    }

    # Inner HTML of <body>, and the <title>.
    method _bodyOf {html} {
        if {[regexp {(?s)<body[^>]*>(.*)</body>} $html -> inner]} { return $inner }
        return $html
    }

    # book.tcl as data (safe interp): dict title subtitle lang date chapters.
    method _bookMeta {dir} {
        set meta [dict create title "" subtitle "" lang "" date "" chapters {}]
        set bt [file join $dir book.tcl]
        if {![file exists $bt]} { return $meta }
        set ip [interp create -safe]
        catch {
            set fh [open $bt r]; fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
            set script [read $fh]; close $fh
            interp eval $ip $script
            foreach k {title subtitle lang date chapters} {
                if {[interp eval $ip [list info exists $k]]} {
                    dict set meta $k [interp eval $ip [list set $k]]
                }
            }
        }
        interp delete $ip
        return $meta
    }

    # Title of a folder: book title, index.md H1, README.md H1, folder name.
    method _dirTitle {dir} {
        if {[file exists [file join $dir book.tcl]]} {
            set t [dict get [my _bookMeta $dir] title]
            if {$t ne ""} { return $t }
        }
        foreach f {index.md README.md} {
            set p [file join $dir $f]
            if {[file exists $p]} {
                set t [my _h1Title $p]
                if {$t ne ""} { return [my _plainLabel $t] }
            }
        }
        return [file tail $dir]
    }

    # Markdown decoration off a title: [x]{.index} -> x, [x](u) -> x.
    method _plainLabel {t} {
        regsub -all {\[([^\]]*)\]\{[^\}]*\}} $t {\1} t
        regsub -all {\[([^\]]*)\]\([^)]*\)} $t {\1} t
        regsub -all {\{[^\}]*\}} $t {} t
        regsub -all {[*_`]} $t {} t
        return [string trim $t]
    }

    # First prose paragraph of a Markdown file (headings, quotes, code,
    # lists and tables skipped), shortened to about LEN characters.
    method _firstPara {file {len 180}} {
        if {[catch {open $file r} fh]} { return "" }
        fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
        set para "" ; set inCode 0
        while {[gets $fh line] >= 0} {
            if {[regexp {^\s*(```|~~~)} $line]} { set inCode [expr {!$inCode}] ; continue }
            if {$inCode} continue
            set l [string trim $line]
            if {$l eq ""} { if {$para ne ""} break ; continue }
            if {[regexp {^(#|>|\||-{3,}|\*{3,}|[-*+] |\d+\. |<|\*Stand|_Stand)} $l]} {
                if {$para ne ""} break
                continue
            }
            append para " " $l
        }
        close $fh
        set para [my _plainLabel $para]
        if {[string length $para] > $len} {
            set cut [string last " " $para $len]
            if {$cut < 40} { set cut $len }
            set para "[string range $para 0 [expr {$cut - 1}]] ..."
        }
        return $para
    }

    # Is DIR a book or does it hold one directly (a bookkit wrapper)?
    method _bookEditions {dir} {
        set out {}
        foreach d [lsort [glob -nocomplain -directory $dir -type d *]] {
            if {[file exists [file join $d book.tcl]]} { lappend out $d }
        }
        return $out
    }

    # bookkit writes <name>.pdf / <name>.html next to the book folder.
    # Returns {label url ...} relative to a page inside the book folder.
    method _bookDownloads {bookDir} {
        set out {}
        set name [file tail $bookDir]
        foreach ext {pdf html} label {PDF HTML} {
            if {[file exists [file join [file dirname $bookDir] $name.$ext]]} {
                lappend out $label "../$name.$ext"
            }
        }
        return $out
    }

    # Landing page of a book without index.md, as Markdown: title, subtitle,
    # the README's first paragraph, downloads, chapter list. The chapter bar
    # and the sidebar link "Uebersicht" point here -- without it they gave 404.
    method _bookLandingMd {dir} {
        set m [my _bookMeta $dir]
        set title [dict get $m title]
        if {$title eq ""} { set title [file tail $dir] }
        set md "# $title\n\n"
        if {[dict get $m subtitle] ne ""} { append md "*[dict get $m subtitle]*\n\n" }
        foreach f [list [file join $dir README.md] [file join [file dirname $dir] README.md]] {
            if {[file exists $f]} {
                set p [my _firstPara $f 400]
                if {$p ne ""} { append md "$p\n\n" ; break }
            }
        }
        set dl [my _bookDownloads $dir]
        if {[llength $dl]} {
            set parts {}
            foreach {label url} $dl { lappend parts "\[$label\]($url)" }
            append md "**Download:** [join $parts { | }]\n\n"
        }
        append md "## Kapitel\n\n"
        set i 0
        foreach ch [my _bookChapters $dir] {
            append md "[incr i]. \[[my _chapterLabel [file join $dir $ch]]\]($ch)\n"
        }
        return $md
    }

    # Breadcrumbs for URLPATH: Start > folder titles > page title.
    method _crumbs {urlPath pageTitle} {
        set parts [lsearch -all -inline -not [split [string trim $urlPath /] /] ""]
        set isDir [string match */ $urlPath]
        if {!$isDir && [llength $parts]} {
            if {[lindex $parts end] eq "index.md"} { set isDir 1 }
            set parts [lrange $parts 0 end-1]
        }
        set crumbs [list [list Start /]]
        set url "/" ; set fs [my cfg root]
        foreach p $parts {
            append url "$p/"
            set fs [file join $fs $p]
            lappend crumbs [list [my _dirTitle $fs] $url]
        }
        if {!$isDir && $pageTitle ne ""} { lappend crumbs [list $pageTitle ""] }
        # a bookkit wrapper and its edition usually share the title: once is enough
        set dedup {}
        foreach c $crumbs {
            if {[llength $dedup] && [lindex $dedup end 0] eq [lindex $c 0]} {
                set dedup [lreplace $dedup end end $c]
            } else { lappend dedup $c }
        }
        set crumbs $dedup
        if {[llength $crumbs] < 2} { return "" }
        set out {}
        foreach c [lrange $crumbs 0 end-1] {
            lassign $c label url
            lappend out "<a href=\"[my _esc $url]\">[my _esc $label]</a>"
        }
        lappend out "<span>[my _esc [lindex $crumbs end 0]]</span>"
        return "<nav class=\"mds-crumbs\">[join $out { <span class="sep">&rsaquo;</span> }]</nav>"
    }

    # "On this page": h2/h3 with id from the rendered body; only when there
    # are at least three.
    method _pageToc {body} {
        set items ""
        set n 0
        # A page with several H1 (manual pages: NAME, SYNOPSIS, DESCRIPTION
        # each as "# ...") has its sections one level up: then h1/h2.
        set lv 23
        set shift 0
        if {[regexp -all {<h1[\s>]} $body] > 1} { set lv 12; set shift 1 }
        foreach {- lvl id text} [regexp -all -inline "<h(\[$lv\])\[^>\]*?\\mid=\"(\[^\"\]+)\"\[^>\]*?>(.*?)</h\\1>" $body] {
            regsub -all {<[^>]+>} $text {} text
            set cls [expr {$lvl + $shift}]
            append items "<li class=\"l$cls\"><a href=\"#$id\">$text</a></li>"
            incr n
        }
        if {$n < 3} { return "" }
        return "<nav class=\"mds-toc\"><div class=\"mds-toc-title\">Auf dieser Seite</div><ul>$items</ul></nav>"
    }

    # Sidebar: the book (chapters, downloads) or the current folder.
    method _sideNav {fsPath urlPath} {
        set dir [expr {[file isdirectory $fsPath] ? $fsPath : [file dirname $fsPath]}]
        set cur [expr {[file isdirectory $fsPath] ? "index.md" : [file tail $fsPath]}]
        if {[my _isBookDir $dir]} {
            set title [my _esc [my _dirTitle $dir]]
            set cls [expr {$cur eq "index.md" ? " class=\"cur\"" : ""}]
            set items "<li$cls><a href=\"index.md\">&Uuml;bersicht</a></li>"
            foreach ch [my _bookChapters $dir] {
                set c [expr {$ch eq $cur ? " class=\"cur\"" : ""}]
                append items "<li$c><a href=\"$ch\">[my _chapterLabel [file join $dir $ch]]</a></li>"
            }
            set dl ""
            foreach {label url} [my _bookDownloads $dir] {
                append dl "<a class=\"mds-dl\" href=\"$url\">$label</a>"
            }
            if {$dl ne ""} { set dl "<div class=\"mds-side-dl\">$dl</div>" }
            return "<div class=\"mds-side-title\"><span class=\"mds-badge\">Buch</span> $title</div>$dl<ul>$items</ul>"
        }
        # a folder: its subfolders and documents
        set items ""
        foreach d [lsort -dictionary [glob -nocomplain -directory $dir -type d *]] {
            set n [file tail $d]
            if {[string index $n 0] eq "." || ![my _dirHasAnyMd $d]} continue
            append items "<li><a href=\"$n/\">[my _esc [my _dirTitle $d]]</a></li>"
        }
        foreach f [lsort -dictionary [glob -nocomplain -directory $dir *.md]] {
            set n [file tail $f]
            if {$n in {index.md indexsub.md}} continue
            set c [expr {$n eq $cur ? " class=\"cur\"" : ""}]
            set t [my _h1Title $f]
            if {$t eq ""} { set t [file rootname $n] }
            append items "<li$c><a href=\"$n\">[my _esc [my _plainLabel $t]]</a></li>"
        }
        foreach f [my _pdfsIn $dir] {
            set n [file tail $f]
            set l [lindex [split [my _docLabel $f] ,] 0]
            set c [expr {$n eq $cur ? " class=\"cur\"" : ""}]
            append items "<li$c><a href=\"[my _esc [string map {" " %20} $n]]\">[my _esc [file rootname $n]]</a>\
                <small>[my _esc $l]</small></li>"
        }
        if {$items eq ""} { return "" }
        # if, not expr: expr would turn a title like 007 into 7
        if {$dir eq [my cfg root]} { set title [my cfg title] } else { set title [my _dirTitle $dir] }
        return "<div class=\"mds-side-title\">[my _esc $title]</div><ul>$items</ul>"
    }

    # Previous / next chapter as two cards (book chapters only).
    method _pagerCards {fsPath} {
        set dir [file dirname $fsPath]
        set name [file tail $fsPath]
        if {![my cfg chapternav] || $name eq "index.md" || ![my _isBookDir $dir]} { return "" }
        set ch [my _bookChapters $dir]
        set i [lsearch -exact $ch $name]
        if {$i < 0} { return "" }
        set out ""
        if {$i > 0} {
            set p [lindex $ch [expr {$i - 1}]]
            append out "<a class=\"mds-pager prev\" href=\"$p\"><small>&larr; Zur&uuml;ck</small>[my _chapterLabel [file join $dir $p]]</a>"
        } else { append out "<span></span>" }
        if {$i < [llength $ch] - 1} {
            set n [lindex $ch [expr {$i + 1}]]
            append out "<a class=\"mds-pager next\" href=\"$n\"><small>Weiter &rarr;</small>[my _chapterLabel [file join $dir $n]]</a>"
        }
        return "<nav class=\"mds-pagers\">$out</nav>"
    }

    # Folder page as cards: books first, then folders, documents, files.
    method _folderCards {dir urlPath} {
        set books "" ; set folders "" ; set docs "" ; set files ""
        foreach d [lsort -dictionary [glob -nocomplain -directory $dir -type d *]] {
            set n [file tail $d]
            if {[string index $n 0] eq "."} continue
            set eds [my _bookEditions $d]
            set isBook [file exists [file join $d book.tcl]]
            if {!$isBook && ![llength $eds] && ![my _dirHasAnyMd $d]} continue
            set title [my _esc [my _dirTitle $d]]
            set desc ""
            foreach f {index.md README.md} {
                if {[file exists [file join $d $f]]} { set desc [my _firstPara [file join $d $f]] ; break }
            }
            if {$isBook || [llength $eds]} {
                # a book describes itself best by its subtitle
                set m [my _bookMeta [expr {$isBook ? $d : [lindex $eds 0]}]]
                if {[dict get $m subtitle] ne ""} { set desc [dict get $m subtitle] }
                set meta {}
                foreach e [expr {$isBook ? [list $d] : $eds}] {
                    set l [dict get [my _bookMeta $e] lang]
                    if {$l ne ""} { lappend meta [string toupper $l] }
                }
                set href [expr {$isBook || [llength $eds] != 1 ? "$n/" : "$n/[file tail [lindex $eds 0]]/"}]
                append books "<a class=\"mds-card book\" href=\"$href\"><span class=\"mds-badge\">Buch</span>\
<strong>$title</strong><span>[my _esc $desc]</span><em>[join $meta { &middot; }]</em></a>"
            } else {
                append folders "<a class=\"mds-card\" href=\"$n/\"><strong>$title</strong><span>[my _esc $desc]</span></a>"
            }
        }
        foreach f [lsort -dictionary [glob -nocomplain -directory $dir *.md]] {
            set n [file tail $f]
            if {$n in {index.md indexsub.md}} continue
            set t [my _h1Title $f]
            if {$t eq ""} { set t [file rootname $n] }
            append docs "<a class=\"mds-card doc\" href=\"$n\"><strong>[my _esc [my _plainLabel $t]]</strong>\
<span>[my _esc [my _firstPara $f]]</span></a>"
        }
        foreach f [my _pdfsIn $dir] {
            set n [file tail $f]
            append docs "<a class=\"mds-card doc\" href=\"[my _esc [string map {" " %20} $n]]\"><strong>[my _esc [file rootname $n]]</strong>\
<span>[my _esc [my _docLabel $f]]</span></a>"
        }
        foreach f [lsort -dictionary [glob -nocomplain -directory $dir -type f *]] {
            set ext [string tolower [file extension $f]]
            if {$ext in {.md .tcl .tsv .css} || [dict exists [my _docKinds] $ext]
                    || [string index [file tail $f] 0] eq "."} continue
            set kb [expr {([file size $f] + 1023) / 1024}]
            append files "<li><a href=\"[my _esc [file tail $f]]\">[my _esc [file tail $f]]</a> <small>[string toupper [string range $ext 1 end]], $kb KB</small></li>"
        }
        set out ""
        if {$books   ne ""} { append out "<h2>B&uuml;cher</h2><div class=\"mds-cards\">$books</div>" }
        if {$folders ne ""} { append out "<h2>Bereiche</h2><div class=\"mds-cards\">$folders</div>" }
        if {$docs    ne ""} { append out "<h2>Dokumente</h2><div class=\"mds-cards\">$docs</div>" }
        if {$files   ne ""} { append out "<h2>Dateien</h2><ul class=\"mds-files\">$files</ul>" }
        if {$out eq ""} { set out "<p><em>Keine Dokumente gefunden.</em></p>" }
        return $out
    }

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

    # The whole page around BODY.
    method _sitePage {title body fsPath urlPath theme} {
        set css ""
        set cssFile [my _styleCss site]
        if {$cssFile ne ""} {
            catch { set fh [open $cssFile r]; fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts; set css [read $fh]; close $fh }
        }
        set dark [expr {$theme in {dunkel dark} ? " class=\"dark\"" : ""}]
        set head ""
        foreach link [my cfg navlinks] {
            lassign $link label url
            append head "<a href=\"$url\">$label</a>"
        }
        if {[my cfg navsections]} {
            foreach link [my _sectionLinks] {
                lassign $link label url
                append head "<a href=\"$url\">$label</a>"
            }
        }
        set side  [my _sideNav $fsPath $urlPath]
        # the folder of this page goes with the search, so the result page
        # can offer "only here" (the search itself still covers everything)
        set vd [string trim $urlPath /]
        if {[file isfile $fsPath]} { set vd [string trim [file dirname "/$vd"] /] }
        set von ""
        if {[my _searchScope $vd] ne ""} {
            set von "<input type=\"hidden\" name=\"von\" value=\"[my _esc [my _searchScope $vd]]\">"
        }
        set toc   [my _pageToc $body]
        set crumbs [my _crumbs $urlPath $title]
        set pager [expr {[file isfile $fsPath] ? [my _pagerCards $fsPath] : ""}]
        set cls "mds-layout"
        # no sidebar content: on a phone the menu still offers the header links
        if {$side eq ""} { append cls " noside" }
        if {$toc eq ""}  { append cls " notoc" }
        set brand [my _esc [my cfg title]]
        return "<!DOCTYPE html>
<html lang=\"de\"$dark>
<head>
<meta charset=\"utf-8\"/>
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>
<title>[my _esc $title] &ndash; $brand</title>
<style>
$css
</style>
</head>
<body>
<input type=\"checkbox\" id=\"mds-menu\" class=\"mds-menu-toggle\">
<header class=\"mds-top\">
<label for=\"mds-menu\" class=\"mds-menu-btn\" title=\"Navigation\">&#9776;</label>
<a class=\"mds-brand\" href=\"/\">$brand</a>
<nav class=\"mds-topnav\">$head</nav>
<form class=\"mds-search\" action=\"/\" method=\"get\" role=\"search\">\
<input type=\"search\" name=\"q\" placeholder=\"Suchen\" aria-label=\"Suchen\">$von</form>
</header>
<div class=\"$cls\">
<aside class=\"mds-side\">$side<nav class=\"mds-side-top\">$head</nav></aside>
<main class=\"mds-main\">
$crumbs
<article class=\"mds-content\">
$body
</article>
$pager
</main>
<aside class=\"mds-aside\">$toc</aside>
</div>
</body>
</html>
"
    }

    # A Markdown file (or Markdown text) as a site page.
    method _siteMarkdown {mdText fsPath urlPath theme} {
        set ast  [mdstack::parser::parse $mdText]
        set html [mdstack::html::render $ast -theme none -toc 0 -lang de]
        set body [my _bodyOf $html]
        set title ""
        # Non-greedy throughout: in a Tcl regexp the FIRST quantifier sets
        # the greediness of the whole expression. With "<h1[^>]*>(.*?)</h1>"
        # the ".*?" was greedy too and took everything up to the LAST
        # </h1> -- a page with several H1 (manual pages: NAME, SYNOPSIS, ...)
        # had its whole text in the title and the breadcrumbs.
        regexp {<h1[^>]*?>(.*?)</h1>} $body -> title
        regsub -all {<[^>]+>} $title {} title
        set title [string map {&amp; & &lt; < &gt; > &quot; \"} $title]
        if {[my _isManSection $title] && [file isfile $fsPath]} {
            set t [my _h1Title $fsPath]
            if {$t ne ""} { set title $t }
        }
        if {$title eq ""} { set title [file rootname [file tail $fsPath]] }
        return [my _sitePage $title $body $fsPath $urlPath $theme]
    }

    # Invalid UTF-8 becomes U+FFFD under Tcl 9 as under 8.6; up to
    # 2026-10-30 Tcl 9 answered such a Markdown file with 500.
    method _readUtf8 {path} {
        set fh [open $path r]
        try {
            fconfigure $fh -encoding utf-8 {*}$::mdserver::readOpts
            return [read $fh]
        } finally {
            close $fh
        }
    }

    # Write DATA (text) to PATH through a temporary file: a failed write
    # leaves the old file, no temporary file and no open channel. Uses
    # tclutils::common::replaceFile when it loads (tclutils 0.69.0).
    method _writeAtomic {path data} {
        if {![catch {package require tclutils::common 0.3}]} {
            ::tclutils::common::replaceFile $path $data -encoding utf-8 -translation lf
            return
        }
        set tmp $path.tmp[pid]
        set fh [open $tmp w]
        try {
            fconfigure $fh -encoding utf-8 -translation lf
            puts -nonewline $fh $data
            close $fh
        } on error {msg opts} {
            catch {close $fh}
            catch {file delete -- $tmp}
            return -options $opts $msg
        }
        file rename -force -- $tmp $path
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
        if {$ext eq ".csv" && [my _csvOn]} { return [my _csvBody $fsPath] }
        if {[dict exists [my _officeViewExts] $ext]} { return [my _officeBody $fsPath] }
        return ""
    }

    # The same page in the styles other than site: through the Markdown
    # renderer as one HTML block, so theme, style and navigation apply.
    method _viewPage {body theme toc style} {
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

    method _tclutilsPath {} {
        if {[info exists ::env(TCLUTILS_TM)] && [file isdirectory $::env(TCLUTILS_TM)]} {
            catch {tcl::tm::path add $::env(TCLUTILS_TM)}
        }
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

    method _searchIndex {} {
        my variable _searchIdx
        if {![info exists _searchIdx]} { set _searchIdx {} }
        set root [my cfg root]
        set fresh {}
        foreach f [my _searchFiles $root] {
            if {[catch {file mtime $f} mt]} continue
            if {[dict exists $_searchIdx $f] && [dict get $_searchIdx $f mtime] == $mt} {
                dict set fresh $f [dict get $_searchIdx $f]
                continue
            }
            if {[string tolower [file extension $f]] eq ".pdf"} {
                if {[my _pdfWorkerOn]} {
                    lassign [my _pdfCached $f $mt] ok raw
                    if {!$ok} {
                        # not in the index yet: the next scan looks again
                        my _pdfQueue $f $mt
                        continue
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
                dict set fresh $f [dict create mtime $mt kind pdf pages $pages]
                continue
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
                dict set fresh $f [dict create mtime $mt kind $kind title $title text $text \
                    ftitle [my _fold $title] ftext [my _fold $text]]
                continue
            }
            if {[catch {my _readUtf8 $f} md]} continue
            set title [my _h1Title $f]
            if {$title eq ""} { set title [file rootname [file tail $f]] }
            set title [my _plainLabel $title]
            set text [my _plainText $md]
            dict set fresh $f [dict create mtime $mt title $title text $text \
                ftitle [my _fold $title] ftext [my _fold $text]]
        }
        set _searchIdx $fresh
        return $fresh
    }

    # A query as a dict: groups (list of OR-lists of folded terms, all
    # groups must match), excl (folded terms that must not match), in
    # (folder relative to the root, "" = everywhere), typ (md, pdf or "").
    method _parseQuery {query {in ""} {typ ""}} {
        set groups {} ; set excl {} ; set orNext 0
        foreach {all neg phr word} [regexp -all -inline {(-?)(?:"([^"]*)"?|(\S+))} $query] {
            set isPhrase [expr {[string index $all [string length $neg]] eq "\""}]
            if {!$isPhrase && $neg eq ""} {
                if {$word in {OR ODER |}} { set orNext 1 ; continue }
                if {[regexp -nocase {^(in|typ|type):(.*)$} $word -> k v]} {
                    if {[string tolower $k] eq "in"} { set in $v } else { set typ $v }
                    continue
                }
            }
            set t [my _fold [expr {$isPhrase ? $phr : $word}]]
            set t [string trim [regsub -all {\s+} $t " "]]
            if {[string length $t] < 2} continue
            if {$neg ne ""} {
                lappend excl $t
            } elseif {$orNext && [llength $groups]} {
                lset groups end [linsert [lindex $groups end] end $t]
            } else {
                lappend groups [list $t]
            }
            set orNext 0
        }
        return [dict create groups $groups excl $excl \
            in [my _searchScope $in] typ [my _searchTyp $typ]]
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

    # Score of TERM in a title/text pair: 20 for the title, plus the hits
    # in the text (at most 10); 0 if it is in neither.
    method _termScore {term fh ft} {
        set inTitle [expr {[string first $term $fh] >= 0}]
        set n [regexp -all -- [my _reQuote $term] $ft]
        return [expr {$inTitle * 20 + min($n, 10)}]
    }

    # Hits for QUERY: list of dicts {url title path snippet score}, best first.
    # IN and TYP narrow the search as in:/typ: in the query (those win).
    method _search {query {max 50} {in ""} {typ ""}} {
        set q [my _parseQuery $query $in $typ]
        set groups [dict get $q groups]
        if {![llength $groups]} { return {} }
        set excl  [dict get $q excl]
        set scope [dict get $q in]
        set typ   [dict get $q typ]
        # the words to mark: every positive term
        set words [concat {*}$groups]
        set root [my cfg root]
        set hits {}
        dict for {f e0} [my _searchIndex] {
          set kind [expr {[dict exists $e0 kind] ? [dict get $e0 kind] : "md"}]
          set isPdf [expr {$kind eq "pdf"}]
          if {$typ ne "" && $typ ne $kind} continue
          set rel [string range $f [string length $root] end]
          set url [join [lmap p [file split $rel] {
              if {$p eq "/" || $p eq "\\"} continue ; set p }] /]
          if {$scope ne "" && $url ne $scope && ![string match "$scope/*" $url]} continue
          # a Markdown file is one entry, a PDF one entry per page
          set entries [expr {$isPdf ? [dict get $e0 pages] : [list $e0]}]
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
            set dirTitles {}
            set fs $root
            foreach p [lrange [split [string trim $url /] /] 0 end-1] {
                set fs [file join $fs $p]
                set dt [my _dirTitle $fs]
                # bookkit wrapper and edition share the title: once
                if {[lindex $dirTitles end] ne $dt} { lappend dirTitles $dt }
            }
            set u $url
            if {[dict exists $e page]} { append u "#page=[dict get $e page]" }
            lappend hits [dict create url "/$u" title [dict get $e title] \
                path [join $dirTitles " \u203a "] score $score \
                snippet [my _snippet [dict get $e text] $words]]
          }
        }
        set hits [lsort -command [list apply {{a b} {
            set r [expr {[dict get $b score] - [dict get $a score]}]
            if {$r == 0} { set r [string compare [dict get $a title] [dict get $b title]] }
            return $r
        }}] $hits]
        return [lrange $hits 0 [expr {$max - 1}]]
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

    # The results as HTML (site style) ...
    method _searchBody {query {in ""} {typ ""} {von ""}} {
        set hits [my _search $query 50 $in $typ]
        set pq [my _parseQuery $query $in $typ]
        set q [my _esc $query]
        set body "<h1>Suche</h1>
<form class=\"mds-search-big\" action=\"/\" method=\"get\">\
<input type=\"search\" name=\"q\" value=\"$q\" autofocus><button>Suchen</button>\
[my _searchFilters [dict get $pq in] [dict get $pq typ] $von]</form>
<p class=\"mds-search-help\">\"Wortfolge\" &middot; -ohne &middot; a ODER b &middot;\
in:ordner &middot; typ:md|pdf|office|csv</p>"
        if {[string trim $query] eq ""} { return $body }
        set offen [my _pdfPending]
        if {$offen} {
            append body "<p class=\"mds-note\">[my _pdfPendingText $offen]</p>"
        }
        if {![llength $hits]} {
            append body "<p>Nichts gefunden f&uuml;r <strong>$q</strong>.</p>"
            return $body
        }
        append body "<p class=\"mds-lead\">[llength $hits] Treffer f&uuml;r <strong>$q</strong></p><ol class=\"mds-hits\">"
        foreach h $hits {
            set path [dict get $h path]
            append body "<li><a href=\"[my _esc [dict get $h url]]\">[my _esc [dict get $h title]]</a>"
            if {$path ne ""} { append body "<div class=\"mds-hit-path\">[my _esc $path]</div>" }
            append body "<p>[dict get $h snippet]</p></li>"
        }
        append body "</ol>"
        return $body
    }

    # The two choices under the search field: folder (everywhere, or one of
    # the folders above the page the search came from, or the current in)
    # and type. Folders are offered only if they exist under the root.
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
        if {[llength $dirs]} {
            append out "<label>Bereich <select name=\"in\">"
            append out "<option value=\"\"[expr {$in eq "" ? " selected" : ""}]>\u00fcberall</option>"
            foreach d $dirs {
                set titles {}
                set fs $root
                foreach p [split $d /] {
                    set fs [file join $fs $p]
                    set dt [my _dirTitle $fs]
                    if {[lindex $titles end] ne $dt} { lappend titles $dt }
                }
                set sel [expr {$d eq $in ? " selected" : ""}]
                append out "<option value=\"[my _esc $d]\"$sel>[my _esc [join $titles " \u203a "]]</option>"
            }
            append out "</select></label>"
            # keep the origin for the next search from this page
            append out "<input type=\"hidden\" name=\"von\" value=\"[my _esc [my _searchScope $von]]\">"
        }
        append out "<label>Typ <select name=\"typ\">"
        set opts [list "" alle md Markdown]
        if {[my _pdfOn]} { lappend opts pdf PDF }
        if {[dict size [my _officeReaders]]} { lappend opts office Office }
        if {[my _csvOn]} { lappend opts csv CSV }
        foreach {v l} $opts {
            set sel [expr {$v eq $typ ? " selected" : ""}]
            append out "<option value=\"$v\"$sel>$l</option>"
        }
        append out "</select></label>"
        return "<div class=\"mds-search-filter\">$out</div>"
    }

    method _pdfPendingText {n} {
        set was [expr {$n == 1 ? "1 PDF wird" : "$n PDFs werden"}]
        return "$was noch gelesen; ihre Seiten fehlen in dieser Liste.\
            Sp\u00e4ter noch einmal suchen."
    }

    # ... as JSON (?format=json, any style), with tclutils::tujson:
    #   {"query":..., "pending":N, "hits":[{"url","title","path","snippet","score"}]}
    # The snippet is plain text, without <mark>. Without tujson: 501.
    method _searchJson {query in typ} {
        my _tclutilsPath
        if {[catch {package require tclutils::tujson 0.1}]} { return "" }
        set J ::tclutils::tujson
        set hits {}
        foreach h [my _search $query 50 $in $typ] {
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
            hits    [${J}::arr $hits]]]]
    }

    method _sendSearchJson {chan req} {
        set j [my _searchJson [$req param q ""] [$req param in ""] [$req param typ ""]]
        if {$j eq ""} {
            my _notiz $chan "search json: no tujson"
            my _send $chan "501 Not Implemented" "text/plain; charset=utf-8" \
                "format=json needs tclutils::tujson\n"
            return
        }
        my _notiz $chan "search json"
        my _send $chan "200 OK" "application/json; charset=utf-8" $j
    }

    # ... and as Markdown for the other styles.
    method _searchMd {query {in ""} {typ ""}} {
        set md "# Suche: [string map {\[ \\\[ \] \\\] * \\* _ \\_ < &lt;} $query]\n\n"
        set hits [my _search $query 50 $in $typ]
        set offen [my _pdfPending]
        if {$offen} { append md "*[my _pdfPendingText $offen]*\n\n" }
        if {![llength $hits]} { return "$md*Nichts gefunden.*\n" }
        foreach h $hits {
            append md "- \[[dict get $h title]\]([dict get $h url])"
            if {[dict get $h path] ne ""} { append md " -- [dict get $h path]" }
            append md "\n"
        }
        return $md
    }

    # Requests in style "site".
    method _siteDispatch {chan req urlPath theme} {
        if {[dict exists [$req params] q] && [$req param format ""] eq "json"} {
            my _sendSearchJson $chan $req
            return
        }
        if {[dict exists [$req params] q]} {
            set q [$req param q ""]
            my _notiz $chan "search"
            my _send $chan "200 OK" "text/html; charset=utf-8" \
                [my _sitePage "Suche" [my _searchBody $q [$req param in ""] \
                    [$req param typ ""] [$req param von ""]] [my cfg root] / $theme]
            return
        }
        if {[$req param nav ""] eq "index"} {
            $_renderer setDocKinds [my _docKinds]
            set html [$_renderer siteIndex [my cfg root] none]
            my _notiz $chan "site index"
            my _send $chan "200 OK" "text/html; charset=utf-8" \
                [my _sitePage "Alle Dokumente" [my _bodyOf $html] [my cfg root] $urlPath $theme]
            return
        }
        set fsPath [my _safePath $urlPath]
        if {[file isdirectory $fsPath]} {
            if {![string match "*/" $urlPath]} {
                set loc "$urlPath/"
                set q [$req query]
                if {$q ne ""} { append loc "?$q" }
                my _redirect $chan $loc
                return
            }
            set indexFile [file join $fsPath [my cfg index]]
            if {[file exists $indexFile]} {
                set html [my _siteMarkdown [my _readUtf8 $indexFile] $indexFile $urlPath $theme]
                my _notiz $chan "index.md"
            } elseif {[file exists [file join $fsPath book.tcl]]} {
                set html [my _siteMarkdown [my _bookLandingMd $fsPath] $indexFile $urlPath $theme]
                my _notiz $chan "book landing"
            } else {
                if {$fsPath eq [my cfg root]} {
                    set title [my cfg title]
                } else {
                    set title [my _dirTitle $fsPath]
                }
                set body "<h1>[my _esc $title]</h1>"
                if {[file exists [file join $fsPath README.md]]} {
                    set p [my _firstPara [file join $fsPath README.md] 400]
                    if {$p ne ""} { append body "<p class=\"mds-lead\">[my _esc $p]</p>" }
                }
                append body [my _folderCards $fsPath $urlPath]
                set html [my _sitePage $title $body $fsPath $urlPath $theme]
                my _notiz $chan "directory index"
            }
            my _send $chan "200 OK" "text/html; charset=utf-8" $html
            return
        }
        # clean URL: /dict -> dict.md (nroff2md --linkmode server)
        if {![file exists $fsPath] && [file isfile $fsPath.md]} {
            set fsPath [my _safePath $urlPath.md]
        }
        if {![file exists $fsPath]} {
            set dir [file dirname $fsPath]
            if {[file tail $fsPath] eq "index.md" && [file exists [file join $dir book.tcl]]} {
                my _notiz $chan "book landing"
                my _send $chan "200 OK" "text/html; charset=utf-8" \
                    [my _siteMarkdown [my _bookLandingMd $dir] $fsPath $urlPath $theme]
                return
            }
            throw {MDDOCS NOTFOUND} $urlPath
        }
        if {[string tolower [file extension $fsPath]] eq ".md"} {
            my _notiz $chan markdown
            my _send $chan "200 OK" "text/html; charset=utf-8" \
                [my _siteMarkdown [my _readUtf8 $fsPath] $fsPath $urlPath $theme]
            return
        }
        set body [my _viewBody $req $fsPath]
        if {$body ne ""} {
            my _notiz $chan "view [string range [string tolower [file extension $fsPath]] 1 end]"
            set title [file rootname [file tail $fsPath]]
            my _send $chan "200 OK" "text/html; charset=utf-8" \
                [my _sitePage $title $body $fsPath $urlPath $theme]
            return
        }
        my _serveFile $chan $req $fsPath [my _mime [string tolower [file extension $fsPath]]]
    }

    method _dispatch {chan req urlPath theme toc {style plain}} {
        try {
            # Health: fuer nginx, systemd, Ueberwachung.
            #
            # Er prueft eine Sache, statt nur zu bestaetigen, dass der Prozess
            # lebt: ist die Wurzel noch ein lesbares Verzeichnis? Ein
            # Health-Endpunkt, der immer 200 sagt, meldet "gesund", wenn
            # --root auf einen nicht mehr eingehaengten Pfad zeigt -- nginx
            # schaltet dann auf einen Server, der fuer alles 404 liefert.
            #
            # Keine Systeminformationen: nur ok oder der Grund.
            if {$urlPath eq [my cfg healthpath]} {
                set wurzel [my cfg root]
                if {[file isdirectory $wurzel] && [file readable $wurzel]} {
                    my _send $chan "200 OK" "text/plain; charset=utf-8" "ok\n"
                } else {
                    my _notiz $chan "root nicht lesbar"
                    my _send $chan "503 Service Unavailable" "text/plain; charset=utf-8" \
                        "root unreadable\n"
                }
                return
            }

            if {$style eq "site"} {
                my _siteDispatch $chan $req $urlPath $theme
                return
            }

            # Full-text search, plain result list for the older styles
            if {[dict exists [$req params] q] && [$req param format ""] eq "json"} {
                my _sendSearchJson $chan $req
                return
            }
            if {[dict exists [$req params] q]} {
                set html [$_renderer markdownText [my _searchMd [$req param q ""] \
                    [$req param in ""] [$req param typ ""]] $theme 0 [my _styleCss $style]]
                my _notiz $chan "search"
                my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                return
            }

            # Site index of all documents
            if {[$req param nav ""] eq "index"} {
                $_renderer setDocKinds [my _docKinds]
                set html [$_renderer siteIndex [my cfg root] $theme [my _styleCss $style]]
                my _notiz $chan "site index"
                my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                return
            }

            set fsPath [my _safePath $urlPath]

            if {[file isdirectory $fsPath]} {
                # Directory without trailing slash: redirect so the browser
                # resolves relative links against the directory, not its parent.
                if {![string match "*/" $urlPath]} {
                    set loc "$urlPath/"
                    set q [$req query]
                    if {$q ne ""} { append loc "?$q" }
                    my _redirect $chan $loc
                    return
                }
                set indexFile [file join $fsPath [my cfg index]]
                if {[file exists $indexFile]} {
                    set html [$_renderer markdown $indexFile $theme $toc [my _styleCss $style]]
                    set html [my _injectBookNav $html $indexFile $style]
                    my _notiz $chan "index.md"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } elseif {[file exists [file join $fsPath book.tcl]]} {
                    set html [$_renderer markdownText [my _bookLandingMd $fsPath] $theme $toc [my _styleCss $style]]
                    set html [my _injectBookNav $html $indexFile $style]
                    my _notiz $chan "book landing"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } else {
                    set html [$_renderer index $fsPath $urlPath $theme [my _styleCss $style]]
                    my _notiz $chan "directory index"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                }

            } elseif {![file exists $fsPath] && [file isfile $fsPath.md]} {
                # clean URL: /dict -> dict.md (nroff2md --linkmode server)
                set fsPath [my _safePath $urlPath.md]
                set html [$_renderer markdown $fsPath $theme $toc [my _styleCss $style]]
                set html [my _injectChapterNav $html $fsPath]
                set html [my _injectBookNav $html $fsPath $style]
                my _notiz $chan markdown
                my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]

            } elseif {![file exists $fsPath]} {
                # index.md of a book without one: the generated landing page
                # (chapter bar and sidebar link "Uebersicht" point here)
                set dir [file dirname $fsPath]
                if {[file tail $fsPath] eq "index.md" && [file exists [file join $dir book.tcl]]} {
                    set html [$_renderer markdownText [my _bookLandingMd $dir] $theme $toc [my _styleCss $style]]
                    set html [my _injectBookNav $html $fsPath $style]
                    my _notiz $chan "book landing"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                    return
                }
                throw {MDDOCS NOTFOUND} $urlPath

            } else {
                set ext [string tolower [file extension $fsPath]]
                if {$ext eq ".md"} {
                    set html [$_renderer markdown $fsPath $theme $toc [my _styleCss $style]]
                    set html [my _injectChapterNav $html $fsPath]
                    set html [my _injectBookNav $html $fsPath $style]
                    my _notiz $chan markdown
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } elseif {[set body [my _viewBody $req $fsPath]] ne ""} {
                    my _notiz $chan "view [string range $ext 1 end]"
                    my _send $chan "200 OK" "text/html; charset=utf-8" \
                        [my _viewPage $body $theme $toc $style]
                } else {
                    set mime [my _mime $ext]
                    my _serveFile $chan $req $fsPath $mime
                }
            }

        } trap {MDDOCS TRAVERSAL} {msg} {
            my _notiz $chan $msg
            my _send $chan "403 Forbidden" "text/html; charset=utf-8" \
                "<html><body><h1>403 Forbidden</h1><p>$msg</p></body></html>"
        } trap {MDDOCS NOTFOUND} {msg} {
            if {$style eq "site"} {
                set body "<h1>Nicht gefunden</h1><p>[my _esc $msg] gibt es hier nicht.</p>\
<p><a href=\"/\">Zur Startseite</a> &middot; <a href=\"/?nav=index\">Alle Dokumente</a></p>"
                my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                    [my _sitePage "Nicht gefunden" $body [my cfg root] / $theme]
                return
            }
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1><p>$msg</p></body></html>"
        } trap {POSIX ENOENT} {} {
            my _notiz $chan ENOENT
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1></body></html>"
        } on error {msg info} {
            # The client closed the connection while the answer was written
            # (a quick click on): nothing to answer. Up to 2026-10-30 this
            # tried a 500 and logged it.
            if {[lindex [dict get $info -errorcode] 1] in {EPIPE ECONNRESET}
                    || [regexp {^error (writing|flushing) "[^"]*": (broken pipe|connection reset)} $msg]} {
                my _notiz $chan "Verbindung vom Klienten geschlossen"
                return
            }
            my _notiz $chan $msg
            my _send $chan "500 Internal Server Error" "text/html; charset=utf-8" \
                "<html><body><h1>500 Internal Server Error</h1><pre>$msg</pre></body></html>"
        }
    }

    # Helper methods

    # _unterhalb wurzel pfad -- liegt pfad wirklich unter wurzel?
    #
    # "string match ${root}*" war zu grosszuegig: bei der Wurzel /srv/md haette
    # auch /srv/mdxyz gepasst. Verglichen wird darum bis zum Trennzeichen.
    method _unterhalb {root path} {
        if {$path eq $root} { return 1 }
        return [string match "[string trimright $root /]/*" $path]
    }

    # _resolveLinks pfad -- Symlinks Schritt fuer Schritt aufloesen.
    #
    # Tcls "file normalize" loest "." und ".." auf, aber KEINE Symlinks. Ein
    # Verweis in der Wurzel fuehrt damit hinaus, und die Pruefung darueber
    # sieht es nicht, weil sie die Zeichenkette prueft und nicht das Ziel.
    # Gemessen am 28.09.2026: /link.txt -> /tmp/geheim.txt kam mit 200 zurueck,
    # und /tmplink/... lief durch einen Verweis auf /tmp. Windows-Klienten
    # koennen ueber SMB gewoehnlich keine Symlinks anlegen -- "rsync -a" von
    # der Arbeitsstation nimmt sie aber mit, und genau so wird der Bestand
    # befuellt.
    #
    # max begrenzt die Runden: ein Verweis auf sich selbst wuerde sonst ewig
    # laufen. Danach bleibt der Pfad, wie er ist, und die Pruefung unten
    # entscheidet.
    method _resolveLinks {path {max 32}} {
        set p [file normalize $path]
        for {set runde 0} {$runde < $max} {incr runde} {
            set teile [file split $p]
            set bisher [lindex $teile 0]
            set geaendert 0
            for {set i 1} {$i < [llength $teile]} {incr i} {
                set bisher [file join $bisher [lindex $teile $i]]
                if {[catch {file type $bisher} typ]} break
                if {$typ ne "link"} continue
                if {[catch {file readlink $bisher} ziel]} break
                if {[file pathtype $ziel] ne "absolute"} {
                    set ziel [file join [file dirname $bisher] $ziel]
                }
                set rest [lrange $teile [expr {$i + 1}] end]
                set p [file normalize [file join $ziel {*}$rest]]
                set geaendert 1
                break
            }
            if {!$geaendert} break
        }
        return $p
    }

    method _safePath {urlPath} {
        set root [my cfg root]
        set path [file normalize [file join $root [string trimleft $urlPath /]]]
        if {![my _unterhalb $root $path]} {
            throw {MDDOCS TRAVERSAL} "Directory traversal blocked: $urlPath"
        }
        # Punkt-Dateien und -Ordner.
        #
        # Die Verzeichnisliste zeigt sie ohnehin nicht (Tcls "glob *" laesst
        # sie aus), der direkte Aufruf lieferte sie aber aus: GET /.git/HEAD
        # kam am 28.09.2026 mit 200 und dem Inhalt zurueck. Wer seinen Bestand
        # aus einem Arbeitsbaum rsynct, bringt das .git mit -- und dann liegt
        # der ganze Verlauf im Browser. --dotfiles 1 fuer den, der es braucht.
        if {![my cfg dotfiles]} {
            foreach teil [file split [string trimleft $urlPath /]] {
                if {[string match ".?*" $teil]} {
                    throw {MDDOCS TRAVERSAL} "hidden files are not served: $urlPath"
                }
            }
        }
        # und erst jetzt die Verweise
        set echt [my _resolveLinks $path]
        if {![my _unterhalb $root $echt]} {
            throw {MDDOCS TRAVERSAL} "a symlink leaves the document root: $urlPath"
        }
        return $path
    }

    method _mime {ext} {
        if {[dict exists $::mdserver::mimeTypes $ext]} {
            return [dict get $::mdserver::mimeTypes $ext]
        }
        return "application/octet-stream"
    }

    method _readBin {path} {
        set fh [open $path rb] ;# binary mode -- no fconfigure -encoding needed
        try {
            return [read $fh]
        } finally {
            close $fh
        }
    }

    # HTTP date (GMT) for Last-Modified / If-Modified-Since
    method _httpDate {t} {
        return [clock format $t -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]
    }

    # Den Koerper schreiben -- ausser die Anfrage war HEAD.
    #
    # RFC 9110 9.3.2: die Antwort auf HEAD ist identisch mit der auf GET, nur
    # OHNE Koerper. Content-Length bleibt also die Laenge, die ein GET
    # geliefert haette -- sie wird hier nicht angefasst, nur das Schreiben
    # faellt aus. Bis 0.3.1 kam der Koerper mit, obwohl der Allow-Kopf HEAD
    # ausdruecklich zusagt.
    #
    # Der Merker haengt am Kanal, nicht am Objekt: es bedienen mehrere
    # Coroutinen gleichzeitig dasselbe Server-Objekt, eine Objektvariable
    # wuerde zwischen ihnen ueberschrieben.
    method _koerper {chan daten} {
        variable _nurKopf
        if {[info exists _nurKopf($chan)] && $_nurKopf($chan)} { return }
        puts -nonewline $chan $daten
    }

    # Status und Laenge fuer die Protokollzeile festhalten. Sie entsteht erst
    # am Ende der Anfrage -- vorher ist der Status nicht bekannt.
    method _merken {chan status len} {
        variable _antwort
        set _antwort($chan) [list [lindex [split $status] 0] $len]
    }

    # Eine kurze Notiz, die in der Protokollzeile hinten anhaengt: was sonst
    # verloren waere -- markdown, der Bereich bei 206, der Grund bei 403.
    method _notiz {chan text} {
        variable _notizen
        set _notizen($chan) $text
    }

    # Die Protokollzeile. Eine je Anfrage, am Ende geschrieben -- vorher sind
    # Status und Bytes nicht bekannt. Bis 0.3.4 waren es zwei Zeilen, und die
    # Bytes standen nur bei statischen Dateien; Markdown hatte keine.
    #
    #   [01:30:12] 127.0.0.1 GET /index.md 200 6104 markdown
    #   [01:30:12] 192.168.17.42 GET /handbuch.pdf 206 65536 bytes 0-65535/2400000
    #
    # Die Adresse ist die Gegenstelle, oder der erste X-Forwarded-For-Eintrag,
    # wenn die Gegenstelle in --trusted-proxy steht.
    method _zeile {chan woher methode pfad} {
        variable _antwort
        variable _notizen
        lassign [expr {[info exists _antwort($chan)] ? $_antwort($chan) : {- -}}] status bytes
        set text "$woher $methode $pfad $status $bytes"
        if {[info exists _notizen($chan)] && $_notizen($chan) ne ""} {
            append text " $_notizen($chan)"
        }
        my _log $text
    }

    method _zeileWeg {chan} {
        variable _antwort
        variable _notizen
        unset -nocomplain _antwort($chan) _notizen($chan)
    }

    # Write status line + headers (no body). extra = list of "Name: Value".
    method _sendHead {chan status contentType len extra} {
        my _merken $chan $status $len
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        foreach h $extra { puts $chan $h }
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
    }

    # Passt der If-Range-Validator auf diese Datei?
    #
    # Nur ein Datums-Validator kann passen, und nur auf die Sekunde genau:
    # mdserver setzt keine ETags, also ist alles in ETag-Form (" oder W/) ein
    # Validator, den dieser Server nie ausgegeben hat. "Passt nicht" ist die
    # sichere Antwort -- sie fuehrt zum ganzen Inhalt, nie zu einem Stueck aus
    # der falschen Fassung.
    #
    # Bewusst ohne expr auf dem Wert: expr rechnet mit einem Zweig, der wie
    # eine Zahl aussieht.
    method _ifRangePasst {ifr mtime} {
        if {[string index $ifr 0] eq "\"" || [string match "W/*" $ifr]} { return 0 }
        if {[catch {clock scan $ifr -gmt 1} t]} { return 0 }
        return [expr {$t == $mtime}]
    }

    # Serve a static file: Conditional GET (304) + Range (206) + full (200).
    method _serveFile {chan req fsPath mime} {
        set size    [file size $fsPath]
        set mtime   [file mtime $fsPath]
        set lastmod [my _httpDate $mtime]

        # Conditional GET
        set ims [$req header if-modified-since]
        if {$ims ne "" && ![catch {clock scan $ims -gmt 1} imsT] && $mtime <= $imsT} {
            my _notiz $chan "not modified"
            my _sendHead $chan "304 Not Modified" $mime 0 [list "Last-Modified: $lastmod"]
            return
        }

        # Range
        set range [$req header range]

        # If-Range: der Bereich gilt NUR, wenn die Datei noch dieselbe ist
        # (RFC 9110 13.1.5). Passt der Validator nicht, gehoert der ganze
        # Inhalt in die Antwort -- 200, nicht 206.
        #
        # Bis 0.3.2 wurde der Kopf gar nicht gelesen. Wer eine grosse PDF
        # stueckweise holt (Adobe Reader, Chrome) und waehrenddessen speichert
        # jemand die Datei neu, bekam Stuecke der NEUEN Datei, im
        # Content-Range als Teil der alten ausgegeben. Der Viewer klebt daraus
        # zwei Fassungen zusammen, ohne dass etwas darauf hinweist. Genau der
        # Fall, wenn /srv/md ueber Samba gepflegt wird und gleichzeitig
        # gelesen.
        #
        # mdserver setzt keine ETags. Ein Validator in ETag-Form (beginnt mit
        # " oder W/) kann darum nie passen und fuehrt ebenso zum ganzen
        # Inhalt; ein schwacher Validator ist fuer If-Range ohnehin nicht
        # zulaessig. Ohne Range-Kopf wird If-Range ignoriert -- den Fall
        # erledigt die Bedingung unten von selbst.
        if {$range ne ""} {
            set ifr [string trim [$req header if-range]]
            if {$ifr ne "" && ![my _ifRangePasst $ifr $mtime]} {
                my _notiz $chan "If-Range passt nicht"
                set range ""
            }
        }

        if {[regexp {^bytes=(\d*)-(\d*)$} $range -> a b] && ($a ne "" || $b ne "")} {
            if {$a eq ""} {
                set start [expr {$size - $b}]; if {$start < 0} { set start 0 }
                set end   [expr {$size - 1}]
            } elseif {$b eq ""} {
                set start $a; set end [expr {$size - 1}]
            } else {
                set start $a; set end $b
                if {$end > $size - 1} { set end [expr {$size - 1}] }
            }
            if {$start > $end || $start >= $size} {
                my _notiz $chan "range"
                my _sendHead $chan "416 Range Not Satisfiable" $mime 0 \
                    [list "Content-Range: bytes */$size"]
                return
            }
            set fh [open $fsPath rb]
            seek $fh $start
            set data [read $fh [expr {$end - $start + 1}]]
            close $fh
            my _notiz $chan "bytes $start-$end/$size"
            my _sendHead $chan "206 Partial Content" $mime [string length $data] \
                [list "Accept-Ranges: bytes" "Last-Modified: $lastmod" \
                      "Content-Range: bytes $start-$end/$size"]
            fconfigure $chan -translation binary
            my _koerper $chan $data
            return
        }

        # Full (200)
        set data [my _readBin $fsPath]
        my _notiz $chan $mime
        my _sendHead $chan "200 OK" $mime [string length $data] \
            [list "Accept-Ranges: bytes" "Last-Modified: $lastmod"]
        fconfigure $chan -translation binary
        my _koerper $chan $data
    }

    # 301 redirect (e.g. add a trailing slash to a directory URL).
    method _redirect {chan location} {
        my _merken $chan 301 0
        my _notiz $chan "-> $location"
        puts $chan "HTTP/1.1 301 Moved Permanently"
        puts $chan "Location: $location"
        puts $chan "Content-Length: 0"
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
    }

    # extra: zusaetzliche Kopfzeilen als Paare {Name Wert Name Wert ...}.
    # Vorgabe leer, damit alle vorhandenen Aufrufe unveraendert bleiben.
    method _send {chan status contentType body {extra {}}} {
        set bytes [encoding convertto utf-8 $body]
        set len [string length $bytes]
        my _merken $chan $status $len
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        foreach {name wert} $extra { puts $chan "$name: $wert" }
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
        # Write the body in binary: otherwise -translation crlf expands each \n to \r\n
        # so the byte count would no longer match Content-Length -> truncation.
        chan configure $chan -translation binary
        my _koerper $chan $bytes
    }

    method _sendBin {chan status contentType data} {
        set len [string length $data]
        my _merken $chan $status $len
        fconfigure $chan -translation binary
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
        my _koerper $chan $data
    }

    method _log {msg} {
        if {[my cfg log]} {
            puts "\[[clock format [clock seconds] -format "%H:%M:%S"]\] $msg"
            # In eine Datei oder Pipe umgelenkt puffert Tcl seitenweise. Genau
            # so laeuft der Dienst unter systemd -- ohne flush steht die
            # letzte Anfrage erst Kilobytes spaeter im Protokoll.
            flush stdout
        }
    }

    # Die Startmeldung sagte bis 0.3.4 immer "http://localhost:PORT/" -- auch
    # wenn ohne --bind an ALLE Schnittstellen gebunden wurde. Genau im
    # gefaehrlichen Fall behauptete sie also das Gegenteil: "localhost" liest
    # sich wie "nur hier". Jetzt steht die Adresse da, an die wirklich
    # gebunden wurde.
    method _horchtAuf {port} {
        set adr [my cfg bind]
        if {$adr eq ""} { return "0.0.0.0:$port (alle Schnittstellen)" }
        return "$adr:$port"
    }

    method _printStatus {} {
        set adr [my cfg bind]
        set url [expr {$adr eq "" ? "localhost" : $adr}]
        puts "$::mdserver::serverHeader -- Tcl Markdown Server"
        puts "  Root:  [my cfg root]"
        puts "  Theme: [my cfg theme]"
        puts "  PDF:   [my _pdfStatus]"
        puts "  Office: [my _officeStatus]"
        set v [my _officeViewExts]
        # ASCII only: a test or a pipe may read the banner as strict UTF-8
        puts "  Ansicht: [expr {[dict size $v] ? "[join [dict keys $v] { }] als Seite" : "aus"}]"
        puts "  CSV:   [expr {[my _csvOn] ? "Tabellenseite und Suche an (tclutils::tucsv [package present tclutils::tucsv])" : "aus"}]"
        if {[encoding system] ni {utf-8 utf8}} {
            puts "  Achtung: Systemkodierung [encoding system] -- Dateinamen mit Umlauten werden nicht gefunden (LANG=C.UTF-8 setzen)"
        }
        puts ""
        puts "  HTTP:  [my _horchtAuf [my cfg port]]"
        puts "         http://$url:[my cfg port]/"
        if {[my cfg tls]} {
            puts "  HTTPS: [my _horchtAuf [my cfg tlsport]]"
            puts "         https://$url:[my cfg tlsport]/"
            puts "  Cert:  [my cfg cert]"
        } else {
            puts "  HTTPS: nicht aktiv (--cert und --key angeben)"
        }
        if {[my cfg control] ne ""} {
            # Nicht "echo stop | nc ..." vorschlagen: OpenBSD-netcat, das
            # Standard-nc auf Debian, wartet dort ohne -N bis zum Timeout.
            puts "  Stop:  127.0.0.1:[my cfg control]"
            puts "         tclsh mdctl.tcl --port [my cfg control] stop"
        }
        puts ""
        puts "Press Ctrl+C to stop."
        puts ""
    }
}
