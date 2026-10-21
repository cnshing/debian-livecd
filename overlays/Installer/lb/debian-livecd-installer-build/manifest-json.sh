#!/bin/sh
# Generates the manifest, one JSON document, from the overlays' YAML files.
#   sh manifest-json.sh /usr/share/debian-livecd-installer > manifest.json

set -eu
SCHEMA=$(dirname "$0")/schema.yaml
NL='
'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for kind in section feature; do
	yq ".$kind" "$SCHEMA" > "$tmp/$kind.json"
done

# Each file as one JSON object per line: its id, then every key, with a text's lines joined into one. yq -s gives the
# file's documents as a list, so that an empty file is null and fails.
: > "$tmp/objects"
for file in "$1"/*/section.yaml "$1"/*/*/feature.yaml; do
	[ -f "$file" ] || continue
	case $file in */section.yaml) kind=section ;; *) kind=feature ;; esac
	id=${file#"$1"/}
	yq -s '.[0]' "$file" > "$tmp/file.json"
	# The jsonschema CLI warns that it is deprecated for check-jsonschema, which trixie does not package
	PYTHONWARNINGS=ignore jsonschema -i "$tmp/file.json" -F "$file: {error.json_path}: {error.message}$NL" \
		"$tmp/$kind.json"
	jq -c --arg id "${id%/*}" --slurpfile schema "$tmp/$kind.json" '
		{ id: $id } + ($schema[0].properties | map_values(.default)) + .
		| map_values(if type == "string" then gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ") end)' \
		"$tmp/file.json" >> "$tmp/objects"
done
jq -s '. as $all | { sections: [$all[] | select(.id | contains("/") | not) | .id as $section
	| . + { features: [$all[] | select(.id | startswith($section + "/"))] }] }' "$tmp/objects"
