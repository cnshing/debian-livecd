# page.sh constructs the "Select optional features" page.

# Shows a multiselect per section, from each choice's `label`, `description` and `default`. A choice gets its `default` the first time it is offered, unless its section was preseeded. Sets $displayed if the page was shown.
page_ask() {
	displayed= below= last= gap=$(printf '\302\240') # Add a no-break space, as cdebconf trims and values with just whitespace
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
		value=$RET choices_c= choices= note=$(text "$category" description)
		[ -z "$note" ] || note="$note\n"
		for choice in $(choices "$category"); do
			id=$category/$choice
			choices_c="${choices_c:+$choices_c, }$choice"
			choices="${choices:+$choices, }$(label "$id")"
			[ -z "$(text "$id" description)" ] || note="$note$(label "$id") - $(text "$id" description)\n"
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
		# Trick to make each description appear at the bottom of each section by placing them at the top of the next section.
		[ "$DEBIAN_FRONTEND" = gtk ] || below=$note
		page_describe "$q" "$below"
		db_set "$q" "$value"
		[ -z "$again" ] || db_fset "$q" seen false
		if db_input high "$q"; then displayed=1 last=$note below=${note:-$gap}; fi
	done
	if [ "$DEBIAN_FRONTEND" = gtk ] && [ -n "$last" ]; then
		page_describe debian-livecd-installer/notes "$last"
		db_fset debian-livecd-installer/notes seen false
		db_input high debian-livecd-installer/notes || true
	fi
	db_go
}

# Sets a question's DESCRIPTION. `escape` has cdebconf turn each \n into a line break and trim any other backslash.
page_describe() {
	db_capb backup escape
	db_subst "$1" DESCRIPTION "$2"
	db_capb backup
}

# Writes the answers to $STATE/selected and $STATE/deselected
page_answers() {
	: > "$STATE/selected"
	: > "$STATE/deselected"
	for category in $(categories); do
		db_get "debian-livecd-installer/$category"
		for choice in $(choices "$category"); do
			id=$category/$choice
			if has "$choice" "$RET"; then
				echo "$id" >> "$STATE/selected"
			else
				echo "$id" >> "$STATE/deselected"
			fi
		done
	done
}
