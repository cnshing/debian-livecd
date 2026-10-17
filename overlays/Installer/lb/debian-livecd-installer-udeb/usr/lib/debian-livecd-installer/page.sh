# page.sh constructs the "Select optional features" page.

# Shows a multiselect per section, from each choice's `label`, `description` and `default`. A choice gets its `default` the first time it is offered, unless its section was preseeded. Sets $displayed if the page was shown.
page_ask() {
	displayed=
	db_settitle debian-installer/debian-livecd-installer/title
	for category in $(categories); do
		q=debian-livecd-installer/$category
		db_register debian-livecd-installer/category "$q"
		if ! grep -qx "$q" "$STATE/asked" 2>/dev/null; then
			echo "$q" >> "$STATE/asked"
			db_fget "$q" seen
			[ "$RET" != true ] || echo "$q" >> "$STATE/preseeded"
		fi
		db_get "$q"
		value=$RET choices_c= choices= notes=$(text "$category" description)
		for choice in $(choices "$category"); do
			id=$category/$choice
			reason=$(import_unavailable "$id")
			if [ -n "$reason" ]; then
				notes="$notes $(label "$id"): $reason"
				continue
			fi
			choices_c="${choices_c:+$choices_c, }$choice"
			choices="${choices:+$choices, }$(label "$id")"
			[ -z "$(text "$id" description)" ] || notes="$notes $(label "$id"): $(text "$id" description)"
			grep -qx "$id" "$STATE/offered" 2>/dev/null && continue
			echo "$id" >> "$STATE/offered"
			if [ "$(text "$id" default)" != false ] && ! grep -qx "$q" "$STATE/preseeded" 2>/dev/null; then
				value="${value:+$value, }$choice"
			fi
		done
		[ -n "$choices_c" ] || continue
		db_subst "$q" HEADING "$(label "$category")"
		db_subst "$q" CHOICES-C "$choices_c"
		db_subst "$q" CHOICES "$choices"
		db_subst "$q" DESCRIPTION "$notes"
		db_set "$q" "$value"
		[ -z "$again" ] || db_fset "$q" seen false
		if db_input high "$q"; then displayed=1; fi
	done
	db_go
}

# Writes the answers to $STATE/selected and $STATE/deselected
page_answers() {
	: > "$STATE/selected"
	: > "$STATE/deselected"
	for category in $(categories); do
		db_get "debian-livecd-installer/$category"
		for choice in $(choices "$category"); do
			id=$category/$choice
			if has "$choice" "$RET" && [ -z "$(import_unavailable "$id")" ]; then
				echo "$id" >> "$STATE/selected"
			else
				echo "$id" >> "$STATE/deselected"
			fi
		done
	done
}
