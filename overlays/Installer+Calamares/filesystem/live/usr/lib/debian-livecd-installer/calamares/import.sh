# Calamares' remaining functionality for Debian Installer's import.sh.

# Finds the corresponding user that Calamares created, NAME ($2), in the new system at TARGET ($1) and sets variables.
user_find() {
	user=$2
	entry=$(grep "^$user:" "$1/etc/passwd" || true)
	uid=$(echo "$entry" | cut -d: -f3)
	gid=$(echo "$entry" | cut -d: -f4)
	home=$(echo "$entry" | cut -d: -f6)
}
