#!/bin/sh
# Remove debian-installer-launcherr and related desktop icon integrations
apt-get --yes purge debian-installer-launcher
rm -f /etc/skel/Desktop/debian-installer-launcher.desktop /home/*/Desktop/debian-installer-launcher.desktop /etc/xdg/autostart/enable-launching-debian-installer.desktop
