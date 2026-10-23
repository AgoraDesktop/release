#!/bin/sh
#
# build.sh — build every component this release pins, in order, into a prefix.
#
#   scripts/build.sh [options]
#
#   --prefix DIR       install prefix recorded in the build (default /usr/local)
#   --destdir DIR      staging root; files land under DIR/PREFIX
#                      (default: <build-root>/destdir)
#   --build-root DIR   per-component build trees (default: build)
#   --libdir DIR       CMAKE_INSTALL_LIBDIR (default: CMake's choice, `lib`)
#   --components FILE  ordered component list (default: components.conf)
#   --only NAME        build only NAME (repeatable, space-separated)
#   --from NAME        start at NAME in the ordered list
#   --jobs N           parallel build jobs (default: every CPU)
#   --c-compiler CC    default: clang-19, else clang, else cc
#   --cxx-compiler CXX default: clang++-19, else clang++, else c++
#   --objc-compiler CC default: the C compiler
#   --build-type TYPE  CMAKE_BUILD_TYPE (default Release)
#   --no-install       build but do not install
#   --dry-run          print what would run, and run nothing
#   --clean            remove the build trees
#   --distclean        remove the build trees and the staged prefix
#
# A component is whatever `components.conf` names: a submodule directory that is
# a CMake project. The driver uses only the interface every component already
# offers — configure, build, install — so it builds whichever revisions the
# release pins, without knowing what versions they are. The order in
# `components.conf` is the dependency order; it is data, not code, so a release
# pinning different revisions can carry a different order.
#
# This is a DESTDIR build: `--prefix` is where the desktop is meant to live and
# `--destdir` is where a build stages it. `make install` copies the staged tree
# into place; `debian/rules` stages into `debian/tmp`. Nothing here needs root.

set -eu

die() { echo "build: $*" >&2; exit 1; }

self=$0
root=$(CDPATH= cd -- "$(dirname -- "$self")/.." && pwd)
cd "$root"

PREFIX=/usr/local
stage_root=
build_root=build
libdir=
components_file=components.conf
only=
from=
jobs=
cc=
cxx=
objc=
build_type=Release
do_install=true
dry_run=false
action=build

while [ $# -gt 0 ]; do
	case $1 in
		--prefix)     PREFIX=$2; shift 2 ;;
		--destdir)    stage_root=$2; shift 2 ;;
		--build-root) build_root=$2; shift 2 ;;
		--libdir)     libdir=$2; shift 2 ;;
		--components) components_file=$2; shift 2 ;;
		--only)       only="$only $2"; shift 2 ;;
		--from)       from=$2; shift 2 ;;
		--jobs)       jobs=$2; shift 2 ;;
		--c-compiler)   cc=$2; shift 2 ;;
		--cxx-compiler) cxx=$2; shift 2 ;;
		--objc-compiler) objc=$2; shift 2 ;;
		--build-type) build_type=$2; shift 2 ;;
		--no-install) do_install=false; shift ;;
		--dry-run)    dry_run=true; shift ;;
		--clean)      action=clean; shift ;;
		--distclean)  action=distclean; shift ;;
		-h|--help)    sed -n '2,38p' "$self" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) die "unknown option: $1 (try --help)" ;;
	esac
done

PREFIX=${PREFIX%/}
[ -n "$PREFIX" ] || PREFIX=/
[ -n "$stage_root" ] || stage_root=$build_root/destdir

# Absolute paths, because CMake wants CMAKE_PREFIX_PATH absolute.
abs() { case $1 in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$root" "$1" ;; esac; }
stage_root=$(abs "$stage_root")
stage=$stage_root$PREFIX

case $action in
	clean)
		rm -rf "$build_root"
		echo "build: removed $build_root"
		exit 0 ;;
	distclean)
		rm -rf "$build_root" "$stage_root"
		echo "build: removed $build_root and $stage_root"
		exit 0 ;;
esac

# ----------------------------------------------------------------- toolchain --
# CMake wants an absolute compiler path for languages beyond C/C++ (it rejects a
# bare name for OBJC), so resolve everything to the path `command -v` reports.
first_of() { for c in "$@"; do p=$(command -v "$c" 2>/dev/null) && { printf '%s' "$p"; return 0; }; done; return 1; }
resolve()  { case $1 in */*) printf '%s' "$1" ;; *) command -v "$1" 2>/dev/null || printf '%s' "$1" ;; esac; }
[ -n "$cc" ]   || cc=$(first_of clang-19 clang cc || true)
[ -n "$cxx" ]  || cxx=$(first_of clang++-19 clang++ c++ || true)
[ -n "$objc" ] || objc=$cc
[ -n "$cc" ]  || die "no C compiler found (tried clang-19, clang, cc)"
[ -n "$cxx" ] || die "no C++ compiler found (tried clang++-19, clang++, c++)"
cc=$(resolve "$cc"); cxx=$(resolve "$cxx"); objc=$(resolve "$objc")
[ -n "$jobs" ] || jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)

# ------------------------------------------------------------- component list --
[ -f "$components_file" ] || die "no component list: $components_file"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$components_file" > "$tmp/all"

# The list must name every submodule exactly once: a component that exists but
# is not in the list would be silently left out of the desktop.
if [ -f .gitmodules ]; then
	git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | sort > "$tmp/submodules"
	awk '{print $1}' "$tmp/all" | sort > "$tmp/listed"
	if ! cmp -s "$tmp/submodules" "$tmp/listed"; then
		echo "build: components.conf and .gitmodules disagree" >&2
		echo "--- .gitmodules" >&2;      cat "$tmp/submodules" >&2
		echo "--- components.conf" >&2;  cat "$tmp/listed" >&2
		exit 1
	fi
fi

if [ -n "$only" ]; then
	awk -v want="$only" 'BEGIN{n=split(want,a," "); for(i=1;i<=n;i++) if(a[i]!="") w[a[i]]=1}
		$1 in w { print; seen[$1]=1 }
		END { for(k in w) if(!(k in seen)) exit 3 }' "$tmp/all" > "$tmp/filtered" \
		|| die "--only names a component that is not in $components_file"
else
	cp "$tmp/all" "$tmp/filtered"
fi

if [ -n "$from" ]; then
	awk -v from="$from" '$1==from { on=1 } on { print }' "$tmp/filtered" > "$tmp/from" || true
	[ -s "$tmp/from" ] || die "--from: no component named '$from'"
	mv "$tmp/from" "$tmp/filtered"
fi

list=$tmp/filtered

# --------------------------------------------------------------------- build --
echo "build: prefix=$PREFIX destdir=$stage_root libdir=${libdir:-<default>}"
echo "build: cc=$cc cxx=$cxx objc=$objc jobs=$jobs type=$build_type"
$dry_run || mkdir -p "$build_root" "$stage"

while read -r name rest; do
	skip=false
	extra=
	for token in $rest; do
		case $token in --skip) skip=true ;; *) extra="$extra $token" ;; esac
	done

	if $skip; then echo "build: $name — skip (not built yet)"; continue; fi

	src=$root/$name
	bld=$build_root/$name
	if [ ! -f "$src/CMakeLists.txt" ]; then
		echo "build: $name — skip (no CMakeLists.txt)"
		continue
	fi

	echo "build: $name — configure"
	set -- cmake -S "$src" -B "$bld" \
		-DCMAKE_BUILD_TYPE="$build_type" \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		-DCMAKE_PREFIX_PATH="$stage" \
		-DCMAKE_C_COMPILER="$cc" \
		-DCMAKE_CXX_COMPILER="$cxx" \
		-DCMAKE_OBJC_COMPILER="$objc" \
		-DBUILD_TESTING=OFF
	[ -n "$libdir" ] && set -- "$@" -DCMAKE_INSTALL_LIBDIR="$libdir"
	for token in $extra; do set -- "$@" "$token"; done
	if $dry_run; then printf '  + %s\n' "$*"; else "$@"; fi

	echo "build: $name — build"
	if $dry_run; then
		printf '  + cmake --build %s --parallel %s\n' "$bld" "$jobs"
	else
		cmake --build "$bld" --parallel "$jobs"
	fi

	if $do_install; then
		echo "build: $name — install -> $stage"
		if $dry_run; then
			printf '  + env DESTDIR=%s cmake --install %s\n' "$stage_root" "$bld"
		else
			DESTDIR="$stage_root" cmake --install "$bld"
		fi
	fi
done < "$list"

# THE INSTALLATION'S DIRECTORY SET, ONCE, AT THE ROOT OF WHAT WAS STAGED. A complete installation carries
# the Mac OS X directories the stack names (README, "The installation"), and they live at the image root
# rather than under the prefix, so they are created beside `$PREFIX` in the same DESTDIR: `make install`
# copies the whole stage, and `debian/rules` lets debhelper create the empty ones in the package.
if $do_install; then
	echo "build: the installation's directory set"
	if $dry_run; then
		printf '  + %s/scripts/install-layout.sh --destdir %s\n' "$root" "$stage_root"
	else
		"$root/scripts/install-layout.sh" --destdir "$stage_root"
	fi
fi

echo "build: done"
