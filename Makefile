# mdstack Makefile -- Install / Test

PREFIX     ?= /usr/local
INSTALLDIR := $(PREFIX)/lib/tcltk/mdstack
USERDIR    := $(HOME)/lib/tcltk/mdstack

.PHONY: install install-user uninstall test pkgindex help

help:
	@echo "Targets:"
	@echo "  make install        # nach $(INSTALLDIR) (sudo evtl. noetig)"
	@echo "  make install-user   # nach $(USERDIR), ohne sudo"
	@echo "  make uninstall      # entfernt $(INSTALLDIR)"
	@echo "  make pkgindex       # pkgIndex.tcl neu generieren"
	@echo "  make test           # Tests"

install:
	mkdir -p $(INSTALLDIR)
	cp -r lib/. $(INSTALLDIR)/
	@echo "Installiert nach $(INSTALLDIR)"

install-user:
	mkdir -p $(USERDIR)
	cp -r lib/. $(USERDIR)/
	@echo "Installiert nach $(USERDIR)"
	@echo "Hinweis: setze TCLLIBPATH=\"\$$HOME/lib/tcltk/mdstack\""

uninstall:
	rm -rf $(INSTALLDIR)

pkgindex:
	tclsh tools/generate-pkgindex.tcl lib --write

test:
	cd tests && tclsh all.tcl
