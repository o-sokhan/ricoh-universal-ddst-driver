# ==============================================================================
# Ricoh DDST/GDI CUPS driver - macOS build
#
#   make                 build the three filters (universal arm64 + x86_64 on macOS)
#   sudo make install    copy filters and PPDs into /Library/Printers (run `make` first)
#   sudo make uninstall  remove them again
#   make test            unit + integration tests with coverage (macOS or Linux)
#   make pkg             build an installer package in dist/ (macOS only)
#
# JBIG compression is compiled in from jbig/ (jbigkit 2.1), so the filters
# depend only on the system CUPS libraries.
# ==============================================================================

UNAME        := $(shell uname -s)
CC           ?= cc
CFLAGS       ?= -O2 -Wall -Wextra
CPPFLAGS     += -Ijbig
LIBS          = -lcups -lcupsimage
VERSION      ?= $(shell v=$$(git describe --tags --always 2>/dev/null); echo $${v:-0.0.0} | sed 's/^v//')

ifeq ($(UNAME),Darwin)
ARCHFLAGS    ?= -arch arm64 -arch x86_64
CFLAGS       += $(ARCHFLAGS) -mmacosx-version-min=12.0
endif

FILTER_DIR   ?= /Library/Printers/Ricoh/Filter
PPD_DIR      ?= /Library/Printers/PPDs/Contents/Resources
FILTERS       = rastertoricohddst rastertoricohjbig rastertoricohlhpl
PPDS          = $(wildcard ppd/*.ppd)
OWNER        ?= -o root -g wheel

.PHONY: all build install uninstall test pkg clean

all: build
build: $(FILTERS)

rastertoricohddst: rastertoricohddst.c jbig/jbig.c jbig/jbig_ar.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $^ $(LIBS)

rastertoricohjbig: rastertoricohjbig.c jbig/jbig.c jbig/jbig_ar.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $^ $(LIBS)

rastertoricohlhpl: rastertoricohlhpl.c jbig/jbig85.c jbig/jbig_ar.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $^ $(LIBS)

# PPDs reference filters by absolute path, so the CUPS filter search path
# (/usr/libexec/cups/filter, SIP-protected) is never touched.
# Deliberately not depending on `build`, so sudo never compiles into root-owned files.
install:
	@for f in $(FILTERS); do [ -x $$f ] || { echo "Error: $$f not built. Run 'make' (without sudo) first." >&2; exit 1; }; done
	install -d $(OWNER) -m 755 "$(DESTDIR)$(FILTER_DIR)" "$(DESTDIR)$(PPD_DIR)"
	for f in $(FILTERS); do install $(OWNER) -m 755 $$f "$(DESTDIR)$(FILTER_DIR)/$$f"; done
	for p in $(PPDS); do \
		sed -E 's#(application/vnd\.cups-raster 0 )(rastertoricoh[a-z]+)#\1$(FILTER_DIR)/\2#' "$$p" \
			> "$(DESTDIR)$(PPD_DIR)/$$(basename $$p)"; \
		chmod 644 "$(DESTDIR)$(PPD_DIR)/$$(basename $$p)"; \
	done
	@echo "Installed. Add the printer in System Settings > Printers & Scanners and pick 'Ricoh SP ... DDST'."

uninstall:
	rm -f $(addprefix "$(DESTDIR)$(FILTER_DIR)"/,$(FILTERS))
	-rmdir "$(DESTDIR)$(FILTER_DIR)" "$(DESTDIR)/Library/Printers/Ricoh" 2>/dev/null
	rm -f $(addprefix "$(DESTDIR)$(PPD_DIR)"/,$(notdir $(PPDS)))

test:
	./tests/run_coverage.sh

pkg:
	./packaging/build_pkg.sh "$(VERSION)" dist

clean:
	rm -f $(FILTERS) *.o *.gcda *.gcno *.gcov
	rm -rf dist *.dSYM
