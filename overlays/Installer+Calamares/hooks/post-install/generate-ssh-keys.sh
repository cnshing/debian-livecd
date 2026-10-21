#!/bin/sh
# The image has no SSH host keys (live-build deletes them). Debian Installer creates them (live-installer's openssh-server
# step), Calamares does not, and openssh-server's own sshd-keygen.service only runs on a first boot, which Calamares'
# machine ID rules out: without this, the installed system's SSH server would not start. Keys that exist are kept.
[ ! -x /usr/bin/ssh-keygen ] || ssh-keygen -A
