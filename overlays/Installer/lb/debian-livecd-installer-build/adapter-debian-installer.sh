#!/bin/sh
# Converts the manifest into a simple file for Debian Installer in a  BusyBox environment can read
# Each section and feature, with each key in a file of its own, a text on one line, and a list one item per line.
#   sh adapter-debian-installer.sh manifest.json /usr/share/debian-livecd-installer /var/lib/debian-livecd-installer/manifest
# A key left empty has no file. A feature's `deselect` script becomes its file `deselect`, next to everything else of
# the overlays' folders, such as what the scripts source.
set -eu
JSON=$1 SOURCE=$2 OUT=$3

# A key ($2) of a section or feature ($1), as lines: a list's items, a text, `false` for a default of false, and
# nothing for a key left empty
value() {
	jq -r --arg id "$1" --arg key "$2" '.sections[] | (., .features[]) | select(.id == $id) | .[$key]
		| if . == null or . == "" or . == true then empty elif type == "array" then .[] else tostring end' "$JSON"
}

rm -rf "$OUT"
mkdir -p "$OUT"
cp -a "$SOURCE/." "$OUT/"
find "$OUT" -name '*.yaml' -delete

for id in $(jq -r '.sections[] | .id, .features[].id' "$JSON"); do
	for key in label description default warn requires requiresWarn requiresError packages exclude import; do
		text=$(value "$id" "$key")
		[ -z "$text" ] || printf '%s\n' "$text" > "$OUT/$id/$key"
	done
	# debconf separates choices with commas, and reads a backslash as an escape
	sed -i 's/[,\\]//g' "$OUT/$id/label"
	script=$(value "$id" deselect)
	[ -z "$script" ] || mv "$OUT/$id/$script" "$OUT/$id/deselect"
done
