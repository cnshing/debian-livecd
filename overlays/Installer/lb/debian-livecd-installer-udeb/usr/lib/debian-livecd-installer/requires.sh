# requires.sh validates each selected choice to detect any invalid configurations.


# When a choice is selected without any of the choices in its `requires`, adds its `requires-warn` to $warnings, otherwise an error from `requires-error` to $problems. Outputs $unmet for any choices whose requirements are not selected.
requires_check() {
	unmet= sections=
	for id in $(cat "$STATE/selected"); do
		[ -f "$M/$id/requires" ] || continue
		for required in $(list "$M/$id/requires"); do
			grep -qx "$required" "$STATE/selected" && continue 2
		done
		if [ -f "$M/$id/requires-warn" ]; then
			warnings="$warnings $(text "$id" requires-warn)"
			continue
		fi
		unmet="$unmet $id"
	done
	# Any section's requires-error is shown all at once, listing the relevant choices of what's required
	for id in $unmet; do
		category=${id%%/*}
		if [ -f "$M/$category/requires-error" ]; then
			case " $sections " in *" $category "*) continue ;; esac
			sections="$sections $category"
			names=
			for other in $unmet; do
				[ "${other%%/*}" = "$category" ] && names="${names:+$names, }$(label "$other")"
			done
			problems="$problems $(printf "$(text "$category" requires-error)" "$names")"
		elif [ -f "$M/$id/requires-error" ]; then
			problems="$problems $(printf "$(text "$id" requires-error)" "$(label "$id")")"
		else
			problems="$problems $(label "$id") needs another choice that is not selected."
		fi
	done
}
