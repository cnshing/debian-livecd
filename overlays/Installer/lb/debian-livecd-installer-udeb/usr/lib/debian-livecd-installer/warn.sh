#!/bin/sh

# Collects any deselected choices' `warn`, if found, into $warnings and asks the user to confirm the choices.
warn_check() {
	for id in $(cat "$STATE/deselected"); do
		[ ! -f "$M/$id/warn" ] || warnings="$warnings $(text "$id" warn)"
	done
}
