# Calamares' version of uninstall_run in Debian Installer's prepare.sh.

# Runs uninstall.sh inside the new system at TARGET ($1), logging any errors along the way. 
uninstall_run() {
	in_target sh /tmp/debian-livecd-installer/lib/uninstall.sh && return
	log "some deselected features could not be removed: $(tr '\n' ' ' < "$1/tmp/debian-livecd-installer/errors" 2>/dev/null)"
	mkdir -p "$1/var/log/installer/debian-livecd-installer"
	cp "$1/tmp/debian-livecd-installer/errors" "$1/var/log/installer/debian-livecd-installer/" || true
}
