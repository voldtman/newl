.POSIX:
.SUFFIXES:

include config.mk

# Base flags for compiling
NEWLCPPFLAGS = -I. -DWLR_USE_UNSTABLE -D_POSIX_C_SOURCE=200809L \
	-DVERSION=\"$(VERSION)\" $(XWAYLAND)

# Development and warning flags
NEWLDEVCFLAGS = -g \
	-Wpedantic -Wall -Wextra \
	-Wdeclaration-after-statement \
	-Wno-unused-parameter \
	-Wshadow \
	-Wunused-macros \
	-Werror=implicit \
	-Werror=return-type \
	-Werror=incompatible-pointer-types \
	-Wfloat-conversion

# Optimization flags
NEWLOPTFLAGS = \
	-O3 \
	-march=native \
	-ffast-math \
	-flto=auto \
	-fno-fat-lto-objects \
	-ffunction-sections \
	-fdata-sections \
	-fno-omit-frame-pointer \
	-fno-plt

# Combine all flags
NEWLALLFLAGS = $(NEWLDEVCFLAGS) $(NEWLOPTFLAGS)

# Package configuration
PKGS = wayland-server xkbcommon libinput $(XLIBS)
NEWLCFLAGS = `$(PKG_CONFIG) --cflags $(PKGS)` $(WLR_INCS) $(NEWLCPPFLAGS) $(NEWLALLFLAGS) $(CFLAGS)

# Linker flags
LDFLAGS += \
	-flto \
	-Wl,--gc-sections \
	-Wl,--as-needed \
	-Wl,-O3 \
	-Wl,--sort-common \
	-Wl,--relax

LDLIBS = `$(PKG_CONFIG) --libs $(PKGS)` $(WLR_LIBS) -lm $(LIBS)

# For PGO: Uncomment the appropriate set of flags when using profile guided optimization
# First compile with:
NEWLOPTFLAGS += -fprofile-generate
LDFLAGS += -fprofile-generate
# Then run the program normally, and recompile with:
# NEWLOPTFLAGS += -fprofile-use
# LDFLAGS += -fprofile-use

all: newl

newl: newl.o util.o dwl-ipc-unstable-v2-protocol.o
	$(CC) newl.o util.o dwl-ipc-unstable-v2-protocol.o $(NEWLCFLAGS) $(LDFLAGS) $(LDLIBS) -o $@

newl.o: newl.c client.h config.h config.mk cursor-shape-v1-protocol.h \
	ext-image-copy-capture-v1-protocol.h \
	pointer-constraints-unstable-v1-protocol.h wlr-layer-shell-unstable-v1-protocol.h \
	wlr-output-power-management-unstable-v1-protocol.h xdg-shell-protocol.h \
	dwl-ipc-unstable-v2-protocol.h

util.o: util.c util.h

dwl-ipc-unstable-v2-protocol.o: dwl-ipc-unstable-v2-protocol.c dwl-ipc-unstable-v2-protocol.h

# Protocol generation
WAYLAND_SCANNER   = `$(PKG_CONFIG) --variable=wayland_scanner wayland-scanner`
WAYLAND_PROTOCOLS = `$(PKG_CONFIG) --variable=pkgdatadir wayland-protocols`

cursor-shape-v1-protocol.h:
	$(WAYLAND_SCANNER) enum-header \
		$(WAYLAND_PROTOCOLS)/staging/cursor-shape/cursor-shape-v1.xml $@

ext-image-copy-capture-v1-protocol.h:
	$(WAYLAND_SCANNER) enum-header \
		$(WAYLAND_PROTOCOLS)/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml $@

pointer-constraints-unstable-v1-protocol.h:
	$(WAYLAND_SCANNER) enum-header \
		$(WAYLAND_PROTOCOLS)/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml $@

wlr-layer-shell-unstable-v1-protocol.h:
	$(WAYLAND_SCANNER) enum-header \
		protocols/wlr-layer-shell-unstable-v1.xml $@

wlr-output-power-management-unstable-v1-protocol.h:
	$(WAYLAND_SCANNER) server-header \
		protocols/wlr-output-power-management-unstable-v1.xml $@

xdg-shell-protocol.h:
	$(WAYLAND_SCANNER) server-header \
		$(WAYLAND_PROTOCOLS)/stable/xdg-shell/xdg-shell.xml $@

dwl-ipc-unstable-v2-protocol.h:
	$(WAYLAND_SCANNER) server-header \
		protocols/dwl-ipc-unstable-v2.xml $@

dwl-ipc-unstable-v2-protocol.c:
	$(WAYLAND_SCANNER) private-code \
		protocols/dwl-ipc-unstable-v2.xml $@

config.h:
	cp config.def.h $@

clean:
	rm -f newl *.o *-protocol.h
# rm -f *.gcda *.gcno

dist: clean
	mkdir -p newl-$(VERSION)
	cp -R LICENSE* Makefile CHANGELOG.md README.md client.h config.def.h \
		config.mk protocols newl.1 newl.c util.c util.h newl.desktop \
		newl-$(VERSION)
	tar -caf newl-$(VERSION).tar.gz newl-$(VERSION)
	rm -rf newl-$(VERSION)

install: newl
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	rm -f $(DESTDIR)$(PREFIX)/bin/newl
	cp -f newl $(DESTDIR)$(PREFIX)/bin
	chmod 755 $(DESTDIR)$(PREFIX)/bin/newl
	mkdir -p $(DESTDIR)$(DATADIR)/wayland-sessions
	cp -f newl.desktop $(DESTDIR)$(DATADIR)/wayland-sessions/newl.desktop
	chmod 644 $(DESTDIR)$(DATADIR)/wayland-sessions/newl.desktop

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/newl \
		$(DESTDIR)$(DATADIR)/wayland-sessions/newl.desktop

.SUFFIXES: .c .o
.c.o:
	$(CC) $(CPPFLAGS) $(NEWLCFLAGS) -o $@ -c $<