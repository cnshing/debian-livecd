# import.sh allows each selected choice to copy any file paths in `import` from the live session directly to the installed system.
# Copies the contents of $1 into $2, without changing the mode and owner of $2
import_copy_into() {
	(cd "$1" && find . -mindepth 1 -maxdepth 1) | while read -r entry; do
		cp -a "$1/$entry" "$2/" || log "warning: could not copy ${entry#./} into $2"
	done
}


# Finds the user that Debian Installer created in the new system at TARGET ($1) and sets their variables
user_find() {
	user=$(debconf-get passwd/username || true)
	entry=
	if [ "$(debconf-get passwd/make-user || true)" != false ] && [ -n "$user" ]; then
		entry=$(grep "^$user:" "$1/etc/passwd" || true)
	fi
	uid=$(echo "$entry" | cut -d: -f3)
	gid=$(echo "$entry" | cut -d: -f4)
	home=$(echo "$entry" | cut -d: -f6)
}

# Copies what the selected choices `import` from the running live session to $STATE/import/CHOICE/home/ and .../system/,
# readable by root only, where import_copy finds them. `~/...` paths are in the home of the live user who started the
# installer through pkexec. Only an installer that runs in the live session can do this, such as Calamares.
import_snapshot() {
	live_home=$(getent passwd "${PKEXEC_UID:-1000}" | cut -d: -f6)
	rm -rf "$STATE/import"
	mkdir -p -m 700 "$STATE/import"
	for id in $(cat "$STATE/selected"); do
		list "$M/$id/import" | while read -r path; do
			path=${path%/} # A folder is copied as itself, with or without its trailing /
			case $path in
				"~/"*) from=$live_home/${path#"~/"} to=$STATE/import/$id/home/${path#"~/"} ;;
				/*) from=$path to=$STATE/import/$id/system$path ;;
				*) continue ;;
			esac
			[ -e "$from" ] || continue
			mkdir -p "${to%/*}"
			cp -a "$from" "${to%/*}/" || log "warning: $id: could not copy $from"
		done
	done
}

# Copies any live session files for an `import` into the new system at TARGET ($1). Any files located in ~/ are owned by the newly installed user.
import_copy() {
	for id in $(cat "$STATE/selected" 2>/dev/null); do
		[ -f "$M/$id/import" ] || continue
		snapshot=$STATE/import/$id
		if [ -z "$(ls -A "$snapshot" 2>/dev/null)" ]; then
			log "warning: $id: no files from a live session, so nothing was copied"
			continue
		fi
		if [ -d "$snapshot/system" ]; then
			import_copy_into "$snapshot/system" "$1"
		fi
		if [ -d "$snapshot/home" ] && [ -n "$home" ] && [ -d "$1$home" ]; then
			import_copy_into "$snapshot/home" "$1$home"
			(cd "$snapshot/home" && find . -mindepth 1) | while read -r p; do
				chown -h "$uid:$gid" "$1$home/${p#./}"
			done
		elif [ -d "$snapshot/home" ]; then
			log "$id: no user account, so the live user's files were not copied"
		fi
		log "$id: copied from the live session"
	done
}
