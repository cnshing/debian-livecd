# Sourced by uninstall.sh, to purge any deselected choice's `packages`.

# Lists the installed packages of a choice, with globs expanded
packages_installed() {
	[ -f "$M/$1/packages" ] || return 0
	list "$M/$1/packages" | while read -r p; do
		dpkg-query -W -f '${db:Status-Status} ${Package}\n' "$p" 2> /dev/null
	done | awk '$1 == "installed" { print $2 }'
}

# Purges the packages of the deselected choices and autoremove the dependencies similarly to 14remove-live-packages.
packages_purge() {
	purge=$(for id in $(cat "$STATE/deselected"); do packages_installed "$id"; done | sort -u)
	[ -n "$purge" ] || return 0
	others=$(apt-get -s purge $purge | sed -n 's/^Purg \([^ :]*\).*/\1/p' | grep -vxF "$purge" || true)
	[ -n "$others" ] || { apt-get -y purge $purge && apt-get -y --purge autoremove; } || error "apt-get could not remove $(echo $purge)."
	for id in $(cat "$STATE/deselected"); do
		kept=$(packages_installed "$id")
		[ -z "$kept" ] || error "Kept $(echo $kept) ($id), as other installed packages still need them${others:+: $(echo $others)}."
	done
}
