# mdstack/indexgen-0.1.tm  --  package mdstack::indexgen
#
# Generates index.md and indexsub.md for Markdown directory trees.
# Uses managed blocks (HTML comments) to update generated sections
# on subsequent runs, without destroying manual content.
#
# Public API:
#   mdstack::indexgen::scan $dir ?-verbose 0? ?-dryrun 0?
#       Recursive: generate/update index.md + indexsub.md
#       -verbose 1: Print changes to stdout
#       -dryrun 1:  Check only, write nothing
#       Returns: dict with keys "updated", "unchanged", "created"
#
#   mdstack::indexgen::updateIndex $dir ?-dryrun 0?
#       Only update index.md in directory
#
#   mdstack::indexgen::updateSub $dir ?-dryrun 0?
#       Only update indexsub.md in directory
#
#   mdstack::indexgen::readTitle $file
#       Read title from .md (YAML frontmatter or first H1, fallback: filename)
#
#   mdstack::indexgen::readDescription $file
#       Read first non-empty paragraph after title (max 200 characters)
#
#   mdstack::indexgen::configure ?-key value ...?
#       Change configuration:
#       -skip_files   {index.md indexsub.md}  Files to skip
#       -skip_dirs    {build dist .git ...}   Directories to skip
#       -descriptions 0/1                     Show short description in index
#       -sort         name/title              Sort order: filename or title
#
# Managed Blocks:
#   <!-- mdindexgen:begin -->
#   ... generated content ...
#   <!-- mdindexgen:end -->
#
#   If the file already exists with manual content before/after the blocks,
#   it is preserved. Only the block content is replaced.
#
# Example:
#   package require mdstack::indexgen 0.1
#   mdstack::indexgen::scan /path/to/docs -verbose 1
#   mdstack::indexgen::scan /path/to/docs -dryrun 1 -verbose 1

package require Tcl 8.6 9
package provide mdstack::indexgen 0.1

namespace eval mdstack::indexgen {
    namespace export scan updateIndex readTitle readDescription configure

    variable BEGIN "<!-- mdindexgen:begin -->"
    variable END   "<!-- mdindexgen:end -->"

    # Files to skip during index generation
    variable SKIP_FILES {index.md indexsub.md}

    # Directories to skip during recursive search
    variable SKIP_DIRS {
        build dist .git .svn .hg __pycache__
        node_modules vendor vendors
    }

    # Optional features
    variable DESCRIPTIONS 0     ;# Show short description
    variable SORT         "name" ;# name or title
}

# ── Configuration ────────────────────────────────────────

proc mdstack::indexgen::configure {args} {
    # Change configuration.
    #
    # Options:
    #   -skip_files   {index.md indexsub.md}
    #   -skip_dirs    {build dist .git ...}
    #   -descriptions 0/1
    #   -sort         name/title
    #
    # Without arguments: return current configuration as dict.

    variable SKIP_FILES
    variable SKIP_DIRS
    variable DESCRIPTIONS
    variable SORT

    if {[llength $args] == 0} {
        return [dict create \
            -skip_files   $SKIP_FILES \
            -skip_dirs    $SKIP_DIRS \
            -descriptions $DESCRIPTIONS \
            -sort         $SORT]
    }

    foreach {key val} $args {
        switch -- $key {
            -skip_files   { set SKIP_FILES $val }
            -skip_dirs    { set SKIP_DIRS $val }
            -descriptions { set DESCRIPTIONS [expr {!!$val}] }
            -sort         {
                if {$val ni {name title}} {
                    error "mdstack::indexgen::configure -sort: '$val'\
                           (allowed: name, title)"
                }
                set SORT $val
            }
            default {
                error "mdstack::indexgen::configure: Unknown option '$key'\
                       (allowed: -skip_files, -skip_dirs, -descriptions,\
                       -sort)"
            }
        }
    }
}

# ── File Helpers ──────────────────────────────────────────

proc mdstack::indexgen::_stripBom {text} {
    # Removes UTF-8 BOM (EF BB BF) at file start.
    if {[string range $text 0 0] eq "\uFEFF"} {
        return [string range $text 1 end]
    }
    return $text
}

proc mdstack::indexgen::_readFile {file} {
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    return [_stripBom $data]
}

proc mdstack::indexgen::_writeFile {file text} {
    set fh [open $file w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $text
    close $fh
}

# ── Public Helpers ──────────────────────────────────

proc mdstack::indexgen::_cleanTitle {title} {
    # Normalise a heading for use as plain Markdown link text. Nested brackets
    # would otherwise break the generated "[title](file)" link.
    #   [text]{.attr}  -> text   (pandoc bracketed span, e.g. "[pack]{.index}")
    #   [text](url)    -> text   (inline link)
    #   {.attr}        -> (drop) (leftover attribute block)
    regsub -all {\[([^\]]*)\]\{[^\}]*\}} $title {\1} title
    regsub -all {\[([^\]]*)\]\([^)]*\)} $title {\1} title
    regsub -all {\{[^\}]*\}} $title {} title
    return [string trim $title]
}

proc mdstack::indexgen::readTitle {file} {
    # Reads title from a Markdown file.
    #
    # Order:
    #   1. YAML frontmatter: title: ...
    #   2. First H1: # ...
    #   3. Fallback index.md: directory name
    #   4. Fallback others: filename without extension
    #
    # BOM is automatically removed.

    set fh [open $file r]
    fconfigure $fh -encoding utf-8

    set title ""
    set in_frontmatter 0
    set line_no 0
    set first_line 1

    while {[gets $fh line] >= 0} {
        incr line_no

        # Remove BOM in first line
        if {$first_line} {
            set line [_stripBom $line]
            set first_line 0
        }

        # Frontmatter start (must be first line)
        if {$line_no == 1 && [string trim $line] eq "---"} {
            set in_frontmatter 1
            continue
        }

        # Frontmatter end
        if {$in_frontmatter && [string trim $line] eq "---"} {
            set in_frontmatter 0
            continue
        }

        # title: in frontmatter
        if {$in_frontmatter} {
            if {[regexp {^title:\s*(.+)} $line -> t]} {
                set title [string trim $t "\"' "]
                break
            }
            continue
        }

        # H1 heading (first match)
        if {[regexp {^#\s+(.*)} $line -> t]} {
            set title [string trim $t]
            break
        }

        # Give up after 30 lines
        if {$line_no > 30} break
    }

    close $fh

    if {$title eq ""} {
        # For index.md: directory name as fallback (not "index")
        set basename [file tail $file]
        if {[string tolower $basename] eq "index.md"} {
            set title [file tail [file dirname [file normalize $file]]]
        } else {
            set title [file rootname $basename]
        }
    }
    return [_cleanTitle $title]
}

proc mdstack::indexgen::readDescription {file} {
    # Reads first non-empty paragraph after title.
    # Returns max 200 characters, truncated with ...
    # Empty string if no description found.

    set fh [open $file r]
    fconfigure $fh -encoding utf-8

    set found_title 0
    set in_frontmatter 0
    set desc_lines {}
    set line_no 0
    set first_line 1

    while {[gets $fh line] >= 0} {
        incr line_no

        if {$first_line} {
            set line [_stripBom $line]
            set first_line 0
        }

        # Skip frontmatter
        if {$line_no == 1 && [string trim $line] eq "---"} {
            set in_frontmatter 1
            continue
        }
        if {$in_frontmatter} {
            if {[string trim $line] eq "---"} {
                set in_frontmatter 0
            }
            continue
        }

        # Skip title (H1)
        if {!$found_title && [regexp {^#\s+} $line]} {
            set found_title 1
            continue
        }

        # After title: skip empty lines
        if {$found_title && [string trim $line] eq ""} {
            # If we already have description lines -> end
            if {[llength $desc_lines] > 0} break
            continue
        }

        # Collect description text (no headings, no lists, no code)
        if {$found_title} {
            if {[regexp {^[#\-\*\|`>]} $line]} break
            lappend desc_lines [string trim $line]
            if {[llength $desc_lines] >= 3} break
        }

        if {$line_no > 40} break
    }

    close $fh

    if {[llength $desc_lines] == 0} {
        return ""
    }

    set desc [join $desc_lines " "]
    if {[string length $desc] > 200} {
        set desc "[string range $desc 0 196]..."
    }
    return $desc
}

# ── Internal Helpers ────────────────────────────────────────

proc mdstack::indexgen::_listMarkdownFiles {dir} {
    variable SKIP_FILES
    set files {}
    foreach f [glob -nocomplain -directory $dir *.md] {
        set name [file tail $f]
        if {$name in $SKIP_FILES} continue
        lappend files $f
    }
    return [lsort -dictionary $files]
}

proc mdstack::indexgen::_listSubDirs {dir} {
    variable SKIP_DIRS
    set dirs {}
    foreach d [glob -nocomplain -directory $dir *] {
        if {![file isdirectory $d]} continue
        set name [file tail $d]
        if {$name in $SKIP_DIRS} continue
        # Skip hidden directories
        if {[string index $name 0] eq "."} continue
        lappend dirs $d
    }
    return [lsort -dictionary $dirs]
}

proc mdstack::indexgen::_sortEntries {entries} {
    # Sorts {filename title ?desc?} lists.
    # According to SORT setting: name (filename) or title.
    variable SORT

    if {$SORT eq "title"} {
        return [lsort -dictionary -index 1 $entries]
    }
    return [lsort -dictionary -index 0 $entries]
}

proc mdstack::indexgen::_buildBlock {content} {
    # Baut den managed Block mit BEGIN/END-Markern.
    variable BEGIN
    variable END
    return "$BEGIN\n$content\n$END"
}

proc mdstack::indexgen::_replaceBlock {text block} {
    # Replaces managed block in text.
    # Safe against regsub special characters (& \1 etc.).
    variable BEGIN
    variable END

    set idx_begin [string first $BEGIN $text]
    set idx_end   [string first $END $text]

    if {$idx_begin < 0 || $idx_end < 0} {
        return ""  ;# no block found
    }

    set before [string range $text 0 [expr {$idx_begin - 1}]]
    set after  [string range $text [expr {$idx_end + [string length $END]}] end]

    return "${before}${block}${after}"
}

proc mdstack::indexgen::_updateBlock {file content args} {
    # Ersetzt den managed Block in $file, oder haengt ihn an.
    #
    # Optionen:
    #   -dryrun 0/1  Nur pruefen, nicht schreiben
    #
    # Rueckgabe: "created", "updated", "unchanged"

    variable BEGIN
    variable END

    array set opts {-dryrun 0}
    array set opts $args

    set block [_buildBlock $content]

    if {[file exists $file]} {
        set text [_readFile $file]
        set old_text $text

        if {[string match "*$BEGIN*$END*" $text]} {
            # String-based replacement (safe against & \1 etc.)
            set new_text [_replaceBlock $text $block]
            if {$new_text ne ""} {
                set text $new_text
            }
        } else {
            append text "\n\n$block\n"
        }

        if {$text eq $old_text} {
            return "unchanged"
        }

        if {!$opts(-dryrun)} {
            _writeFile $file $text
        }
        return "updated"
    } else {
        if {!$opts(-dryrun)} {
            _writeFile $file "$block\n"
        }
        return "created"
    }
}

# ── Public API ─────────────────────────────────────

# True if $dir or any subdirectory (transitively) contains at least one
# Markdown document (any *.md other than index.md / indexsub.md). Used to
# hide empty subdirectories from the generated listing.
proc mdstack::indexgen::_hasDocsDeep {dir} {
    foreach f [glob -nocomplain -directory $dir *.md] {
        if {[file tail $f] ni {index.md indexsub.md}} { return 1 }
    }
    foreach d [_listSubDirs $dir] {
        if {[_hasDocsDeep $d]} { return 1 }
    }
    return 0
}

proc mdstack::indexgen::updateIndex {dir args} {
    # Creates/updates the managed block in $dir/index.md.
    # One combined list: documents first, then non-empty subdirectories.
    # Only the managed block is touched; manual prose around it is preserved.
    #
    # Options: -dryrun 0/1
    # Returns: Dict {file $path status $status}
    variable DESCRIPTIONS

    array set opts {-dryrun 0}
    array set opts $args

    set files [_listMarkdownFiles $dir]

    # Non-empty subdirectories only (transitively contain a document).
    set subdirs {}
    foreach d [_listSubDirs $dir] {
        if {[_hasDocsDeep $d]} { lappend subdirs $d }
    }

    if {[llength $files] == 0 && [llength $subdirs] == 0} {
        return [dict create file "" status ""]
    }

    # Documents (sorted per SORT).
    set docEntries {}
    foreach f $files {
        set name  [file tail $f]
        set title [readTitle $f]
        set desc  ""
        if {$DESCRIPTIONS} { set desc [readDescription $f] }
        lappend docEntries [list $name $title $desc]
    }
    set docEntries [_sortEntries $docEntries]

    # Non-empty subdirectories (sorted per SORT); link to their index.md,
    # title from that index.md (falls back to the folder name).
    set dirEntries {}
    foreach d $subdirs {
        set name  [file tail $d]
        set idx   [file join $d index.md]
        set title [expr {[file exists $idx] ? [readTitle $idx] : $name}]
        lappend dirEntries [list $name $title ""]
    }
    set dirEntries [_sortEntries $dirEntries]

    # Build the block: documents first, then folders -- one flat list.
    set lines {}
    lappend lines "## Contents
"
    foreach entry $docEntries {
        lassign $entry name title desc
        if {$desc ne ""} {
            lappend lines [format { - [%s](%s) -- %s} $title $name $desc]
        } else {
            lappend lines [format { - [%s](%s)} $title $name]
        }
    }
    foreach entry $dirEntries {
        lassign $entry name title desc
        lappend lines [format { - [%s](%s/index.md)} $title $name]
    }

    set content [join $lines "
"]
    set idxFile [file join $dir index.md]
    set status  [_updateBlock $idxFile $content -dryrun $opts(-dryrun)]
    return [dict create file $idxFile status $status]
}


proc mdstack::indexgen::_removeBlock {file dryrun} {
    # Remove a previously written managed block (BEGIN..END) from $file, keeping
    # surrounding prose. Returns "updated" if something was removed, else "".
    variable BEGIN
    variable END
    if {![file exists $file]} { return "" }
    set text [_readFile $file]
    set i [string first $BEGIN $text]
    set j [string first $END $text]
    if {$i < 0 || $j < $i} { return "" }
    set j [expr {$j + [string length $END]}]
    set new "[string range $text 0 [expr {$i - 1}]][string range $text $j end]"
    # Collapse 3+ consecutive newlines left at the seam into two.
    regsub -all {\n{3,}} $new "\n\n" new
    set new [string trimleft $new "\n"]
    if {$new eq $text} { return "" }
    if {!$dryrun} { _writeFile $file $new }
    return "updated"
}

proc mdstack::indexgen::scan {dir args} {
    # Recursive: creates/updates index.md for $dir and all subdirectories.
    # Subdirectories are processed FIRST so their index.md (and thus titles)
    # exist before the parent is indexed -- a single pass is complete.
    #
    # Options: -verbose 0/1, -dryrun 0/1
    # Returns: dict {created {...} updated {...} unchanged {...}}
    array set opts {-verbose 0 -dryrun 0}
    array set opts $args

    set depth [expr {[info exists opts(-_depth)] ? $opts(-_depth) : 0}]
    set result [dict create created {} updated {} unchanged {}]
    set prefix [expr {$opts(-dryrun) ? "(dry-run) " : ""}]

    # Directories owned by bookkit (they contain book.tcl) are left to the book
    # tool (book-webindex.tcl): do not recurse into or index them. The parent
    # still lists such a directory as a section (it has documents).
    if {[file exists [file join $dir book.tcl]]} {
        # Book dir: owned by bookkit. Remove any stale mdindexgen block we may
        # have written before, then leave the directory to the book tool.
        set idx [file join $dir index.md]
        set st  [_removeBlock $idx $opts(-dryrun)]
        if {$st ne ""} {
            dict lappend result $st $idx
            if {$opts(-verbose)} { puts "${prefix}${st} (book, block removed): $idx" }
        }
        return $result
    }

    # Recurse first (bottom-up).
    foreach d [_listSubDirs $dir] {
        set sub [scan $d -verbose $opts(-verbose) -dryrun $opts(-dryrun) \
                     -_depth [expr {$depth + 1}]]
        foreach key {created updated unchanged} {
            dict lappend result $key {*}[dict get $sub $key]
        }
    }

    # Then this directory's index.md.
    set r [updateIndex $dir -dryrun $opts(-dryrun)]
    set status [dict get $r status]
    set file   [dict get $r file]
    if {$status ne ""} {
        dict lappend result $status $file
        if {$opts(-verbose) && $status ne "unchanged"} {
            puts "${prefix}${status}: $file"
        }
    }

    if {$opts(-verbose) && $depth == 0} {
        set nc [llength [dict get $result created]]
        set nu [llength [dict get $result updated]]
        set nn [llength [dict get $result unchanged]]
        if {$nc + $nu + $nn > 0} {
            puts "${prefix}---"
            puts "${prefix}Result: $nc new, $nu updated, $nn unchanged"
        }
    }
    return $result
}
