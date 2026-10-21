# A manifest represents all the available customization features for installation. The overlays write them as YAML in
# These provide some functionality for debian-installer to retrieve manifest information using the shell.

# "Global" "state" variables
STATE=${STATE:-/var/lib/debian-livecd-installer}
M=$STATE/manifest
IMAGE=/cdrom/live/filesystem.squashfs

log() { logger -t debian-livecd-installer "$*"; }
# Runs a command inside the new system with Debian Installer's in-target.
in_target() { in-target "$@"; }
# Reads a list file, one item per line
list() { cat "$1" 2>/dev/null || true; }
# Reads a section's or feature's ($1) label
label() { cat "$M/$1/label"; }
# Reads a section's or feature's ($1) text ($2), on one line
text() { cat "$M/$1/$2" 2>/dev/null || true; }
has() { case ", $2, " in *", $1, "*) return 0 ;; esac; return 1; } # has CHOICE "a, b, c"
categories() { for f in "$M"/*/label; do [ -f "$f" ] && basename "${f%/label}"; done; }
choices() { for f in "$M/$1"/*/label; do [ -f "$f" ] && basename "${f%/label}"; done; }

# Copies the manifest out of the SquashFS filesystem mounted by live-installer later
manifest_load() {
	[ -d "$M" ] && return 0
	ANNA_QUIET=1 anna-install squashfs-modules || true
	# depmod before installing to load squashfs-modules
	[ ! -x /sbin/depmod ] || depmod -a > /dev/null 2>&1 || true
	modprobe squashfs 2>/dev/null || true
	modprobe loop 2>/dev/null || true
	mkdir -p "$STATE/image"
	mount -t squashfs -o loop,ro "$IMAGE" "$STATE/image" || return 1
	mkdir -p "$M"
	cp -a "$STATE/image/var/lib/debian-livecd-installer/manifest/." "$M/" 2>/dev/null || true
	umount -d "$STATE/image"
}
