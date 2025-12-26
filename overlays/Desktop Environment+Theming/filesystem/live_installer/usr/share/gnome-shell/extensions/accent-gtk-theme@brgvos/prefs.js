/* prefs.js
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
import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk';
import { ExtensionPreferences, gettext as _ } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class AccentDirsPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const preferences = this.getSettings();
        const page = new Adw.PreferencesPage({
            title: _('General'),
            iconName: 'dialog-information-symbolic',
        });
        const GeneralGroup = new Adw.PreferencesGroup({
            title: _('General'),
            description: _('Configure General Options'),
        });
        page.add(GeneralGroup);
        // Create a switch
        const setLinkGTK4 = new Adw.SwitchRow({
            title: _('Create link to gtk4 local config'),
            subtitle: _('Enables or disables create link to gtk4 local config for theming libadwaita'),
        });
        GeneralGroup.add(setLinkGTK4);
        // Create a label for the entry
        const label = new Adw.PreferencesGroup();
        label.set_title('Path to the themes');
        label.set_visible(false);
        // Create an entry for the variable
        const pathTheme = new Adw.EntryRow();
        pathTheme.set_title('Edit the path and then push Save button (used for link in .config/gtk-4.0)');
        pathTheme.set_text(this._getPathTheme(preferences)); // Set the current value
        label.add(pathTheme);
        GeneralGroup.add(label);   
        // Create a save button
        const saveButton = new Gtk.Button({
            label: "Save",
            visible: false,
        });
        saveButton.connect("clicked", () => {
            //_setPathTheme(pathTheme.get_text()); // Save the new path
            preferences.set_string('set-theme-path', pathTheme.get_text());
        });
        GeneralGroup.add(saveButton);
        // connect the switch state with label and botton to be visible or not 
        setLinkGTK4.connect("notify::active", (row) => {
            let isActive = row.get_active();
            if(isActive) {                
                label.set_visible(isActive);
                saveButton.set_visible(isActive);
            } else {
                label.set_visible(isActive);
                saveButton.set_visible(isActive);
            }
        });
        // Add custom light theme selection group
        const ThemeGroupLight = new Adw.PreferencesGroup({
            title: _('Custom Gtk Themes Light'),
            description: _('Select custom gtk themes for each accent color'),
        });
        page.add(ThemeGroupLight);
        // Get available gtk themes
        const gtkThemesLight = this._getAvailableGtkThemes();
        // Create dropdown for each accent color
        const accentColorsLight = [
            'blue', 'teal', 'green', 'yellow',
            'orange', 'red', 'pink', 'purple', 'slate'
        ];
        accentColorsLight.forEach(color => {
            const row = new Adw.ComboRow({
                title: _(color.charAt(0).toUpperCase() + color.slice(1)),
                model: this._createGtkThemeModel(gtkThemesLight),
                selected: this._getSelectedIndexLight(preferences, color, gtkThemesLight)
            });
            row.connect('notify::selected', () => {
                const selected = gtkThemesLight[row.selected];
                preferences.set_string(`${color}-theme-light`, selected);
            });
            ThemeGroupLight.add(row);
        });
        // Add custom dark theme selection group
        const ThemeGroupDark = new Adw.PreferencesGroup({
            title: _('Custom Gtk Themes Dark'),
            description: _('Select custom gtk themes for each accent color'),
        });
        page.add(ThemeGroupDark);
        // Get available gtk themes
        const gtkThemesDark = this._getAvailableGtkThemes();
        // Create dropdown for each accent color
        const accentColorsDark = [
            'blue', 'teal', 'green', 'yellow',
            'orange', 'red', 'pink', 'purple', 'slate'
        ];
        accentColorsDark.forEach(color => {
            const row = new Adw.ComboRow({
                title: _(color.charAt(0).toUpperCase() + color.slice(1)),
                model: this._createGtkThemeModel(gtkThemesDark),
                selected: this._getSelectedIndexDark(preferences, color, gtkThemesDark)
            });
            row.connect('notify::selected', () => {
                const selected = gtkThemesDark[row.selected];
                preferences.set_string(`${color}-theme-dark`, selected);
            });
            ThemeGroupDark.add(row);
        });
        window.add(page);
        preferences.bind('set-link-gtk4', setLinkGTK4, 'active', Gio.SettingsBindFlags.DEFAULT);
        return Promise.resolve();
    }

    // Next method load the themes in declarated dirs and return the list with themes
    _getAvailableGtkThemes() {
        const themes = new Set();
        const directories = [
            '/usr/local/share/themes',
            '/usr/share/themes',
            GLib.get_home_dir() + '/.local/share/themes',
            GLib.get_home_dir() + '/.themes'
        ];
        // Scan directories for gtk themes
        directories.forEach(dir => {
            if (GLib.file_test(dir, GLib.FileTest.IS_DIR)) {
                const directory = Gio.File.new_for_path(dir);
                const enumerator = directory.enumerate_children('standard::*', Gio.FileQueryInfoFlags.NONE, null);
                let info;
                while ((info = enumerator.next_file(null))) {
                    const path = dir + '/' + info.get_name();
                    if (this._isValidGtkTheme(path)) {
                        themes.add(info.get_name());
                    }
                }
            }
        });
        return Array.from(themes).sort();
    }

    // Next method is used to check if in a path exist a theme (check if index.theme file exist)
    _isValidGtkTheme(path) {
        return GLib.file_test(path + '/index.theme', GLib.FileTest.EXISTS);
    }

    // Next return a list with themes
    _createGtkThemeModel(themes) {
        return new Gtk.StringList({ strings: themes });
    }

    // Next method return theme selected used for Ligh scheme
    _getSelectedIndexLight(preferences, color, themes) {
        const savedTheme = preferences.get_string(`${color}-theme-light`);
        const theme = savedTheme;
        return Math.max(0, themes.indexOf(theme));
    }
    
    // Next method return theme selected used for Dark scheme
    _getSelectedIndexDark(preferences, color, themes) {
        const savedTheme = preferences.get_string(`${color}-theme-dark`);
        const theme = savedTheme;
        return Math.max(0, themes.indexOf(theme));
    }

    // Next method return the path stored in schema and used for set the link to gtk4 config local
    _getPathTheme(preferences) {
        const savedPath = preferences.get_string('set-theme-path');
        return savedPath;
    }
}
