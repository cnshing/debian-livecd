#!/bin/sh
# Calamares' counterpart of Debian Installer's finish-install.d/08post-install-hooks.
# Copies `import` files from the live session and runs the post-install-hooks for the system and user.
#   sh post-install-hooks.sh TARGET NEW_USER SELECTED
# where TARGET is where the new system is mounted, NEW_USER its user, and SELECTED are the selected features.
set -e
TARGET=$1

# Loads Debian Installer's functions, then Calamares' versions of those that differ
LIB=/usr/lib/debian-livecd-installer
for module in manifest page import post-install user-post-install; do
	. "$LIB/$module.sh"
	[ ! -f "$LIB/calamares/$module.sh" ] || . "$LIB/calamares/$module.sh"
done

manifest_load
page_answers "$3"
page_log "$TARGET"
user_find "$TARGET" "$2"
import_snapshot
import_copy "$TARGET"
post_install_hooks "$TARGET"
exit 0
