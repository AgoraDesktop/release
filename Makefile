# Makefile — build, install and package the desktop this release pins.
#
#   make                 build every component into a staged prefix
#   make install         copy the staged prefix into $(DESTDIR)$(PREFIX)
#   make deb             build Debian packages with dpkg-buildpackage
#   make clean           remove the per-component build trees
#   make distclean       remove the build trees and the staged prefix
#
# The build is DESTDIR-based, so `make` needs no root and `make install` writes
# only where DESTDIR and PREFIX say. `make deb` never touches the running
# system at all: it stages into debian/tmp.
#
# Nothing here names a component version. The versions are the submodule pins;
# which components exist and in what order is `components.conf`.

PREFIX    ?= /usr/local
DESTDIR   ?=
BUILD_DIR ?= build
STAGE     ?= $(BUILD_DIR)/destdir
JOBS      ?=
DRIVER    ?= scripts/build.sh
# Left empty on purpose: gen-changelog.sh derives the version from the checked
# out tag. Set it to override, e.g. `make VERSION=0.0.1 deb`.
VERSION   ?=

ARGS := --prefix "$(PREFIX)" --destdir "$(STAGE)" --build-root "$(BUILD_DIR)"
ifneq ($(strip $(JOBS)),)
ARGS += --jobs $(JOBS)
endif

.PHONY: all install deb clean distclean list

all:
	$(DRIVER) $(ARGS)

install: all
	install -d "$(DESTDIR)$(PREFIX)"
	cp -a "$(STAGE)$(PREFIX)/." "$(DESTDIR)$(PREFIX)/"

deb:
	VERSION="$(VERSION)" scripts/gen-changelog.sh > debian/changelog
	dpkg-buildpackage -b -us -uc
	mkdir -p "$(BUILD_DIR)/deb"
	mv ../agora_*.deb ../agora_*.buildinfo ../agora_*.changes "$(BUILD_DIR)/deb/" 2>/dev/null || true
	@echo "build: packages in $(BUILD_DIR)/deb"

clean:
	$(DRIVER) --build-root "$(BUILD_DIR)" --clean

distclean:
	rm -rf "$(BUILD_DIR)" "$(STAGE)"
	rm -rf debian/tmp debian/agora debian/agora-dev debian/agora-dbgsym \
	       debian/files debian/.debhelper debian/*.substvars \
	       debian/changelog debian/agora-files debian/agora-links \
	       debian/agora.install debian/agora-dev.install

list:
	$(DRIVER) --dry-run $(ARGS)
