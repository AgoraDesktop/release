# Agora — release

*The composition of a whole Agora desktop: a floating `main` that follows every component, and tags
that freeze one combination.*

**Status: tracking.** `main` follows the `main` branch of each of the fourteen components — the Cocoa
stack, its supporting libraries, the window server, the Workspace shell, and a demonstration
application. No release tag exists yet.

## What this repository is

Agora is a federation of small repositories, one per component. This is the **release** repository: it
owns no component of its own and writes none of their code. It does two things — it follows *which*
revision of each component is current, and it records *which* revision of each component a shipped
desktop was built from.

The development workspace (`AgoraDesktop/Agora`) follows the same components at the same tips; it is
the surrounding checkout, not the thing that gets released. This repository is where a release is
*named*.

## `main` floats

`main` tracks the components. Every entry in `.gitmodules` carries `branch = main`, so

```
git submodule update --remote
```

moves each submodule to the tip of its component's `main`. Committing those moves advances a rolling
snapshot: `main` is the freshest combination that exists, and it is never a release.

## Tags pin

A release is a **tag** on this repository. A tagged commit records one exact revision of every
component — the commit named by that component's own release tag. The tag is the pin; `main` is not.

The pin set is authored as a **manifest**, one file per release under `releases/`:

```
# component          ref
libagora-core        v0.9.0
libagora-drawing     v1.24
window-server        v0.4.2
```

A ref is any ref resolvable in that component — a tag, a commit, a branch. It is resolved to a commit
when the release is cut, and the commit is what the tag records.

To cut a release:

```
scripts/cut-release.sh --seed 1.3     # start releases/1.3.txt from what main holds
$EDITOR releases/1.3.txt              # set each component's ref
scripts/cut-release.sh --dry-run 1.3  # resolve and report; write nothing
scripts/cut-release.sh 1.3            # build the commit and tag it
git push origin 1.3                   # publish the tag
```

The script writes a commit whose tree records every component's resolved commit as a gitlink, with the
branch-tracking keys removed from `.gitmodules` and the manifest committed beside them at
`releases/<version>.txt`. `main` is not touched: a release hangs off it, reached only by its tag. That
is what makes a tagged release hermetic — `git submodule update --remote` against it has no branch to
follow.

## Building a desktop

Two front ends over one driver. `scripts/build.sh` builds every component this release pins, in
`components.conf` order, into a staged prefix; `make` and `dh` are only front ends for it.

### From source: `make`

```
make                 # build every component into build/destdir
make install         # copy the staged image to $(DESTDIR)/
make install PREFIX=/usr/local DESTDIR=
make clean           # remove the per-component build trees
```

The build is DESTDIR-based: `make` needs no root, and `make install` writes only under `$(DESTDIR)`.

**The stage is the image root, not just the prefix.** Components install under `$(PREFIX)`, and one
thing does not: the installation's directory set. A complete installation carries the Mac OS X
directories the stack names — `/Applications`, `/Library`, `/System`, `/Users`, `/Volumes`, and the
home-side set — because the Cocoa surface names those paths rather than searching for them
(workspace `README.md`, "The installation"). `scripts/install-layout.sh` creates them beside the prefix
in the same DESTDIR, and `make install` copies the whole stage, so `make install` produces a complete
installation rather than a prefix with a Mac-shaped name.

### Debian packages: `make deb`

```
make deb             # dpkg-buildpackage; the .deb files land in build/deb/
```

The package version comes from `git describe`, so a release tag names its package without anyone bumping
a version by hand. `debian/rules` stages the same driver's output into `debian/tmp` and splits it into
`agora` (runtime) and `agora-dev` (headers, CMake configs, pkg-config) by inspecting what was actually
installed, so the split cannot go stale. The installation's directories are empty, so they are not a file
list at all: `override_dh_installdirs` asks `scripts/install-layout.sh --list` for them and hands the answer
to `dh_installdirs`, which is the one mechanism that puts an empty directory in a package.

### How it stays version-agnostic

The driver names no component version. It uses the one interface every component already offers —
`cmake` configure, build, install — with `-DCMAKE_PREFIX_PATH` pointing at the staged prefix, so each
component finds its dependencies there in build order. Which components exist, and in what order, is
`components.conf`, which is data; the versions are the submodule pins.

### What is not built yet

- `widget-zoo` is an empty repository, so `components.conf` marks it `--skip`.
- `window-server`'s backends are explicit now — `AWS_WITH_DRM` / `AWS_WITH_X11` / `AWS_WITH_LIBINPUT`,
  set on the `window-server` line of `components.conf` — so the feature set follows the release rather
  than the build host. libinput is **ON by decision**: its device-input path needs `libudev` and `logind`,
  which the workspace `README.md`'s "No systemd" rule excludes, and real device input was judged to
  outrank the rule. The release therefore build-depends on `libudev-dev` and ships a compositor linked
  against libudev and logind — a deliberate, recorded deviation, not an oversight.
- `libagora-app`'s test suite is added unconditionally (`enable_testing()` does not consult
  `BUILD_TESTING`), and one test — `tests/text_hyphenation.m` — links
  `CFStringIsHyphenationAvailableForLocale`, which `libagora-core` does not define in a committed tree.
  A full `make` therefore stops at that link until the hyphenation code lands in Core Foundation, or
  the suite is gated on `BUILD_TESTING`. The library itself builds and installs.

## The components

### The Cocoa stack

| component | what it is |
|---|---|
| `libagora-core` | Core Foundation — the C core: strings, collections, run loops |
| `libagora-text` | Core Text — text layout and fonts |
| `libagora-drawing` | Core Graphics — the 2D drawing and geometry model |
| `libagora-base` | Foundation — Objective-C collections, strings, dates, files, notifications |
| `libagora-app` | Application Kit (AppKit) — windows, views, controls, the menu model |

### Supporting libraries

| component | what it is |
|---|---|
| `libagora-objc` | the Objective-C runtime (GNUstep libobjc2) |
| `libagora-dispatch` | libdispatch — Grand Central Dispatch and the blocks runtime |
| `libagora-lcms2` | little CMS — the colour-management engine Core Graphics uses |

### The desktop

| component | what it is |
|---|---|
| `window-server` | the Wayland compositor: outputs, seats, input routing, surface roles, layers |
| `widget-zoo` | a demonstration application: the view and control classes and the menu system |

## Working here

- `main` is a snapshot, not a release. Move a component forward on `main` freely; a release happens
  only when a tag is cut.
- A component's own `README` describes the component. This document describes only the composition.
