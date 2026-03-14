#!/usr/bin/env tclsh
# mdmodel-0.1 Demo
# CLI demo for mdmodel

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdmodel 0.1

set ast [dict create \
    type document \
    version 1 \
    meta {title "Demo"} \
    blocks {
        {type heading level 1 content {{type text value "Title"}} anchor "title"}
        {type heading level 2 content {{type text value "Install"}} anchor "install"}
        {type paragraph content {{type text value "Text"}}}
    }
]

set doc [mdmodel::new $ast]

puts "TOC:"
puts [mdmodel::toc $doc]

puts "\nAnchors:"
puts [mdmodel::anchors $doc]

puts "\nHeadings:"
puts [mdmodel::headings $doc]
