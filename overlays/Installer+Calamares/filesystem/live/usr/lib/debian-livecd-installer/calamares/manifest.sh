# Calamares' remaining functionality for Debian Installer's manifest.sh. 

log() { echo "debian-livecd-installer: $*"; }

# Calamares has no in-target: it mounts the new system at a path of its own as TARGET.
in_target() { chroot "$TARGET" "$@"; }
