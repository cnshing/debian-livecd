# requires.sh validates each selected choice to detect any invalid configurations.


# Printf $2 where $1 has %s, without changing  any other % or \ in $1
fill() { case $1 in *%s*) printf '%s\n' "${1%%%s*}$2${1#*%s}" ;; *) printf '%s\n' "$1" ;; esac; }

# When a choice is selected without any of the choices in its `requires`, adds its `requiresWarn` to $warnings, otherwise an error from `requiresError` to $problems. Outputs $unmet for any choices whose requirements are not selected.
requires_check() {
	unmet= sections=
	for id in $(cat "$STATE/selected"); do
		[ -f "$M/$id/requires" ] || continue
		for required in $(list "$M/$id/requires"); do
			grep -qx "$required" "$STATE/selected" && continue 2
		done
		if [ -f "$M/$id/requiresWarn" ]; then
			warnings="$warnings $(text "$id" requiresWarn)"
			continue
		fi
		unmet="$unmet $id"
	done
	# Any section's requiresError is shown all at once, listing the relevant choices of what's required
	for id in $unmet; do
		category=${id%%/*}
		if [ -f "$M/$category/requiresError" ]; then
			case " $sections " in *" $category "*) continue ;; esac
			sections="$sections $category"
			names=
			for other in $unmet; do
				[ "${other%%/*}" = "$category" ] && names="${names:+$names, }$(label "$other")"
			done
			problems="$problems $(fill "$(text "$category" requiresError)" "$names")"
		elif [ -f "$M/$id/requiresError" ]; then
			problems="$problems $(fill "$(text "$id" requiresError)" "$(label "$id")")"
		else
			problems="$problems $(label "$id") needs another choice that is not selected."
		fi
	done
}
