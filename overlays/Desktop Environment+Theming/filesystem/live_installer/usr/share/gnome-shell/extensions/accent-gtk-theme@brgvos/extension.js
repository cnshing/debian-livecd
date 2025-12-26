/* extension.js
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

export default class AccentColorGtkThemeExtension extends Extension {
    _settings;
    _preferences;
    _accentColorChangedId = 0;
    _colorSchemeChangedId = 0;
    _customThemeChangedId = 0;
    _stateSwitchChangedId = 0;
    _pathThemeChangedId = 0;
    gtkThemesLight = Object.values({});
    gtkThemesDark = Object.values({});

    // Next method is run when the extension is enabled
    enable() {
        // Get the interface settings
        this._settings = new Gio.Settings({
            schema: "org.gnome.desktop.interface",
        });
        // Initializing gtk themes
        this.gtkThemesDark = Object.values({
            blue: "Fluent-round-Dark",
            teal: "Fluent-round-teal-Dark",
            green: "Fluent-round-green-Dark",
            yellow: "Fluent-round-yellow-Dark",
            orange: "Fluent-round-orange-Dark",
            red: "Fluent-round-red-Dark",
            pink: "Fluent-round-pink-Dark",
            purple: "Fluent-round-purple-Dark",
            slate: "Fluent-round-grey-Dark",
        });
        this.gtkThemesLight = Object.values({
            blue: "Fluent-round-Light",
            teal: "Fluent-round-teal-Light",
            green: "Fluent-round-green-Light",
            yellow: "Fluent-round-yellow-Light",
            orange: "Fluent-round-orange-Light",
            red: "Fluent-round-red-Light",
            pink: "Fluent-round-pink-Light",
            purple: "Fluent-round-purple-Light",
            slate: "Fluent-round-grey-Light",
        });
        // Get Preferences
        this._preferences = this.getSettings();
        // Connect to accent color changes
        this._accentColorChangedId = this._settings.connect("changed::accent-color", this._onSomethingChanged.bind(this));
        // Connect to color scheme changes
        this._colorSchemeChangedId = this._settings.connect("changed::color-scheme", this._onSomethingChanged.bind(this));
        // Connect to switch Create link to gtk4 local config
        this._stateSwitchChangedId = this._preferences.connect("changed::set-link-gtk4", this._onSomethingChanged.bind(this));        
        // Connect to editable Path Theme 
        this._pathThemeChangedId = this._preferences.connect("changed::set-theme-path", this._onSomethingChanged.bind(this)); 
        // Initial theme update
        this._onSomethingChanged();
    }

    // Next metod is run when the estension is disabled    
    disable() {
        // Disconnect the signal handler
        if (this._settings && this._accentColorChangedId) {
            this._settings.disconnect(this._accentColorChangedId);
            this._accentColorChangedId = 0;
        }
        if (this._settings && this._colorSchemeChangedId) {
            this._settings.disconnect(this._colorSchemeChangedId);
            this._colorSchemeChangedId = 0;
        }
        if (this._preferences && this._stateSwitchChangedId) {
            this._preferences.disconnect(this._stateSwitchChangedId);
            this._stateSwitchChangedId = 0;
        }
        if (this._preferences && this._pathThemeChangedId) {
            this._preferences.disconnect(this._pathThemeChangedId);
            this._pathThemeChangedId = 0;
        }
        // Clear the gtkThemes array
        this.gtkThemesDark = [];
        this.gtkThemesLight = [];
        // Optionally reset to default gtk theme - Adwaita
        this._setGtkTheme("Adwaita");
        // Null out settings
        this._settings = null;
        this._preferences = null;
        // Delete files and directories if exist
        this._delFilesDirsLocalGtk4();
    }

    // Next metod is called when extension is enabled, color accent, edit a new path to the themes, or the switch for set link gtk4 local is changed
    _onSomethingChanged() {
        // Get the state of the switch Create link to gtk4 local config
        const changeSetLinkGTK4 = this._preferences?.get_boolean("set-link-gtk4");
        // Check color scheme and set the user theme
        if(this._settings?.get_string("color-scheme") === 'prefer-dark') {
            // Get the current accent color
            const accentColor = this._settings?.get_string("accent-color") ?? "blue";
            // Get custom theme from preferences
            const customTheme = this._preferences?.get_string(`${accentColor}-theme-dark`);
            // Get the corresponding gtk theme or default to Adwaita
            const gtkTheme = customTheme || "Adwaita";
            // Set the gtk theme
            this._setGtkTheme(gtkTheme);
            // Set link for libadwaita
            if(changeSetLinkGTK4) {
                // If the swith is ON first delete actual symlinks
                this._delFilesDirsLocalGtk4();
                // Then create new symlink to the light user theme
                this._createFilesDirsLocalGtk4(gtkTheme);
            } else {
                // Else if the switch is OFF delete actual symlinks
                this._delFilesDirsLocalGtk4();
            }
        }
        else {
            // Get the current accent color
            const accentColor = this._settings?.get_string("accent-color") ?? "blue";
            // Get custom theme from preferences
            const customTheme = this._preferences?.get_string(`${accentColor}-theme-light`);
            // Get the corresponding gtk theme or default to Adwaita
            const gtkTheme = customTheme || "Adwaita";
            // Set the gtk theme
            this._setGtkTheme(gtkTheme);
            // Set link for libadwaita
            if(changeSetLinkGTK4) {
                // If the swith is ON first delete actual symlinks
                this._delFilesDirsLocalGtk4();
                // Then create new symlink to the dark user theme
                this._createFilesDirsLocalGtk4(gtkTheme);
            } else {
                // Else if the switch is OFF delete actual symlinks
                this._delFilesDirsLocalGtk4();
            }
        }
    }

    // Next method create symlinks to user local gtk 4 config
    _createFilesDirsLocalGtk4(themeName) {
        // Get the path where is the theme installed
        const setPathTheme = this._preferences?.get_string(`set-theme-path`);
        // Relative path to directory
        const relativePath = '.config/gtk-4.0';
        const dirFile = this._createFullPath(relativePath);
        const pathRelative = dirFile.get_path();
        //Create directory if not exist
        this._createDirectoryInHomeDir(dirFile);
        // Copy file gtk.css to $HOME/.config/gtk-4.0/gtk.css
        const source_1 = setPathTheme+'/'+themeName+'/gtk-4.0/gtk.css';
        const destination_1 = pathRelative+'/gtk.css';
        this._copyFile(source_1, destination_1);
        // Copy file gtk-dark.css to $HOME/.config/gtk-4.0/gtk-dark.css
        const source_2 = setPathTheme+'/'+themeName+'/gtk-4.0/gtk-dark.css';
        const destination_2 = pathRelative+'/gtk-dark.css';
        this._copyFile(source_2, destination_2);
        // Copy assests directory to $HOME/.config/gtk-4.0/assets
        const source_3 = setPathTheme+'/'+themeName+'/gtk-4.0/assets';
        const destination_3 = pathRelative+'/assets';
        this._copyRecursive(source_3, destination_3);
        // Create symbolic link at $HOME/.config/gtk-4.0/windows-assets for MacTahoe or WhiteSur theme, for Fluent is not needed
        const onlyThemeName = themeName.split("-",1); // take  from full name only the name, at the first char "-"
        if(onlyThemeName == 'MacTahoe' || onlyThemeName == 'WhiteSur') {
            const source_4 = setPathTheme+'/'+themeName+'/gtk-4.0/windows-assets';
            const destination_4 = pathRelative+'/windows-assets';
            this._copyRecursive(source_4, destination_4);
        }
    }

    // Next method remove symlinks from local gtk 4 config
    _delFilesDirsLocalGtk4() {
        // Relative path to directory
        const relativePath = '.config/gtk-4.0';
        const dirFile = this._createFullPath(relativePath);
        const pathRelative = dirFile.get_path();
        // Delete file $HOME/.config/gtk-4.0/gtk.css
        const path_1 = pathRelative+'/gtk.css';
        this._deleteFile(path_1);
        // Delete file $HOME/.config/gtk-4.0/gtk-dark.css
        const path_2 = pathRelative+'/gtk-dark.css';
        this._deleteFile(path_2);
        // Delete directory $HOME/.config/gtk-4.0/assets
        const path_3 = pathRelative+'/assets';
        //this._deleteFile(path_3);
        this._deleteRecursive(path_3);
        // Delete directory $HOME/.config/gtk-4.0/windows-assets if exist
        const path_4 = pathRelative+'/windows-assets';
        const pathWindowsAssets =  Gio.File.new_for_path(path_4);
        if (pathWindowsAssets.query_exists(null)) {
            this._deleteRecursive(path_4);
        }
    }
    
    // Next method set the theme
    _setGtkTheme(themeName) {
        // Set the gtk theme
        this._settings?.set_string("gtk-theme", themeName);
    }

    // Next method return the full path for $HOME/.config/gtk-4.0
    _createFullPath(relativePath) {
        // Get the user's home directory
        const homeDir = GLib.get_home_dir();
        // Construct the full path
        const fullPath = GLib.build_filenamev([homeDir, relativePath]);
        // Create a Gio.File object for the directory
        const dirFile = Gio.File.new_for_path(fullPath);
        return dirFile;
    }

    //Next method create directory with parents (like 'mkdir -p')
    _createDirectoryInHomeDir(dirFile) {
        // Check if the path not exist
        if (!dirFile.query_exists(null)) {
            // Create the directory with parents
            dirFile.make_directory_with_parents(null);
        }
    }

    // Next method copy a file
    _copyFile(sourcePath, destinationPath) {
        // Create a Gio.File objects
        const sourceFile = Gio.File.new_for_path(sourcePath);
        const destinationFile = Gio.File.new_for_path(destinationPath);
        // Check if the file already exists or the source not exist, if is true do nothing
        if (destinationFile.query_exists(null) || !sourceFile.query_exists(null)) {
            return;
        }
        // Copy file
        sourceFile.copy_async(destinationFile,
            Gio.FileCopyFlags.NONE, 
            null, 
            null, 
            null, (sourceFile, result) => {
                sourceFile.copy_finish(result);
            });
    }

    // Next method delete a file
    _deleteFile(path) {
        // Create a Gio.File object for the file
        const deletFile = Gio.File.new_for_path(path);
        // Check if the file exist, if not exist do nothig
        if (!deletFile.query_exists(null)) {
            return;
        }
        deletFile.delete_async(null, null, (deletFile, result) => {
            deletFile.delete_finish(result);
        });
    }

    // Next method copy a directory recursive
    _copyRecursive(srcPath, destPath) {
        // Create a Gio.File objects
        const src = Gio.File.new_for_path(srcPath);
        const dest = Gio.File.new_for_path(destPath);
        let info = src.query_info('standard::type', Gio.FileQueryInfoFlags.NONE, null);
        // check if the path is a directory
        if (info.get_file_type() === Gio.FileType.DIRECTORY) {  
            // Create destination directory with parents (like 'mkdir -p')
            try {
                dest.make_directory_with_parents(null);
            } catch (e) {
                // ignore if already exists
                }
            let enumerator = src.enumerate_children('standard::name,standard::type', Gio.FileQueryInfoFlags.NONE, null);
            let childInfo;
            while ((childInfo = enumerator.next_file(null)) !== null) {
                let childSrc = src.get_child(childInfo.get_name());
                let childDest = dest.get_child(childInfo.get_name());
                this._copyRecursive(childSrc.get_path(), childDest.get_path());
            }
        } else {
            // Copy single file, overwrite if exists
            src.copy(dest, Gio.FileCopyFlags.OVERWRITE, null, null);
        }
    }

    // Next method delete a directory recursive
    _deleteRecursive(path) {
        const file = Gio.File.new_for_path(path);
        // Check if the file/directory exist, if not exist do nothig
        if (file.query_exists(null)) {
            let info = file.query_info('standard::type', Gio.FileQueryInfoFlags.NONE, null);
            // check if the path is a directory
            if (info.get_file_type() === Gio.FileType.DIRECTORY) {
                let enumerator = file.enumerate_children('standard::name', Gio.FileQueryInfoFlags.NONE, null);
                let childInfo;
                while ((childInfo = enumerator.next_file(null)) !== null) {
                    let childPath = GLib.build_filenamev([path, childInfo.get_name()]);
                    this._deleteRecursive(childPath);
                }
            }
            file.delete(null);
        }
    }

}
