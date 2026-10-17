# Sourced by uninstall.sh, to purge any deselected choice's `packages`.

# Lists the installed packages of a choice, with globs expanded
packages_installed() {
	[ -f "$M/$1/packages" ] || return 0
	list "$M/$1/packages" | while read -r p; do
		dpkg-query -W -f '${db:Status-Status} ${Package}\n' "$p" 2> /dev/null
	done | awk '$1 == "installed" { print $2 }'
}

# Marks the packages of the deselected choices as automatically installed, so that `autoremove` purges them along with the dependencies nothing needs anymore. Any package that an installed package still depends on or recommends stays installed.
packages_purge() {
	purge=$(for id in $(cat "$STATE/deselected"); do packages_installed "$id"; done | sort -u)
	[ -n "$purge" ] || return 0
	apt-mark auto $purge > /dev/null && apt-get -y --purge autoremove || error "apt-get could not remove $(echo $purge)."
	for id in $(cat "$STATE/deselected"); do
		kept=$(packages_installed "$id")
		[ -z "$kept" ] || error "Kept $(echo $kept) ($id), as other installed packages still need them."
	done
}
