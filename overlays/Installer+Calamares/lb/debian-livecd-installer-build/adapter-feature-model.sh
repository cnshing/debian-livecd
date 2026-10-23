#!/bin/sh
# Adapts the JSON manifest into the JavaScript that Calamares' "Select optional features" page (features.qml) 
#   sh adapter-feature-model.sh manifest.json > /etc/calamares/branding/debian/features-model.js

set -eu

echo "var sections = $(jq '[.sections[] | { id, label, description,
	choices: [.features[] | { id, label, description, warn, checked: .default, requires }] }]' "$1");"
