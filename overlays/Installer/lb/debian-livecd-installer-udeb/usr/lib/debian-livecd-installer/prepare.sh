# prepare.sh prepares the installed system for removing the deselected choices sourced by uninstall.sh

# Prepares uninstall for the system by placing uninstall.sh and other information needed into TARGET/tmp/debian-livecd-installer
uninstall_prepare() {
	rm -rf "$1/tmp/debian-livecd-installer"
	mkdir -p "$1/tmp/debian-livecd-installer"
	cp -a "$STATE/manifest" "$STATE/deselected" "$1/tmp/debian-livecd-installer/"
	cp -a "$LIB" "$1/tmp/debian-livecd-installer/lib"
}

# Runs uninstall.sh inside the new system, showing any of its errors if it fails.
uninstall_run() {
	if ! in_target sh /tmp/debian-livecd-installer/lib/uninstall.sh; then
		db_subst debian-livecd-installer/uninstall-failed ERROR "$(tr '\n' ' ' < "$1/tmp/debian-livecd-installer/errors" 2>/dev/null)"
		db_input critical debian-livecd-installer/uninstall-failed || true
		db_go || true
	fi
}

# Clean up debian-livecd-installer in the new system
uninstall_cleanup() {
	rm -rf "$1/tmp/debian-livecd-installer"
}
