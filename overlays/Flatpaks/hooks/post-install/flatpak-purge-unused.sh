#!/bin/sh
# Cleans up any unused runtimes left over from Flatpak application opt-out by the user. 
flatpak --system uninstall -y --noninteractive --unused
for trigger in /usr/share/flatpak/triggers/*.trigger; do
    "$trigger" /var/lib/flatpak
done
