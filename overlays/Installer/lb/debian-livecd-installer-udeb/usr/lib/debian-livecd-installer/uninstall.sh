#!/bin/sh
# uninstall.sh uninstalls any deselected choices from the installed system.

set -u
STATE=/tmp/debian-livecd-installer
. "$STATE/lib/manifest.sh"
. "$STATE/lib/deselect.sh"
. "$STATE/lib/packages.sh"
: > "$STATE/errors"


error() {
	echo "debian-livecd-installer: $*" >&2
	echo "$*" >> "$STATE/errors"
}

deselect_run
packages_purge

# Removes enabled units whose unit files are gone
find /etc/systemd/system /etc/systemd/user -path '*.wants/*' -xtype l -delete 2> /dev/null
# Rebuilds the dconf database without removed snippets in /etc/dconf/db/*.d
[ ! -x /usr/bin/dconf ] || dconf update || error "dconf update failed."

# Exits 1 if there were any problems
[ ! -s "$STATE/errors" ]
