# Agora — release

*The composition of a whole Agora desktop: a floating `main` that follows every component, and tags
that freeze one combination.*

**Status: tracking.** `main` follows the `main` branch of each of the thirteen components — the Cocoa
stack, its supporting libraries, the window server, and a demonstration application. No release tag
exists yet.

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

To cut one:

1. Tag each component at the revision it should ship (`v0.1.0`, or whatever the component's own scheme
   is).
2. On `main`, bring the submodules to the tagged commits: `git submodule update --remote --init`, then
   `git -C <component> checkout <component-tag>` for each.
3. Commit. A commit whose every submodule gitlink is at a component tag is the release.
4. `git tag -a vX.Y.Z -m "Agora vX.Y.Z"` and push the tag.

The gitlink is the pin; whether a tagged commit also keeps `branch = main` in `.gitmodules` changes
nothing about what the tag records. Keeping it means a run of `git submodule update --remote` against
the tag will float the pins; dropping it for the tagged commit makes the tag hermetic. Either is
workable — the tag records the commits regardless.

## Building a desktop

Not yet written. When it exists it will consume the pins of a tag — never a sibling working tree — and
produce a desktop and an installable image. Whether that is distribution packages, a bootable image,
or both is still open (see the workspace `README.md`, *Open questions*).

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
