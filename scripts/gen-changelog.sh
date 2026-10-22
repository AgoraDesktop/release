#!/bin/sh
#
# gen-changelog.sh — write a Debian changelog for whatever version is checked out.
#
# The version comes from git, so `make deb` names the package after the release
# tag it was built from and no one has to bump a version by hand. A tag `v1.3`
# becomes `1.3-1`; `v1.3-4-gabc123` keeps its describe suffix as the Debian
# revision.

set -eu

version=${VERSION:-}
if [ -z "$version" ]; then
	# An exact tag names the release; otherwise a describe suffix carries the
	# distance and the commit; with no tags at all, name the build after the
	# commit and sort it below every tagged release. A bare commit id must
	# never be mistaken for a version number, which is why it is prefixed
	# rather than tested for a leading digit.
	if v=$(git describe --tags --exact-match 2>/dev/null); then
		version=$v
	elif d=$(git describe --tags 2>/dev/null); then
		version=$d
	else
		version="0.0.0~$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
	fi
fi
version=${version#v}
case $version in
	*-*) ;;
	*)   version=$version-1 ;;
esac

date=$(date -R 2>/dev/null || date)
commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

cat <<EOF
agora ($version) unstable; urgency=medium

  * Release build from Agora $commit.

 -- Kyle J Cardoza <Kyle.Cardoza@icloud.com>  $date
EOF
