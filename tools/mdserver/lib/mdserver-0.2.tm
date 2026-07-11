# mdserver-0.2.tm -- Markdown-Web-Server Modul v0.5 (coroutine/non-blocking)
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

package provide mdserver 0.2

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
catch {package require mdstack::theme 0.1}

# ============================================================
# MIME types (global, immutable)
# ============================================================

namespace eval mdserver {
    variable moduleDir [file dirname [file normalize [info script]]]
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
    }
}

# ============================================================
# Coroutine-aware, non-blocking gets.
# Returns the line length, -1 on EOF/timeout. Yields until a
# complete line is available -- the readable event (or the timeout)
# resumes the coroutine. A slow connection never blocks the others.
# ============================================================
proc mdserver::coGets {chan _line} {
    upvar 1 $_line line
    while {1} {
        set n [gets $chan line]
        if {$n >= 0} { return $n }
        if {[eof $chan]} { return -1 }
        if {[yield] eq "TIMEOUT"} { return -1 }
    }
}

# ============================================================
# mdserver::Request -- parse an HTTP request
# ============================================================

oo::class create mdserver::Request {

    variable _method _path _query _headers _params

    constructor {chan} {
        set _method  ""
        set _path    ""
        set _query   ""
        set _headers {}
        set _params  {}
        my _parse $chan
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
    method _parse {chan} {
        # Request line (coroutine, non-blocking)
        if {[mdserver::coGets $chan requestLine] < 0} {
            throw {MDDOCS BADREQUEST} {connection closed/timeout}
        }

        # Headers until blank line
        while {1} {
            if {[mdserver::coGets $chan line] < 0} break
            set line [string trimright $line]
            if {$line eq ""} break
            if {[regexp {^([^:]+):\s*(.*)$} $line -> k v]} {
                dict set _headers [string tolower $k] $v
            }
        }

        # Method + URL
        if {![regexp {^(GET|HEAD)\s+(/[^\s]*)\s+HTTP} $requestLine \
                -> _method rawUrl]} {
            throw {MDDOCS BADREQUEST} "Invalid request line: $requestLine"
        }

        # Split URL and query
        if {[string first ? $rawUrl] >= 0} {
            regexp {^([^?]*)(\?(.*))?$} $rawUrl -> _path _ _query
        } else {
            set _path $rawUrl
        }
        set _path   [my _urlDecode $_path]
        set _params [my _parseQuery $_query]
    }

    method _urlDecode {str} {
        set str [string map {+ " "} $str]
        regsub -all {%([0-9A-Fa-f]{2})} $str {[binary format H2 \1]} str
        set str [subst $str]
        return [encoding convertfrom utf-8 $str]
    }

    method _parseQuery {query} {
        set result {}
        foreach pair [split $query &] {
            if {$pair eq ""} continue
            set kv [split $pair =]
            set k [my _urlDecode [lindex $kv 0]]
            set v [my _urlDecode [lindex $kv 1]]
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

    constructor {title} {
        set _title $title
    }

    method markdown {path theme toc {cssFile ""}} {
        set md [my _readFile $path]
        set ast [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc $toc -lang de]
        return [my _injectCss $html $cssFile]
    }

    # Insert the chosen style as an extra <style> after the default --
    # render has no -css; the style rules win via the CSS cascade.
    method _injectCss {html cssFile} {
        if {$cssFile eq "" || ![file exists $cssFile]} { return $html }
        set css ""
        catch { set css [my _readFile $cssFile] }
        if {$css eq ""} { return $html }
        set block "<style>\n$css\n</style>\n"
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
            fconfigure $fh -encoding utf-8
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
        fconfigure $fh -encoding utf-8
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
            style      "plain"
            stylesdir  ""
            navbg      "#2c3e50"
            navfg      "#ffffff"
            navlinks   {{{&#127968; Start} /} {{&#128218; Alle Dokumente} /?nav=index}}
            navsections 1
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
        try {
            set _httpSock [socket -server [list [self object] handleRequest] \
                [my cfg port]]
        } on error {err} {
            error "Cannot bind to HTTP port [my cfg port]: $err"
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
                    [my cfg tlsport]]
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
    }

    method stop {} {
        catch { close $_httpSock  }
        catch { close $_httpsSock }
        catch { close $_ctrlSock  }
        foreach ch [dict keys $_conns] { catch { close $ch } }
        set _conns {}
    }

    # Style name (?style=) -> path to a CSS file in styles/, or "" (default).
    # sidebar | sticky | collapsible ; anything else = no extra CSS (plain).
    method _styleCss {style} {
        set dir [my cfg stylesdir]
        if {$dir eq ""} { set dir [file join $::mdserver::moduleDir .. styles] }
        switch -- $style {
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

    # True if $dir contains any .md file (transitively).
    method _dirHasAnyMd {dir} {
        if {[llength [glob -nocomplain -directory $dir *.md]] > 0} { return 1 }
        foreach d [glob -nocomplain -directory $dir -type d *] {
            if {[string index [file tail $d] 0] eq "."} continue
            if {[my _dirHasAnyMd $d]} { return 1 }
        }
        return 0
    }

    # First "# H1" of a Markdown file, or "" if none.
    method _h1Title {file} {
        set title ""
        if {![catch {open $file r} fh]} {
            fconfigure $fh -encoding utf-8
            while {[gets $fh line] >= 0} {
                if {[regexp {^#\s+(.+)$} $line -> t]} {
                    set title [string trim $t]; break
                }
            }
            close $fh
        }
        return $title
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
                set fh [open $bt r]; fconfigure $fh -encoding utf-8
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
                set fh [open $idx r]; fconfigure $fh -encoding utf-8
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
            set fh [open $idx r]; fconfigure $fh -encoding utf-8
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

    method _injectNav {html} {
        if {![my cfg nav]} { return $html }
        set bg [my cfg navbg]
        set fg [my cfg navfg]
        # Links from config: a list of {label url} pairs.
        set links ""
        foreach link [my cfg navlinks] {
            lassign $link label url
            append links "<a href=\"$url\" style=\"color:$fg;text-decoration:none;\">$label</a>"
        }
        # Top-level sections, auto-derived from the document root.
        if {[my cfg navsections]} {
            foreach link [my _sectionLinks] {
                lassign $link label url
                append links "<a href=\"$url\" style=\"color:$fg;text-decoration:none;\">$label</a>"
            }
        }
        set style "background:$bg;color:$fg;padding:0.5em 1em;\
margin:0 calc(50% - 50vw) 1em;width:100vw;box-sizing:border-box;\
font-size:0.95em;display:flex;gap:1.4em;align-items:center;align-self:start;"
        set bar "<nav class=\"mdserver-nav\" style=\"$style\">$links</nav>
"
        if {[regexp -indices {<body[^>]*>} $html m]} {
            set e [lindex $m 1]
            return "[string range $html 0 $e]
$bar[string range $html [expr {$e + 1}] end]"
        }
        return "$bar$html"
    }

    # Clean shutdown: close listeners + open connections, end the loop.
    method shutdown {} {
        my stop
        catch { set ::mdserver::running 0 }
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
                catch { puts $chan "stopping"; flush $chan; close $chan }
                my _log "control: stop"
                my shutdown
                after 150 { exit 0 }
            }
            ping    { catch { puts $chan "pong"; flush $chan; close $chan } }
            default { catch { puts $chan "commands: stop ping"; flush $chan; close $chan } }
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
        chan configure $chan -blocking 0 -buffering full \
            -translation crlf -encoding utf-8
        dict set _conns $chan 1
        # readable event resumes this coroutine; timeout guards against slow-loris
        chan event $chan readable [info coroutine]
        set tid [after [my cfg timeout] [list catch [list [info coroutine] TIMEOUT]]]

        try {
            set req [mdserver::Request new $chan]
            after cancel $tid
            chan event $chan readable {}

            my _log "[$req method] [$req path]"

            set theme [$req param theme [my cfg theme]]
            set toc   [$req param toc   [my cfg toc]]
            set style [$req param style [my cfg style]]
            set path  [$req path]

            my _dispatch $chan $req $path $theme $toc $style

        } trap {MDDOCS BADREQUEST} {} {
            # Broken connection / timeout / invalid request -- ignore silently
        } on error {msg} {
            my _log "  -> bgerror: $msg"
            puts stderr "mdserver bgerror: $msg"
        } finally {
            after cancel $tid
            my _flushClose $chan
        }
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
    method _dispatch {chan req urlPath theme toc {style plain}} {
        try {
            # Site index of all documents
            if {[$req param nav ""] eq "index"} {
                set html [$_renderer siteIndex [my cfg root] $theme [my _styleCss $style]]
                my _log "  -> 200 (site index)"
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
                    my _log "  -> 200 (index.md)"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } else {
                    set html [$_renderer index $fsPath $urlPath $theme [my _styleCss $style]]
                    my _log "  -> 200 (directory index)"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                }

            } elseif {![file exists $fsPath]} {
                throw {MDDOCS NOTFOUND} $urlPath

            } else {
                set ext [string tolower [file extension $fsPath]]
                if {$ext eq ".md"} {
                    set html [$_renderer markdown $fsPath $theme $toc [my _styleCss $style]]
                    set html [my _injectChapterNav $html $fsPath]
                    set html [my _injectBookNav $html $fsPath $style]
                    my _log "  -> 200 (markdown)"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } else {
                    set mime [my _mime $ext]
                    my _serveFile $chan $req $fsPath $mime
                }
            }

        } trap {MDDOCS TRAVERSAL} {msg} {
            my _log "  -> 403 ($msg)"
            my _send $chan "403 Forbidden" "text/html; charset=utf-8" \
                "<html><body><h1>403 Forbidden</h1><p>$msg</p></body></html>"
        } trap {MDDOCS NOTFOUND} {msg} {
            my _log "  -> 404"
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1><p>$msg</p></body></html>"
        } trap {POSIX ENOENT} {} {
            my _log "  -> 404 (ENOENT)"
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1></body></html>"
        } on error {msg info} {
            my _log "  -> 500: $msg"
            my _send $chan "500 Internal Server Error" "text/html; charset=utf-8" \
                "<html><body><h1>500 Internal Server Error</h1><pre>$msg</pre></body></html>"
        }
    }

    # Helper methods
    method _safePath {urlPath} {
        set root [my cfg root]
        set path [file normalize [file join $root [string trimleft $urlPath /]]]
        if {![string match "${root}*" $path]} {
            throw {MDDOCS TRAVERSAL} "Directory traversal blocked: $urlPath"
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

    # Write status line + headers (no body). extra = list of "Name: Value".
    method _sendHead {chan status contentType len extra} {
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        foreach h $extra { puts $chan $h }
        puts $chan "Connection: close"
        puts $chan "Server: mdserver/0.5"
        puts $chan ""
    }

    # Serve a static file: Conditional GET (304) + Range (206) + full (200).
    method _serveFile {chan req fsPath mime} {
        set size    [file size $fsPath]
        set mtime   [file mtime $fsPath]
        set lastmod [my _httpDate $mtime]

        # Conditional GET
        set ims [$req header if-modified-since]
        if {$ims ne "" && ![catch {clock scan $ims -gmt 1} imsT] && $mtime <= $imsT} {
            my _log "  -> 304 (not modified)"
            my _sendHead $chan "304 Not Modified" $mime 0 [list "Last-Modified: $lastmod"]
            return
        }

        # Range
        set range [$req header range]
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
                my _log "  -> 416 (range)"
                my _sendHead $chan "416 Range Not Satisfiable" $mime 0 \
                    [list "Content-Range: bytes */$size"]
                return
            }
            set fh [open $fsPath rb]
            seek $fh $start
            set data [read $fh [expr {$end - $start + 1}]]
            close $fh
            my _log "  -> 206 (bytes $start-$end/$size)"
            my _sendHead $chan "206 Partial Content" $mime [string length $data] \
                [list "Accept-Ranges: bytes" "Last-Modified: $lastmod" \
                      "Content-Range: bytes $start-$end/$size"]
            fconfigure $chan -translation binary
            puts -nonewline $chan $data
            return
        }

        # Full (200)
        set data [my _readBin $fsPath]
        my _log "  -> 200 ($size bytes, $mime)"
        my _sendHead $chan "200 OK" $mime [string length $data] \
            [list "Accept-Ranges: bytes" "Last-Modified: $lastmod"]
        fconfigure $chan -translation binary
        puts -nonewline $chan $data
    }

    # 301 redirect (e.g. add a trailing slash to a directory URL).
    method _redirect {chan location} {
        my _log "  -> 301 $location"
        puts $chan "HTTP/1.1 301 Moved Permanently"
        puts $chan "Location: $location"
        puts $chan "Content-Length: 0"
        puts $chan "Connection: close"
        puts $chan "Server: mdserver/0.5"
        puts $chan ""
    }

    method _send {chan status contentType body} {
        set bytes [encoding convertto utf-8 $body]
        set len [string length $bytes]
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        puts $chan "Connection: close"
        puts $chan "Server: mdserver/0.5"
        puts $chan ""
        # Write the body in binary: otherwise -translation crlf expands each \n to \r\n
        # so the byte count would no longer match Content-Length -> truncation.
        chan configure $chan -translation binary
        puts -nonewline $chan $bytes
    }

    method _sendBin {chan status contentType data} {
        set len [string length $data]
        fconfigure $chan -translation binary
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        puts $chan "Connection: close"
        puts $chan "Server: mdserver/0.4"
        puts $chan ""
        puts -nonewline $chan $data
    }

    method _log {msg} {
        if {[my cfg log]} {
            puts "\[[clock format [clock seconds] -format "%H:%M:%S"]\] $msg"
        }
    }

    method _printStatus {} {
        puts "mdserver 0.4 -- Tcl Markdown Server"
        puts "  Root:  [my cfg root]"
        puts "  Theme: [my cfg theme]"
        puts ""
        puts "  HTTP:  http://localhost:[my cfg port]/"
        if {[my cfg tls]} {
            puts "  HTTPS: https://localhost:[my cfg tlsport]/"
            puts "  Cert:  [my cfg cert]"
        } else {
            puts "  HTTPS: nicht aktiv (--cert und --key angeben)"
        }
        puts ""
        puts "Press Ctrl+C to stop."
        puts ""
    }
}
