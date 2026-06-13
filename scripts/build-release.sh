#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN_DIR="$ROOT/Plugins/LocalArtistRadio"
VERSION=$("$ROOT/scripts/plugin-version.sh")
DIST="$ROOT/dist"
ARCHIVE="$DIST/LocalArtistRadio-$VERSION.zip"

mkdir -p "$DIST"

(
	cd "$ROOT/Plugins"
	find LocalArtistRadio -type f -print | sort | zip -q -9 -X "$ARCHIVE" -@
)

printf '%s\n' "$ARCHIVE"
