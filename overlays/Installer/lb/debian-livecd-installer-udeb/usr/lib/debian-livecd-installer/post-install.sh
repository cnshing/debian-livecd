# Responsible for handling any individual post-install hooks.

# Copied as is from linux-factory's late-command (overlays/debianInstaller/filesystem/live_installer/usr/local/bin/late-command.overlay.tmpl at 0ff2740, lines 61-68).

# Runs each overlay's post-install hooks as root in the installed system and logs them to /var/log/install/post-install-NAME.log.
for script in "/root/install/hooks/post-install"/*.sh; do
    if [ -f "$script" ]; then
        SCRIPT_NAME=$(basename "$script" .sh)
        echo running /var/log/install/post-install-$SCRIPT_NAME.log 1>&2
        in-target sh -c "cd / && sh $script 2>>/var/log/install/post-install-$SCRIPT_NAME.log >>/var/log/install/post-install-$SCRIPT_NAME.log"
    fi
done
