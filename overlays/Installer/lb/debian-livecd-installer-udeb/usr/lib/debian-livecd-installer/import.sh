# import.sh allows each selected choice to copy any file paths in `import` from the live session directly to the installed system.
# Copies the contents of $1 into $2, without changing the mode and owner of $2
import_copy_into() {
	(cd "$1" && find . -mindepth 1 -maxdepth 1) | while read -r entry; do
		cp -a "$1/$entry" "$2/" || log "warning: could not copy ${entry#./} into $2"
	done
}


# Copies any live session files for an `import`. Any files located in ~/ are owned by the newly installed user. 
import_copy() {
	for id in $(cat "$STATE/selected" 2>/dev/null); do
		[ -f "$M/$id/import" ] || continue
		snapshot=$STATE/import/$id
		if [ -z "$(ls -A "$snapshot" 2>/dev/null)" ]; then
			log "warning: $id: no files from a live session, so nothing was copied"
			continue
		fi
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
}
