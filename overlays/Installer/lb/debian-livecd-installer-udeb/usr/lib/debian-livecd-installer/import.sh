# import.sh allows each selected choice to copy any file paths in `import` from the live session directly to the installed system.

# Prints why a choice cannot be offered. Its files must be copied temporarily to $STATE/import/<choice> before the installer starts, as any installation from the boot menu has no live session to copy from.
import_unavailable() {
	[ -f "$M/$1/import" ] || return 0
	[ -z "$(ls -A "$STATE/import/$1" 2>/dev/null)" ] || return 0
	[ -n "${LIVE_INSTALLER_MODE:-}" ] || echo "Only possible when the installer is started from the running live system."
}

# Adds to $warnings the selected choices whose files were not found
import_check() {
	for id in $(cat "$STATE/selected"); do
		[ -f "$M/$id/import" ] && [ -z "$(import_unavailable "$id")" ] || continue
		[ -n "$(ls -A "$STATE/import/$id" 2>/dev/null)" ] || warnings="$warnings The requested import files for \"$(label "$id")\" were not found, so they were skipped."
	done
}

# Copies the contents of $1 into $2, without changing the mode and owner of $2
import_copy_into() {
	(cd "$1" && find . -mindepth 1 -maxdepth 1) | while read -r entry; do
		cp -a "$1/$entry" "$2/"
	done
}

# Copies home/ into the new user's home, owned by the new user, and system/ to the same place as in the live system. Then deletes the copies from the installer's logs, as they may contain private secrets.
import_copy() {
	[ -d "$STATE/import" ] || return 0
	for id in $(cat "$STATE/selected" 2>/dev/null); do
		snapshot=$STATE/import/$id
		[ -d "$snapshot" ] || continue
		if [ -d "$snapshot/system" ]; then
			import_copy_into "$snapshot/system" /target
		fi
		if [ -d "$snapshot/home" ] && [ -n "$home" ] && [ -d "/target$home" ]; then
			import_copy_into "$snapshot/home" "/target$home"
			(cd "$snapshot/home" && find . -mindepth 1) | while read -r p; do
				chown -h "$uid:$gid" "/target$home/${p#./}"
			done
		elif [ -d "$snapshot/home" ]; then
			log "$id: no user account, so the live user's files were not copied"
		fi
		log "$id: copied from the live session"
	done
	rm -rf "$STATE/import"
}
