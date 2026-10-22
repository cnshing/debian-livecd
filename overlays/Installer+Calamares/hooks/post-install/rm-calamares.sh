#!/bin/sh
# Removes Calamares and any of its dependencies from the live session as they are not needed anymore
# Marking them lets autoremove purge them
apt-mark auto calamares calamares-settings-debian libxcb-cursor0 qml6-module-qtquick qml6-module-qtquick-controls \
	qml6-module-qtquick-layouts qml6-module-qtquick-templates qml6-module-qtquick-window qml6-module-qtqml-workerscript
apt-get --yes --purge autoremove

rm -rf /etc/calamares /usr/lib/debian-livecd-installer
