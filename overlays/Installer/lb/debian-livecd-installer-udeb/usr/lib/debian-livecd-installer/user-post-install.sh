# Responsible for running each overlay's user-post-install hooks.

# Copied as is from linux-factory's late-command (overlays/debianInstaller/filesystem/live_installer/usr/local/bin/late-command.overlay.tmpl at 0ff2740, lines 69-82), as a function.

# Runs each overlay's user-post-install hooks as the new user and logs them to /var/log/install/user-post-install-NAME.log.
user_post_install_run() {
mkdir -p $CHROOT/home/$DEFAULT_USER/install/hooks
cp -r /root/install/hooks/user-post-install $CHROOT/home/$DEFAULT_USER/install/hooks
in_target chown -R $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER
for s in "$CHROOT/home/$DEFAULT_USER/install/hooks/user-post-install"/*.sh; do
    SCRIPT_PATH=/home/$DEFAULT_USER/install/hooks/user-post-install/$(basename "$s")
    SCRIPT_NAME=$(basename "$s" .sh)
    if [ -f "${CHROOT}${SCRIPT_PATH}" ]; then
        LOG_PATH="/var/log/install/user-post-install-$SCRIPT_NAME.log"
        in_target touch $LOG_PATH
        in_target chown $DEFAULT_USER:$DEFAULT_USER $LOG_PATH
        echo running $SCRIPT_PATH 1>&2
        in_target su $DEFAULT_USER -c "cd /home/$DEFAULT_USER && sh $SCRIPT_PATH 2>>$LOG_PATH >>$LOG_PATH" < /dev/null
    fi
done
}
