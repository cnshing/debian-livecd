# A manifest represents all the available customization features for installation located in `/usr/share/debian-livecd-installer`.

# "Global" "state" variables
STATE=${STATE:-/var/lib/debian-livecd-installer}
M=$STATE/manifest
IMAGE=/cdrom/live/filesystem.squashfs

log() { logger -t debian-livecd-installer "$*"; }
# Reads a file line by line, without comments and empty lines
list() { sed -e 's/[[:space:]]*#.*//' -e '/^$/d' "$1" 2>/dev/null | awk '!seen[$0]++' || true; }
# Reads a label as one line, without commas, as debconf separates choices with commas
label() { head -n1 "$M/$1/label" | tr -d ',\\'; }
text() { echo $(cat "$M/$1/$2" 2>/dev/null); }
has() { case ", $2, " in *", $1, "*) return 0 ;; esac; return 1; } # has CHOICE "a, b, c"
categories() { for f in "$M"/*/label; do [ -f "$f" ] && basename "${f%/label}"; done; }
choices() { for f in "$M/$1"/*/label; do [ -f "$f" ] && basename "${f%/label}"; done; }

# Copies the choices out of the SquashFS filesystem mounted by live-installer later
manifest_load() {
	[ -d "$M" ] && return 0
	ANNA_QUIET=1 anna-install squashfs-modules || true
	modprobe squashfs 2>/dev/null || true
	modprobe loop 2>/dev/null || true
	mkdir -p "$STATE/image" "$M"
	mount -t squashfs -o loop,ro "$IMAGE" "$STATE/image" || return 1
	cp -a "$STATE/image/usr/share/debian-livecd-installer/." "$M/" 2>/dev/null || true
	umount -d "$STATE/image"
}
