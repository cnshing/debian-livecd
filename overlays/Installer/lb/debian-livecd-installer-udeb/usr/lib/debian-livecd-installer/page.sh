# page.sh constructs the "Select optional features" page.

# Shows one multiselect of every section's choices, each as "Section<TAB>Choice<TAB>Description" which cdebconf's `align` capability draws as columns. Each section's answer is kept in its own question, to allow preseeding.
# Note: We use this format to avoid a bug with cdebconf's GTK frontend as it either selects all or selects none for a multiselect (checkboxes call gtk_list_store_set on a GtkTreeStore)
page_ask() {
	displayed= shown= notes= choices_c= choices= value= tab=$(printf '\t')
	# Use the screen resolution to manually calculate the word wrap.
	# NOTE: about 7 pixels per character of DejaVu Sans 9 (bold labels take about 7.2, descriptions about 6.3), 15 between columns and 86 for the checkbox and margins
	width=$(cut -d, -f1 /sys/class/graphics/fb0/virtual_size 2>/dev/null)
	labels=$(for category in $(categories); do label "$category"; for choice in $(choices "$category"); do echo "$tab$(label "$category/$choice")"; done; done | awk -F "$tab" '{ if (length($1) > a) a = length($1); if (length($2) > b) b = length($2) } END { print a + b }')
	width=$(( (${width:-800} - 116 - 7 * labels) / 7 ))
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
		section=$RET
		for choice in $(choices "$category"); do
			id=$category/$choice
			grep -qx "$id" "$STATE/offered" 2>/dev/null && continue
			echo "$id" >> "$STATE/offered"
			if [ "$(text "$id" default)" != false ] && ! grep -qx "$q" "$STATE/preseeded" 2>/dev/null; then
				section="${section:+$section, }$choice"
			fi
		done
		db_set "$q" "$section"
		if [ -z "$again" ] && grep -qx "$q" "$STATE/preseeded" 2>/dev/null; then continue; fi
		shown="$shown $category"
		[ -z "$(text "$category" description)" ] || notes="$notes$(label "$category") - $(text "$category" description)\n"
		for choice in $(choices "$category"); do
			id=$category/$choice description=
			if [ "$DEBIAN_FRONTEND" = gtk ]; then
				# Remove backslashes to prevent choice splitting on a comma, wrap the description to fit the width, indent new lines, and escape commas.
				description=$(text "$id" description | tr -d '\\' | awk -v w="$width" -v t="$tab" '{ for (i = 1; i <= NF; i++) { if (l != "" && length(l $i) >= w) { o = o l "\\n" t t; l = "" } l = l (l != "" ? " " : "") $i } printf "%s", o l }' | sed 's/,/\\\\,/g')
			elif [ -n "$(text "$id" description)" ]; then
				# newt cuts the list at the screen's width, often 80 columns, so its descriptions go above the list
				notes="$notes$(label "$id") - $(text "$id" description)\n"
			fi
			choices_c="${choices_c:+$choices_c, }$id"
			choices="${choices:+$choices, }$(label "$category")$tab$(label "$id")${description:+$tab$description}"
			! has "$choice" "$section" || value="${value:+$value, }$id"
		done
	done
	[ -n "$choices_c" ] || return 0
	q=debian-livecd-installer/features
	db_subst "$q" CHOICES-C "$choices_c"
	# cdebconf converts each \n into a line break and removes the backslash of \x
	db_capb backup align escape
	db_subst "$q" CHOICES "$choices"
	db_subst "$q" DESCRIPTION "$notes"
	db_capb backup align
	db_set "$q" "$value"
	[ -z "$again" ] || db_fset "$q" seen false
	if db_input high "$q"; then displayed=1; fi
	db_go || return
	# Splits the answer back into its sections' questions
	db_get "$q"
	value=$RET
	for category in $shown; do
		section=
		for choice in $(choices "$category"); do
			! has "$category/$choice" "$value" || section="${section:+$section, }$choice"
		done
		db_set "debian-livecd-installer/$category" "$section"
	done
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

# Records what was selected and not selected, the manifest and state to $1/var/log/installer
page_log() {
	mkdir -p "$1/var/log/installer/debian-livecd-installer"
	cp -a "$STATE/selected" "$STATE/deselected" "$STATE/manifest" "$1/var/log/installer/debian-livecd-installer/" 2>/dev/null || true
}
