#!/usr/bin/env tclsh
# Test mdstack::html::export Asset-Copy (Bilder mit-kopieren)

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    # docir::util ist eine .tm-Datei -- braucht tcl::tm::path zusaetzlich
    # zum auto_path. Sibling-Repo: ../../docir/lib/tm
    foreach p [list \
        [file normalize [file join [file dirname [info script]] .. .. docir lib tm]] \
        [file normalize [file join $::env(HOME) lib tcltk docir lib tm]]] {
        if {[file isdirectory $p]} {
            ::tcl::tm::path add $p
        }
    }
    set ::_setup_done 1
}


package require mdstack::parser
package require mdstack::html

set passed 0
set failed 0

proc testcase {name script} {
    global passed failed
    if {[catch $script err]} {
        puts "FAIL: $name -- $err"
        incr failed
    } else {
        puts "PASS: $name"
        incr passed
    }
}

proc makePng {path} {
    set hex "89504e470d0a1a0a0000000d4948445200000001000000010802000000"
    append hex "9077"
    append hex "53de0000000c4944415478da63f8cffc1f000004ff01ffd472ee26"
    append hex "0000000049454e44ae426082"
    set png [binary format "H*" $hex]
    set fh [open $path wb]
    puts -nonewline $fh $png
    close $fh
}

package require docir::util
set workDir [file join [docir::util::tmpdir] test-mdhtml-assets-[pid]]
set srcDir [file join $workDir src]
set outDir [file join $workDir out]
file mkdir $srcDir [file join $srcDir icons] $outDir

makePng [file join $srcDir logo.png]
makePng [file join $srcDir icons star.png]

set md "# Test

!\[logo\](logo.png)

Icon: !\[star\](icons/star.png)

Extern: !\[ext\](https://example.com/x.png)
"
set fh [open [file join $srcDir test.md] w]
puts $fh $md
close $fh

testcase "exportFile copies block image" {
    mdstack::html::exportFile [file join $::srcDir test.md] [file join $::outDir test.html]
    if {![file exists [file join $::outDir logo.png]]} {
        error "logo.png nicht im outDir"
    }
}

testcase "exportFile copies image with subdir structure" {
    if {![file exists [file join $::outDir icons star.png]]} {
        error "icons/star.png nicht im outDir mit Pfad-Struktur"
    }
}

testcase "exportFile skips external URLs" {
    if {[file exists [file join $::outDir x.png]]} {
        error "Externe URL faelschlich kopiert"
    }
}

testcase "exportFile is idempotent" {
    set logoSize1 [file size [file join $::outDir logo.png]]
    mdstack::html::exportFile [file join $::srcDir test.md] [file join $::outDir test.html]
    set logoSize2 [file size [file join $::outDir logo.png]]
    if {$logoSize1 != $logoSize2} {
        error "Idempotenz verletzt"
    }
}

testcase "export with copyImages=0 skips copy" {
    file delete -force [file join $::outDir logo.png]
    set ast [mdstack::parser::parse $::md]
    mdstack::html::export $ast [file join $::outDir test2.html] \
        -root $::srcDir -copyImages 0
    if {[file exists [file join $::outDir logo.png]]} {
        error "logo.png trotz -copyImages 0 kopiert"
    }
}

file delete -force $workDir

puts ""
puts "  Total: $passed passed, $failed failed"
if {$failed > 0} { exit 1 }
