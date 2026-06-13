#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$("$ROOT/scripts/plugin-version.sh")
REPOSITORY=${1:-${GITHUB_REPOSITORY:-}}
TAG=${RELEASE_TAG:-v$VERSION}
DIST="$ROOT/dist"
ARCHIVE="$DIST/LocalArtistRadio-$VERSION.zip"
OUTPUT="$DIST/extensions.xml"

if [ -z "$REPOSITORY" ]; then
	printf '%s\n' 'Usage: build-repository.sh OWNER/REPOSITORY' >&2
	exit 2
fi

case "$REPOSITORY" in
	*/*) ;;
	*)
		printf '%s\n' 'Repository must use OWNER/REPOSITORY format' >&2
		exit 2
		;;
esac

if [ ! -f "$ARCHIVE" ]; then
	"$ROOT/scripts/build-release.sh" >/dev/null
fi

SHA=$(shasum "$ARCHIVE" | awk '{print $1}')
URL="https://github.com/$REPOSITORY/releases/download/$TAG/LocalArtistRadio-$VERSION.zip"

mkdir -p "$DIST"

cat > "$OUTPUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<extensions>
  <details>
    <title lang="EN">Local Artist Radio</title>
    <title lang="DE">Lokales Interpreten-Radio</title>
  </details>
  <plugins>
    <plugin name="LocalArtistRadio" version="$VERSION" minTarget="9.0" maxTarget="*">
      <title lang="EN">Local Artist Radio</title>
      <title lang="DE">Lokales Interpreten-Radio</title>
      <desc lang="EN">Creates a continuous artist radio using Last.fm similarity data and local music files only.</desc>
      <desc lang="DE">Erstellt ein kontinuierliches Interpreten-Radio mit Last.fm-Ähnlichkeitsdaten und ausschließlich lokalen Musikdateien.</desc>
      <changes lang="EN">See the GitHub release notes for changes.</changes>
      <changes lang="DE">Änderungen stehen in den GitHub Release Notes.</changes>
      <creator>Thomas Hoppe</creator>
      <category>playlists</category>
      <link>https://github.com/$REPOSITORY</link>
      <url>$URL</url>
      <sha>$SHA</sha>
    </plugin>
  </plugins>
</extensions>
EOF

printf '%s\n' "$OUTPUT"

