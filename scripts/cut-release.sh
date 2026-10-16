#!/bin/sh
#
# cut-release.sh — turn a pinned-version manifest into a release commit and tag.
#
#   scripts/cut-release.sh [--dry-run] <version> [manifest]
#   scripts/cut-release.sh --seed <version>
#
# A release is a tag on this repository whose commit records, for every
# component in .gitmodules, exactly one commit as a gitlink. This script
# builds that commit and applies the tag. It never touches `main`, and it
# never pushes.
#
# The pin set comes from a manifest — releases/<version>.txt by default:
#
#     # component          ref
#     libagora-core        v0.9.0
#     libagora-drawing     v1.24
#     window-server        v0.4.2
#
# A ref is anything resolvable inside that component: a tag, a commit, a
# branch. It is resolved to a commit once, here, and the commit is what the
# release records. The gitlink is the pin; the ref is only the instruction.
#
# --seed writes a starting manifest from the commits `main` currently holds.
# --dry-run resolves and reports without writing a commit or a tag.

set -eu

die() { echo "cut-release: $*" >&2; exit 1; }

BASE=${BASE:-main}
dry_run=false
seed=false
while [ $# -gt 0 ]; do
	case $1 in
		-n|--dry-run) dry_run=true; shift ;;
		--seed)       seed=true; shift ;;
		--)           shift; break ;;
		-*)           die "unknown option: $1" ;;
		*)            break ;;
	esac
done
[ $# -ge 1 ] || die "usage: $0 [--dry-run] <version> [manifest]"

version=$1; shift

cd "$(git rev-parse --show-toplevel)"
[ -f .gitmodules ] || die "no .gitmodules in $(pwd)"

git check-ref-format "refs/tags/$version" >/dev/null 2>&1 \
	|| die "'$version' is not a valid tag name"

components=$(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' \
	| awk '{print $2}' | sort)
[ -n "$components" ] || die "no submodules in .gitmodules"

# ------------------------------------------------------------------ --seed --
if $seed; then
	[ $# -eq 0 ] || die "--seed takes only a version"
	out="releases/$version.txt"
	[ -e "$out" ] && die "$out already exists"
	mkdir -p releases
	{
		echo "# Agora $version — the version of each component this release carries."
		echo "# Edit each ref, then run:  scripts/cut-release.sh $version"
		echo "#"
		for path in $components; do
			sha=$(git ls-tree "$BASE" -- "$path" | awk '{print $3}')
			printf '%-24s %s\n' "$path" "${sha:-?}"
		done
	} > "$out"
	echo "wrote $out"
	exit 0
fi

manifest=${1:-releases/$version.txt}
[ -f "$manifest" ] || die "no manifest: $manifest"
git rev-parse -q --verify "refs/tags/$version" >/dev/null && die "tag $version already exists"

# ------------------------------------------------------------- read the pins --
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$manifest" | awk '{print $1, $2}' > "$tmp/pins"
[ -s "$tmp/pins" ] || die "manifest is empty: $manifest"

printf '%s\n' $components                                > "$tmp/components"
awk '{print $1}' "$tmp/pins" | sort                      > "$tmp/listed"
if ! cmp -s "$tmp/components" "$tmp/listed"; then
	echo "cut-release: the manifest must list every component exactly once" >&2
	echo "--- .gitmodules" >&2; cat "$tmp/components" >&2
	echo "--- manifest" >&2;    cat "$tmp/listed"     >&2
	exit 1
fi

# ------------------------------------------------------- resolve refs to commits --
: > "$tmp/resolved"
while read -r path ref; do
	[ -e "$path/.git" ] || git submodule update --init --quiet -- "$path"
	sha=$(git -C "$path" rev-parse --verify --quiet "$ref^{commit}" 2>/dev/null || true)
	if [ -z "$sha" ]; then
		git -C "$path" fetch --quiet --tags origin >/dev/null 2>&1 || true
		sha=$(git -C "$path" rev-parse --verify --quiet "$ref^{commit}" 2>/dev/null || true)
	fi
	[ -n "$sha" ] || die "$path: cannot resolve '$ref'"
	printf '%s %s\n' "$path" "$sha" >> "$tmp/resolved"
done < "$tmp/pins"

echo "Agora $version"
while read -r path sha; do
	short=$(git -C "$path" rev-parse --short=12 "$sha")
	tag=$(git -C "$path" describe --tags --exact-match "$sha" 2>/dev/null || true)
	printf '  %-24s %s%s\n' "$path" "$short" "${tag:+  ($tag)}"
	reachable=$(git -C "$path" for-each-ref --contains="$sha" --count=1 \
		refs/remotes refs/tags 2>/dev/null | wc -l)
	[ "$reachable" -gt 0 ] \
		|| echo "  warning: $path $short is not reachable from any remote or tag" >&2
done < "$tmp/resolved"

if $dry_run; then
	echo
	echo "(dry run — no commit or tag written)"
	exit 0
fi

# ------------------------------------------------------------- build the commit --
export GIT_INDEX_FILE="$tmp/index"
git read-tree "$BASE"
while read -r path sha; do
	git update-index --cacheinfo "160000,$sha,$path"
done < "$tmp/resolved"

# A release tracks no branch: drop the branch keys from the tagged .gitmodules,
# so a later `git submodule update --remote` against the tag cannot move the pins.
git show :.gitmodules \
	| grep -v -e '^[[:space:]]*branch[[:space:]]*=' \
	| git hash-object -w --stdin > "$tmp/gitmodules"
git update-index --cacheinfo "100644,$(cat "$tmp/gitmodules"),.gitmodules"

# The manifest itself is committed beside the gitlinks, as the release's record
# of intent; the gitlinks remain the pins.
blob=$(git hash-object -w "$manifest")
git update-index --add --cacheinfo "100644,$blob,releases/$version.txt"

tree=$(git write-tree)
unset GIT_INDEX_FILE

commit=$(git commit-tree "$tree" -p "$BASE" -m "Agora $version")
git tag -a "$version" -m "Agora $version" "$commit"

echo
echo "tagged $version -> $commit"
echo "  inspect:  git ls-tree $version"
echo "  push:     git push origin $version"
