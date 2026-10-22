#!/bin/sh
# Converts the JSON manifest into the folder that Debian Installer reads with BusyBox's shell tools: a folder for each section and feature, with a file for each of its keys.
# A text is written on one line, a list one item per line, and a key left empty gets no file.
#   sh adapter-debian-installer.sh manifest.json /usr/share/debian-livecd-installer /var/lib/debian-livecd-installer/manifest
# The overlays' folders are copied in first, so that each feature's `deselect` script is in its folder, where the installer runs it by the name in the feature's `deselect` file.
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
	for key in label description default warn requires requiresWarn requiresError packages exclude import deselect; do
		text=$(value "$id" "$key")
		[ -z "$text" ] || printf '%s\n' "$text" > "$OUT/$id/$key"
	done
	# debconf separates choices with commas, and reads a backslash as an escape
	sed -i 's/[,\\]//g' "$OUT/$id/label"
done
