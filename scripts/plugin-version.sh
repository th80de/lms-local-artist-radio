#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_XML="$ROOT/Plugins/LocalArtistRadio/install.xml"

sed -n 's:.*<version>\(.*\)</version>.*:\1:p' "$INSTALL_XML"

