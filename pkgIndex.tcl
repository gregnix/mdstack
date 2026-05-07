# pkgIndex.tcl -- Wurzel-Bruecke
#
# Erlaubt das ganze Repo als Modul-Verzeichnis im auto_path zu nutzen.
# Module liegen in lib/, die echte pkgIndex.tcl ist dort.
set dir [file join $dir lib]
source [file join $dir pkgIndex.tcl]
