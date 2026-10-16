# Sourced by the `deselect` scripts of the "Browser extensions" choices, see docs/installer.md.
# Uninstalls any extension from Google Chrome, Firefox, and Ungoogled Chromium based off ID. No-op if no such ID exists for that particular browser.
# uninstall_extension `ID` simply removes any `.crx`, `.json`, or `.xpi` files.
# Safe operation to remove the extensions in this way in no profile exists yet.

uninstall_extension() {
	for id in "$@"; do
		for dir in /opt/google/chrome/extensions /usr/share/chromium/extensions \
			"/usr/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"; do
			rm -f "$dir/$id.crx" "$dir/$id.json" "$dir/$id.xpi"
		done
	done
}
