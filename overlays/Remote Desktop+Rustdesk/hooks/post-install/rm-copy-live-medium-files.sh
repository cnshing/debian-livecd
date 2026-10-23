#!/bin/sh
# This ensures `copy-live-medium-files` will not be present in the installed system
rm -f /usr/lib/live/config/2550-configure-rustdesk-toml.sh \
    /usr/lib/live/boot/9995-copy-live-medium-files.sh \
    /usr/sbin/copy-live-medium-files \
    /usr/share/initramfs-tools/hooks/copy-live-medium-files
