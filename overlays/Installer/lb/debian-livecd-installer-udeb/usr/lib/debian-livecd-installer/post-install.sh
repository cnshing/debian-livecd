# Responsible for handling any individual post-install hooks.

# Copied as is from linux-factory's late-command (overlays/debianInstaller/filesystem/live_installer/usr/local/bin/late-command.overlay.tmpl at 0ff2740, lines 61-68), as a function.

# Runs each overlay's post-install hooks as root in the installed system and logs them to /var/log/install/post-install-NAME.log.
post_install_run() {
for script in "/root/install/hooks/post-install"/*.sh; do
    if [ -f "$script" ]; then
        SCRIPT_NAME=$(basename "$script" .sh)
        echo running /var/log/install/post-install-$SCRIPT_NAME.log 1>&2
        in_target sh -c "cd / && sh $script < /dev/null 2>>/var/log/install/post-install-$SCRIPT_NAME.log >>/var/log/install/post-install-$SCRIPT_NAME.log"
    fi
done
}

# Runs the user-post-install and post-install hooks (as the user that user_find found in the new system at in the new system at TARGET ($1). A failing hook does not fail any other hooks.
post_install_hooks() {
	set +e
	export CHROOT=$1
	export DEFAULT_USER=
	[ -z "$entry" ] || DEFAULT_USER=$user
	mkdir -p $CHROOT/var/log/install

	post_install_run
	if [ -n "$DEFAULT_USER" ]; then
		user_post_install_run
		rm -rf $CHROOT/home/$DEFAULT_USER/install
	else
		log "no user account, so the user-post-install hooks did not run"
	fi

	rm -rf $CHROOT/root/install
}
