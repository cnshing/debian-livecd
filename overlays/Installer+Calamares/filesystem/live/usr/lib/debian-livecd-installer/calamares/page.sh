# Calamares' remaining functionality to replicate Debian Installer's page.sh. 

# Writes the answers to $STATE/selected and $STATE/deselected, from the page's answer ($1): the selected choices.
page_answers() {
	: > "$STATE/selected"
	: > "$STATE/deselected"
	for category in $(categories); do
		for choice in $(choices "$category"); do
			case ",$1," in
				*",$category/$choice,"*) echo "$category/$choice" >> "$STATE/selected" ;;
				*) echo "$category/$choice" >> "$STATE/deselected" ;;
			esac
		done
	done
	if [ ! -s "$STATE/selected" ] && [ "$1" != none ]; then
		log "the page's answer names no choice: $1"
		return 1
	fi
}
