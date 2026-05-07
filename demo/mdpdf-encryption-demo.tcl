#!/usr/bin/env tclsh
# mdpdf-encryption-demo.tcl
# Zeigt AES-128 Verschluesselung beim PDF-Export aus Markdown.
# pdf4tcl 0.9.4.11 + mdpdf 0.2

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require mdstack::pdf 0.2

set scriptDir [file dirname [file normalize [info script]]]
set pdfDir    [file join $scriptDir pdf]
file mkdir $pdfDir

set markdown {
# Encrypted PDF Demo

This document is exported with AES-128 password protection.

## Content

Normal text, **bold**, *italic*, `code`.

## Links

- [Tcl/Tk Homepage](https://www.tcl.tk)
- [pdf4tcl on GitHub](https://github.com/gregnix/pdf4tcl)

## Table

| Option | Value |
|--------|-------|
| Encryption | AES-128 (V=4, R=4) |
| User password | see below |
| Owner password | see below |

---

*Protected with mdpdf 0.2 / pdf4tcl 0.9.4.11*
}

package require mdstack::parser 0.2
set ast [mdstack::parser::parse $markdown]

# --- a) User password ---
set out [file join $pdfDir mdpdf-encrypted-user.pdf]
mdstack::pdf::export $ast $out \
    -title        "Encrypted Demo (User)" \
    -userpassword "secret" \
    -fontsize     11 -margin 50
puts "Written: $out  (user password: secret)"

# --- b) Owner password ---
set out [file join $pdfDir mdpdf-encrypted-owner.pdf]
mdstack::pdf::export $ast $out \
    -title         "Encrypted Demo (Owner)" \
    -ownerpassword "admin" \
    -fontsize      11 -margin 50
puts "Written: $out  (owner password: admin)"

# --- c) User + Owner ---
set out [file join $pdfDir mdpdf-encrypted-both.pdf]
mdstack::pdf::export $ast $out \
    -title         "Encrypted Demo (User+Owner)" \
    -userpassword  "user123" \
    -ownerpassword "admin456" \
    -fontsize      11 -margin 50
puts "Written: $out  (user: user123 / owner: admin456)"
