#!/bin/sh
#
# install-layout.sh — create the Mac OS X directory set a complete Agora installation carries.
#
#   scripts/install-layout.sh [options]
#
#   --destdir DIR   create the SYSTEM half under DIR (default: /), the root an install stages into
#   --user          create the current user's HOME half instead of the system half
#   --home DIR      the home directory for --user (default: $HOME)
#   --list          print the paths the selected half creates, one per line, and create nothing
#   --dry-run       print what would be created, and create nothing
#
# **WHY THESE DIRECTORIES EXIST AT ALL.** Agora implements the Cocoa surface, and that surface NAMES
# its directories rather than searching for them: Launch Services scans `/Applications`,
# `CFKnownLocations` writes `/Library/Preferences`, `CGFont` reads `/Library/Fonts`, `NSTemporaryDirectory()`
# answers `/System/Temporary Files/`, and a home has `~/Library`, `~/Applications` and `~/Desktop`. A
# machine missing them is not a complete installation: the autosave probe measured exactly that failure
# (`NSTemporaryDirectory()` named a directory nothing created, so every write failed), and an installed
# application bundle outside `/Applications` is invisible to a double-click. The rule and the table are
# README, "The installation"; this script is their executable form, and Foundation's
# `NSSearchPathForDirectoriesInDomains()` is the same table for a program.
#
# THE TWO HALVES ARE SEPARATE BECAUSE THEY ARE OWNED SEPARATELY. The SYSTEM half belongs to the image the
# installer writes (`--destdir`, so a staged install needs no root). The HOME half belongs to the account
# and is created at login — the session script does it for a developer's account — so `--user` is here for
# an installer that wants to prepare an existing account, not for the package. Account creation, when
# Agora has one, copies the same list.
#
# Only directories are created. No file is installed here, so a directory list that drifts from the code
# cannot make an install look complete when it is not: the components install their own payload.
set -eu

self=$0
root=$(CDPATH= cd -- "$(dirname -- "$self")/.." && pwd)

destdir=/
home=
user=false
list=false
dry_run=false

while [ $# -gt 0 ]; do
	case $1 in
		--destdir) destdir=$2; shift 2 ;;
		--user)    user=true; shift ;;
		--home)    home=$2; shift 2 ;;
		--list)    list=true; shift ;;
		--dry-run) dry_run=true; shift ;;
		-h|--help) sed -n '2,26p' "$self" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "install-layout: unknown option: $1 (try --help)" >&2; exit 2 ;;
	esac
done

[ -n "$destdir" ] || destdir=/
destdir=${destdir%/}

# ---------------------------------------------------------------- the layout --
# Every path below is named by the stack; the comment says which code names it. Keep this list and
# README's table in step — a directory here that nothing names is a directory nothing maintains.
system_paths() {
	cat <<'EOF'
# The root of a Mac-shaped file-system hierarchy.
Applications
Applications/Utilities
Library
Library/Application Support
Library/Caches
Library/Colors
Library/Documentation
Library/Fonts
Library/Input Methods
Library/PreferencePanes
Library/Preferences
Library/Printers
Library/Printers/PPDs
Shared
Shared/Configuration
System
System/Configuration
System/Library
System/Library/Application Support
System/Library/Caches
System/Library/CoreServices
System/Library/Documentation
System/Library/Fonts
System/Library/Input Methods
System/Library/PreferencePanes
System/Library/Printers
System/Library/Printers/PPDs
System/Temporary Files
Users
Volumes
EOF
}

user_paths() {
	cat <<'EOF'
Applications
Desktop
Documents
Downloads
Library
Library/Application Scripts
Library/Application Support
Library/Autosave
Library/Caches
Library/Colors
Library/Documentation
Library/Fonts
Library/Input Methods
Library/PreferencePanes
Library/Preferences
Library/Printers
Library/Printers/PPDs
Movies
Music
Pictures
Public
.Trash
EOF
}

if $user; then
	[ -n "$home" ] || home=${HOME:-}
	[ -n "$home" ] || { echo "install-layout: --user needs \$HOME or --home DIR" >&2; exit 2; }
	base=${home%/}
else
	base=$destdir
fi

paths=$(if $user; then user_paths; else system_paths; fi | grep -v '^#' | grep -v '^$')

if $list; then
	printf '%s\n' "$paths"
	exit 0
fi

# THE LIST IS READ FROM A FILE, NOT ITERATED AS WORDS: a path with a space in it
# (`Library/Application Support`) is one path, and a `for` loop would split it in two.
list_file=$(mktemp "${TMPDIR:-/tmp}/agora-layout.XXXXXX") || exit 1
trap 'rm -f "$list_file"' EXIT INT TERM
printf '%s\n' "$paths" > "$list_file"

created=0
while IFS= read -r path; do
	target=$base/$path
	if [ -d "$target" ]; then
		continue
	fi
	if $dry_run; then
		echo "install-layout: would create $target"
	else
		mkdir -p "$target" || {
			echo "install-layout: cannot create $target" >&2
			exit 1
		}
	fi
	created=$((created + 1))
done < "$list_file"

shown=$base
[ -n "$shown" ] || shown=/
echo "install-layout: $shown — $created director$( [ "$created" = 1 ] && echo y || echo ies ) created"
