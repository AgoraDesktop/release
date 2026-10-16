# Agora — release

*The composition of a whole Agora desktop at one exact revision of every component.*

**Status: manifest.** This repository pins the first thirteen components of the Agora desktop — the
Cocoa stack, its supporting libraries, the window server, and a demonstration application — at exact
revisions. The build that turns those pins into a desktop and an installable image is not written yet.

## What this repository is

Agora is a federation of small repositories, one per component. This is the **release** repository: it
owns no component of its own and writes none of their code. It does one thing — it records *which*
revision of *which* component makes up a desktop, and (in time) builds exactly that combination.

It is deliberately not the same kind of thing as the development workspace above it. The workspace
(`AgoraDesktop/Agora`) checks the components out at the tip of `main`, so that work can move; this
repository pins them, so that a build can be reproduced. Anything that floats is a workspace; anything
that ships is a release.

## The pins

Each component is a Git submodule of this repository, recorded at one commit and with no `branch` key
in `.gitmodules` — so `git submodule update --remote` has nothing to float to. The pin *is* the commit.

### The Cocoa stack

| component | what it is | pinned at |
|---|---|---|
| `libagora-core` | Core Foundation — the C core: strings, collections, run loops | `049719c6e70e` |
| `libagora-text` | Core Text — text layout and fonts | `ab82ca941d3c` |
| `libagora-drawing` | Core Graphics — the 2D drawing and geometry model | `06b32839b115` |
| `libagora-base` | Foundation — Objective-C collections, strings, dates, files, notifications | `d1277c14bc49` |
| `libagora-app` | Application Kit (AppKit) — windows, views, controls, the menu model | `04dda7ba544c` |

### Supporting libraries

| component | what it is | pinned at |
|---|---|---|
| `libagora-objc` | the Objective-C runtime (GNUstep libobjc2) | `2f51fdd01d2a` |
| `libagora-dispatch` | libdispatch — Grand Central Dispatch and the blocks runtime | `eab8828bcb80` |
| `libagora-lcms2` | little CMS — the colour-management engine Core Graphics uses | `24dc534207c4` |

### The desktop

| component | what it is | pinned at |
|---|---|---|
| `window-server` | the Wayland compositor: outputs, seats, input routing, surface roles, layers | `2b27b0412d63` |
| `widget-zoo` | a demonstration application: the view and control classes and the menu system | `ef29bb4d4a0a` |

## Building a desktop

Not yet written. When it exists it will consume the pins above — never a sibling working tree — and
produce a desktop and an installable image. Whether that is distribution packages, a bootable image, or
both is still open (see the workspace `README.md`, *Open questions*).

## Working here

- The pins are the product. Changing a pin is a release action, not a development convenience: move a
  component forward here only when that exact revision is the one the release is meant to carry.
- Keep the `branch` key out of `.gitmodules`. A component in this repository tracks a commit, not a
  branch; if a pin should float, it does not belong in a release.
- The component's own `README` describes the component. This document describes only the composition.
