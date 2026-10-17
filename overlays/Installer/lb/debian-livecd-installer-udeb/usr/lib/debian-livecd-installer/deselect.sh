# Sourced by uninstall.sh. When a choice is deselected, a shell script is run as root before its packages are purged as part of the process to remove the deselected choice.

deselect_run() {
	for id in $(cat "$STATE/deselected"); do
		[ -f "$M/$id/deselect" ] || continue
		sh -e "$M/$id/deselect" || error "The removal deselection script of $id failed."
	done
}
