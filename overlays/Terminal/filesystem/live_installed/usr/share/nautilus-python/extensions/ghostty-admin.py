# Adds an elevated "Open in Ghostty" context menu item to folders opened with nautilus-admin's "Open as Administrator".
# Ghostty's own extension, ghostty.py, skips admin:// locations, as they have no local path and gvfs hides the admin mount.
# This extension attempts to resolve the location behind admin://, reusing ghostty.py's path selection and translated label.

import os
from gi.repository import Nautilus, GObject, Gio

try:
    from ghostty import get_paths_to_open, _
except ModuleNotFoundError as e:
    # When Ghostty is uninstalled
    if e.name != 'ghostty':
        raise

    # Find no paths, so as to show no menu item
    def get_paths_to_open(files):
        return []


class LocalFolder:
    """The part of Nautilus.FileInfo that ghostty.py reads, for the local folder behind an admin:// file."""

    def __init__(self, file):
        location = file.get_location() if file.is_directory() else file.get_parent_location()
        self.location = Gio.File.new_for_uri(location.get_uri().replace('admin://', 'file://', 1))

    def is_directory(self):
        return True

    def get_location(self):
        return self.location


def open_in_ghostty_as_root_activated(_menu, paths):
    for path in paths:
        # Change directory manually instead of relying on Ghostty's --working-directory, as a non-root user may not be allowed into that folder
        cmd = ['ghostty', '--gtk-single-instance=false', '-e', 'sudo', '--', 'sh', '-c', 'cd -- "$1" && exec "$2"',
            'sh', path, os.environ.get('SHELL', '/bin/sh')]
        Gio.Subprocess.new(cmd, Gio.SubprocessFlags.NONE)


def get_items_for_admin_files(name, files):
    paths = get_paths_to_open([LocalFolder(file) for file in files if file.get_uri_scheme() == 'admin'])
    if paths:
        item = Nautilus.MenuItem(name=name, label=_('Open in Ghostty'), icon='com.mitchellh.ghostty')
        item.connect('activate', open_in_ghostty_as_root_activated, paths)
        return [item]
    else:
        return []


class GhosttyAdminMenuProvider(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        return get_items_for_admin_files('GhosttyAdminNautilus::open_in_ghostty', files)

    def get_background_items(self, file):
        return get_items_for_admin_files('GhosttyAdminNautilus::open_folder_in_ghostty', [file])
