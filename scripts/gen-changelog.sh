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
	version=$(git describe --tags --always 2>/dev/null || echo 0.0.0)
fi
version=${version#v}
# A Debian version must start with a digit; a bare commit id does not.
case $version in
	[0-9]*) ;;
	*)      version="0.0.0~$version" ;;
esac
case $version in
	*-*) ;;
	*)   version=$version-1 ;;
esac

date=$(date -R 2>/dev/null || date)
commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

cat <<EOF
agora ($version) unstable; urgency=medium

  * Release build from Agora $commit.

 -- Agora <agora@example.invalid>  $date
EOF
