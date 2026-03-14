# wordp.tcl --
#     A very basic word processor
#

# mainWindow --
#     Set up the window with some buttons
#
# Arguments:
#     None
#
# Returns:
#     Nothing
#
# Side effects:
#     Creates a text widget and some formatting buttons
#
proc mainWindow {} {

    global bold
    global italic
    global texttag

    #
    # Create the toolbar
    #
    set t [frame .toolbar]


    ttk::button      $t.store  -text Store -style Toolbutton -command {storeText}
    ttk::checkbutton $t.bold   -text B     -style Toolbutton -variable bold \
        -command {toggleFont}
    ttk::checkbutton $t.italic -text I     -style Toolbutton -variable italic \
        -command {toggleFont}

    ttk::separator .sep

    text   .text

    grid   $t.store $t.bold $t.italic -padx 2 -sticky ns

    grid   $t    -sticky w
    grid   .sep  -sticky we
    grid   .text

    #
    # Tags for the various fonts
    #
    .text tag configure bolditalic -font "Times 12 bold italic"
    .text tag configure bold       -font "Times 12 bold"
    .text tag configure italic     -font "Times 12 italic"
    .text tag configure normal     -font "Times 12"
    .text tag add normal insert

    bind .text <KeyPress> {+insertChar %K}

    set texttag normal
    set italic  0
    set bold    0
}

# insertChar --
#     Insert the typed character with the right tag
#
# Arguments:
#     char        Character to be typed
#
# Returns:
#     Nothing
#
proc insertChar {char} {

    if { [string length $char] == 1 } {
        .text insert insert $char $::texttag
        return -code break
    }
}

# toggleFont --
#     Make the text appear in bold or italic font or normal
#
# Arguments:
#     None
#
# Returns:
#     Nothing
#
# Side effects:
#     Next letters typed in the text widget have the selected font
#
proc toggleFont {} {
    global bold
    global italic
    global texttag

    if { $italic } {
        if { $bold } {
            set texttag bolditalic
        } else {
            set texttag italic
        }
    } else {
        if { $bold } {
            set texttag bold
        } else {
            set texttag normal
        }
    }
}

# toggleBold --
#     Make the text appear in bold font (or ordinary if it was bold)
#
# Arguments:
#     None
#
# Returns:
#     Nothing
#
# Side effects:
#     Next letters typed in the text widget are italic
#
proc toggleBold {} {
    global bold
    global texttag

    if { $bold } {
        set texttag bold
    } else {
        set texttag normal
    }
}

# storeText --
#     Dump the contents
#
# Arguments:
#     None
#
# Returns:
#     Nothing
#
# Side effects:
#     Prints the contents of the text widget in a console
#
proc storeText {} {
    console show
    puts [.text dump 1.0 end]
}

# main --
#     Test the thing
#
#
mainWindow


