# When a choice is deselected, the `exclude` files ensure certain parts of the SquashFS filesystem are never included in the final installed system.


# Copies what is excluded to $STATE/exclude as ./paths
exclude_write() {
	for id in $(cat "$STATE/deselected"); do
		list "$M/$id/exclude"
	done | sed -n 's|^/\(..*\)|./\1|p' | sort -u > "$STATE/exclude"
}

# Deletes what is excluded from the new system at TARGET ($1)
exclude_delete_copied() {
	while read -r p; do
		case $p in ./?*) rm -rf "$1/${p#./}" ;; esac
	done < "$STATE/exclude"
}


# Intercepts the underlying tar execution as a shell function, replacing the previous tar with GNU's version, which is capable of excluding files.
exclude_intercept_tar() {
	LIVECD_EXCLUDE=/var/lib/debian-livecd-installer/exclude
	[ -s "$LIVECD_EXCLUDE" ] || return 0

	tar() {
		if [ "$*" = "c ." ] && [ -x ./usr/bin/tar ]; then
			LC_ALL=C chroot . /usr/bin/tar -c -f - --numeric-owner --anchored --no-wildcards \
				--exclude-from=- . < "$LIVECD_EXCLUDE"
		else
			busybox tar "$@"
		fi
	}


	# Excluding files causes a mismatch between how many files there are versus what is actually counted, which is responsible for controlling the progress bar and sanity-checking the final installed system by comparing the total count of files against this metric. A cheap mechanism was implemented to artificially lower the count from our excluded files, which may lead to a false negative where the installer does not raise an error on failed tar extraction due to this mechanism failing to account for hard links.
	livecd_count() {
		echo $(($1 - $(while read -r p; do
			if [ -e "$p" ] || [ -L "$p" ]; then find "$p"; fi
		done < "$LIVECD_EXCLUDE" | wc -l)))
	}

	for _fs in squashfs ext2 ext3 ext4 btrfs; do
		eval "${_fs}_count() { livecd_count \$(print-inodes /mnt); }"
	done
	dir_count() { livecd_count $(find . | wc -l); }
}
