# Settings

The following document contains more detailed reproducible application settings and instructions to replicate some of the desired [configuration](configuration.md) of the liveCD.

## Desktop Environment

### Extensions

Enable every extension from the [configuration](configuration.md#shell). The three `accent-*@brgvos` extensions make the GTK, Shell and icon themes follow the accent color (see [Theming](#theming)):

```bash
for e in arcmenu@arcmenu.com dash-to-panel@jderose9.github.com ding@rastersoft.com ubuntu-appindicators@ubuntu.com user-theme@gnome-shell-extensions.gcampax.github.com noannoyance-fork@vrba.dev tiling-assistant@leleat-on-github gsconnect@andyholmes.github.io accent-user-theme@brgvos accent-gtk-theme@brgvos accent-icons-theme@brgvos; do gnome-extensions enable "$e"; done
```

Reference: [`00-shell-extensions`](../overlays/Desktop%20Environment/filesystem/live_installed/etc/dconf/db/desktop.d/00-shell-extensions)

### Theming

Dark style with a yellow accent:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface accent-color 'yellow'
```

Reference: [`01-theming.overlay.tmpl`](../overlays/Desktop%20Environment+Theming/filesystem/live_installed/etc/dconf/db/desktop.d/01-theming.overlay.tmpl)

#### Wallpapers

The light theme uses [Milad Fakurian's photo](https://unsplash.com/photos/a-close-up-of-a-circular-object-with-a-blurry-background-7Ra7YDFR4Pw) and the dark theme uses [Heber Davis's photo](https://unsplash.com/photos/a-black-and-white-photo-of-a-curved-wall-ewW6dPCL_Vw), both from Unsplash. Download and select them with:

```bash
mkdir -p ~/Pictures/Wallpapers
curl -L "https://unsplash.com/photos/7Ra7YDFR4Pw/download?force=true" -o ~/Pictures/Wallpapers/light.jpg
curl -L "https://unsplash.com/photos/ewW6dPCL_Vw/download?force=true" -o ~/Pictures/Wallpapers/dark.jpg
gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/light.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/Pictures/Wallpapers/dark.jpg"
```

Reference: [`01-theming.overlay.tmpl`](../overlays/Desktop%20Environment+Theming/filesystem/live_installed/etc/dconf/db/desktop.d/01-theming.overlay.tmpl), [`ATTRIBUTIONS.txt`](../overlays/Desktop%20Environment+Theming/filesystem/live_installed/usr/share/backgrounds/ATTRIBUTIONS.txt)

#### GTK and Shell theme

The theme is [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme), built from the commit the overlay pins (the optional window button step below targets that version's CSS) with the options from `overlays/Desktop Environment+Theming/config.yaml`: the Monterey variant, the Nord scheme and solid opacity. Install it system-wide, then select it for legacy GTK applications and the Shell:

```bash
sudo apt install curl sassc libglib2.0-dev-bin libxml2-utils
git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git
cd WhiteSur-gtk-theme
git checkout d5782652d412137e26fb8ff55b55a5572e4c6995
sudo ./install.sh --monterey --scheme nord --opacity solid --theme all
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark-solid-yellow-nord'
gsettings set org.gnome.shell.extensions.user-theme name 'WhiteSur-Dark-solid-yellow-nord'
```

Reference: [`2700-install-whitesur-theme.hook.chroot.overlay.tmpl`](../overlays/Desktop%20Environment+Theming/lb/hooks/normal/2700-install-whitesur-theme.hook.chroot.overlay.tmpl), [`config.yaml`](../overlays/Desktop%20Environment+Theming/config.yaml), [`themes.yaml`](../overlays/Desktop%20Environment+Theming/packages/themes.yaml), [`01-theming.overlay.tmpl`](../overlays/Desktop%20Environment+Theming/filesystem/live_installed/etc/dconf/db/desktop.d/01-theming.overlay.tmpl)

The Shell theme needs the User Themes extension enabled.

#### Window buttons (optional)

WhiteSur draws its window buttons as macOS-style images. This optional step appends CSS to every installed WhiteSur theme to replace them with customized GNOME-style symbolic buttons.

```bash
cat > /tmp/titlebuttons-gtk3.css <<'EOF'
/* Replaces WhiteSur's PNG window buttons with GNOME-style symbolic window buttons for GTK 3.
 * Adapted from Colloid's "normal" window buttons (vinceliuice/Colloid-gtk-theme, --tweaks normal),
 * with Colloid's fixed light-theme colours swapped for currentColor so one file fits light and dark.
*/
button.titlebutton:not(.suggested-action):not(.destructive-action) {
  min-height: calc(22px * 1.2); /* Special change to increase button size */
  min-width: calc(22px * 1.2); /* Special change to increase button size */
  padding: 0;
  margin: 0 4px;
}

headerbar button.titlebutton.minimize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.maximize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.close:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: alpha(currentColor, 0.75); /* WhiteSur hides the symbolic icon with color: transparent */
  background-image: none; /* Drops WhiteSur's titlebutton PNGs */
  background-color: alpha(currentColor, 0.1);
  border-radius: 100%;
  box-shadow: none;
}

headerbar button.titlebutton.minimize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) image,
headerbar button.titlebutton.maximize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) image,
headerbar button.titlebutton.close:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) image {
  -gtk-icon-transform: scale(1.2); /* Special change to increase button size */
}

headerbar button.titlebutton.minimize:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.maximize:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.close:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: currentColor;
  background-color: alpha(currentColor, 0.15);
}

headerbar button.titlebutton.minimize:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.maximize:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.close:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: currentColor;
  background-color: alpha(currentColor, 0.2);
}

headerbar button.titlebutton.minimize:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.maximize:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
headerbar button.titlebutton.close:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  opacity: 0.65;
}
EOF
cat > /tmp/titlebuttons-gtk4.css <<'EOF'
/* Replaces WhiteSur's PNG window buttons with GNOME-style symbolic window buttons for GTK 4.
 * Adapted from Colloid's "normal" window buttons (vinceliuice/Colloid-gtk-theme, --tweaks normal).
*/
windowcontrols > button:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  min-height: calc(22px * 1.2); /* Special change to increase button size */
  min-width: calc(22px * 1.2); /* Special change to increase button size */
  padding: 6px 0;
  margin-left: 4px;
  margin-right: 4px;
}

windowcontrols > button.minimize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.maximize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.close:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: alpha(currentColor, 0.75);
  background: none; /* Drops WhiteSur's titlebutton PNGs */
  box-shadow: none;
}

windowcontrols > button.minimize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image,
windowcontrols > button.maximize:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image,
windowcontrols > button.close:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image {
  color: inherit; /* WhiteSur hides the symbolic icon with color: transparent */
  -gtk-icon-transform: scale(1.2); /* Special change to increase button size */
  min-height: calc(16px * 1.2); /* Special change to increase button size */
  min-width: calc(16px * 1.2); /* Special change to increase button size */
  padding: 0;
  border-radius: 100%;
  background-color: alpha(currentColor, 0.1);
  transition: background 200ms cubic-bezier(0.25, 0.46, 0.45, 0.94);
}

windowcontrols > button.minimize:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.maximize:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.close:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.minimize:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.maximize:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.close:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: currentColor;
}

windowcontrols > button.minimize:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image,
windowcontrols > button.maximize:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image,
windowcontrols > button.close:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image {
  background-color: alpha(currentColor, 0.15);
}

windowcontrols > button.minimize:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image,
windowcontrols > button.maximize:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image,
windowcontrols > button.close:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) > image {
  background-color: alpha(currentColor, 0.2);
}

windowcontrols > button.minimize:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.maximize:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque),
windowcontrols > button.close:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  opacity: 0.65;
}

/* Override for Chromium.
Chromium draws its own caption buttons from this style path, outside windowcontrols. */
window.background.chromium headerbar.header-bar.titlebar button.titlebutton:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  min-height: 22px;
  min-width: 22px;
  padding: 0;
  border-radius: 100%;
  color: alpha(currentColor, 0.75);
  background-color: alpha(currentColor, 0.1);
}

window.background.chromium headerbar.header-bar.titlebar button.titlebutton:hover:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: currentColor;
  background-color: alpha(currentColor, 0.15);
}

window.background.chromium headerbar.header-bar.titlebar button.titlebutton:active:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  color: currentColor;
  background-color: alpha(currentColor, 0.2);
}

window.background.chromium headerbar.header-bar.titlebar button.titlebutton:backdrop:not(.raised):not(.suggested-action):not(.destructive-action):not(.opaque) {
  opacity: 0.65;
}
EOF
for css in /usr/share/themes/WhiteSur-*/gtk-[34].0/gtk*.css; do
    case "$css" in
        */gtk-3.0/*) sudo tee -a "$css" < /tmp/titlebuttons-gtk3.css > /dev/null ;;
        *) sudo tee -a "$css" < /tmp/titlebuttons-gtk4.css > /dev/null ;;
    esac
done
```

Reference: [`whitesur-titlebuttons-gtk3.css`](../overlays/Desktop%20Environment+Theming/lb/hooks/normal/scripts/whitesur-titlebuttons-gtk3.css), [`whitesur-titlebuttons-gtk4.css`](../overlays/Desktop%20Environment+Theming/lb/hooks/normal/scripts/whitesur-titlebuttons-gtk4.css), [`2700-install-whitesur-theme.hook.chroot.overlay.tmpl`](../overlays/Desktop%20Environment+Theming/lb/hooks/normal/2700-install-whitesur-theme.hook.chroot.overlay.tmpl)

#### Icons

Install the [Colloid](https://github.com/vinceliuice/Colloid-icon-theme) icon themes. This particular liveCD installs the `colloid-icon-theme` package via a pinned Ubuntu Budgie backports PPA, but you may also manually install it using the script from GitHub:

```bash
git clone https://github.com/vinceliuice/Colloid-icon-theme.git
cd Colloid-icon-theme
sudo ./install.sh --theme all
gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Yellow-Dark'
```

Reference: [`colloid.yaml`](../overlays/Desktop%20Environment+Theming/repos/colloid.yaml), [`96-allow-only-colloid-icons.pref`](../overlays/Desktop%20Environment+Theming/repos/96-allow-only-colloid-icons.pref), [`themes.yaml`](../overlays/Desktop%20Environment+Theming/packages/themes.yaml), [`01-theming.overlay.tmpl`](../overlays/Desktop%20Environment+Theming/filesystem/live_installed/etc/dconf/db/desktop.d/01-theming.overlay.tmpl)

The `accent-*@brgvos` extensions normally switch the GTK, Shell and icon themes to follow the accent, so the three `gsettings` theme commands above only set the yellow dark result by hand.

### Shell

Assuming the [Dash to Panel](https://extensions.gnome.org/extension/1160/dash-to-panel/) and [ArcMenu](https://extensions.gnome.org/extension/3628/arcmenu/) extensions are installed, these `gsettings` commands are used to achieve the following configuration:

- The Activities and Show Apps buttons are hidden, with the taskbar on the left, and the system menu, date menu and show-desktop button on the right.
- ArcMenu uses the Redmond layout with the search bar at the bottom, a square avatar, and `bookmarks`, `external devices`, `open windows` and `recent files` enabled.
- Windows are set to display minimize, maximize and close buttons, as GNOME defaults to a close button only.

```bash
# Extension schemas are read from each extension's own folder, as they may not be installed system-wide
EXT=/usr/share/gnome-shell/extensions
DTP="gsettings --schemadir $EXT/dash-to-panel@jderose9.github.com/schemas set org.gnome.shell.extensions.dash-to-panel"
ARC="gsettings --schemadir $EXT/arcmenu@arcmenu.com/schemas set org.gnome.shell.extensions.arcmenu"

# Keyed by monitor index (0, 1, 2) since monitor ids are hardware specific
L='[{"element":"showAppsButton","visible":false,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"stackedTL"},{"element":"centerBox","visible":true,"position":"stackedBR"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]'
$DTP panel-element-positions "{\"0\":$L,\"1\":$L,\"2\":$L}"

$ARC menu-layout 'Redmond'
$ARC searchbar-default-top-location 'Bottom'
$ARC avatar-style 'Square'
$ARC show-bookmarks true
$ARC show-external-devices true
$ARC search-provider-open-windows true
$ARC search-provider-recent-files true

gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
```

Reference: [`03-dash-to-panel`](../overlays/Desktop%20Environment+Shell/filesystem/live_installed/etc/dconf/db/desktop.d/03-dash-to-panel), [`05-arcmenu`](../overlays/Desktop%20Environment+Shell/filesystem/live_installed/etc/dconf/db/desktop.d/05-arcmenu), [`07-window-buttons`](../overlays/Desktop%20Environment+Shell/filesystem/live_installed/etc/dconf/db/desktop.d/07-window-buttons)

Since Debian's `gnome-shell-extension-arc-menu` 65-2 package omits this CSS file, we must reintroduce it by saving it as `/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com/stylesheet.css`:

```bash
sudo tee /usr/share/gnome-shell/extensions/arcmenu@arcmenu.com/stylesheet.css <<'EOF'
/*
 * Unmodified stylesheet.css from upstream ArcMenu v65 (https://gitlab.com/arcmenu/ArcMenu/-/blob/v65/stylesheet.css).
 * Debian's gnome-shell-extension-arc-menu 65-2 omits this file.
 * Remove this file if the Debian package ships its own copy.
*/

.ArcMenuIconGrid {
    text-align: center;
    border-radius: 8px;
    padding: 5px;
    spacing: 0px;
    margin: 0px;
}

.ArcMenuGroupFolder{
    border: 2px solid rgba(0, 0, 0, 0);
}

.ArcMenuIconGrid:drop {
    box-shadow: inset 0px 0px 0px 2px rgba(53, 132, 228, 0.8);
    background-color: rgba(53, 132, 228, 0.2);
}

.arcmenu-menu-item:drop {
    box-shadow: inset 0px 0px 0px 2px rgba(53, 132, 228, 0.8);
    background-color: rgba(53, 132, 228, 0.2);
}

.folder-header {
    font-weight: 800;
    font-size: 16px;
}

.arcmenu-folder-dialog {
    border-width: 2px;
}

.folder-name-container{
    spacing: 12px;
}

.bottomOfScreenMenu{
    margin-bottom: 0px;
}

.arcmenu-search-entry{
    min-height: 0px;
    border-width: 1px;
    padding: 7px 9px;
}

.arcmenu-search-top{
    margin: 0px 0px 6px 0px;
}

.arcmenu-search-bottom{
    margin: 6px 0px 0px 0px;
}

.symbolic-icons{
    -st-icon-style: symbolic;
}
.regular-icons{
    -st-icon-style: regular;
}

.arcmenu-menu-item{
    padding-top: 6px;
    padding-bottom: 6px;
}

.arcmenu-plasma-button{
    width: 90px;
    height: 65px;
    border-radius: 8px;
    text-align: center;
    padding: 5px;
    spacing: 0px;
    margin: 0px;
}

.small-vfade{
    -st-vfade-offset: 44px;
}

.arcmenu-margin-box{
    margin: 0px 6px;
}

.arcmenu-button{
    -st-icon-style: symbolic;
    border-width: 1px;
    border-radius: 8px;
    padding: 8px;
    min-height: 0px;
}

.arcmenu-small-button {
    border-radius: 8px;
    padding: 1px 6px;
    min-height: auto;
}

.arcmenu-avatar-round{
    background-size: contain;
    border-radius: 999px;
}
.arcmenu-avatar-square{
    background-size: contain;
    border-radius: 0px;
}

.arcmenu-tooltip{
    border: 1px solid rgba(255, 255, 255, 0.25);
    padding: 4px 10px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.1);
    max-width: 400px;
    min-height: 0px;
}

/* Recently Installed App Indicator on parent category */
/*
.arcmenu-indicator{
    color: rgb(41, 165, 249);
}
*/

/* Recently Installed App Indicator Text */
.arcmenu-text-indicator{
    font-size: small;
    border-radius: 8px;
    background-color: rgba(255, 255, 255, 0.1);
    margin: 0px; 
    padding: 0px 10px;
}
EOF
```

Reference: [`stylesheet.css`](../overlays/Desktop%20Environment+Shell/filesystem/live_installed/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com/stylesheet.css)

### Thumbnailers

[ffmpegthumbnailer](https://github.com/dirkvdb/ffmpegthumbnailer) already thumbnails video files. More media can be thumbnailed by registering a thumbnailer entry for it, and this snippet does that for the embedded cover art of audio files:

```bash
sudo apt install ffmpegthumbnailer
sudo tee /usr/share/thumbnailers/ffmpegthumbnailer-audio.thumbnailer <<'EOF'
[Thumbnailer Entry]
TryExec=ffmpegthumbnailer
Exec=ffmpegthumbnailer -i %i -o %o -s %s -m
MimeType=audio/mpeg;audio/flac;audio/mp4;audio/x-m4b;audio/aac;audio/ogg;audio/x-vorbis+ogg;audio/x-opus+ogg;audio/x-flac+ogg;audio/x-ms-wma;audio/x-ape;audio/x-wavpack;audio/x-musepack;audio/x-aiff;audio/vnd.wave;audio/x-dsf;audio/x-matroska;audio/webm;
EOF
```

Reference: [`ffmpegthumbnailer-audio.thumbnailer`](../overlays/Desktop%20Environment+Thumbnailers/filesystem/live_installed/usr/share/thumbnailers/ffmpegthumbnailer-audio.thumbnailer), [`thumbnailers.yaml`](../overlays/Desktop%20Environment+Thumbnailers/packages/thumbnailers.yaml)

Clear the thumbnail cache (`rm -r ~/.cache/thumbnails`) to regenerate previews that were already attempted.

### Tweaks

The `gnome-shell-extensions-prefs` configuration is as follows:

```bash
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.sound theme-name 'freedesktop'
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.interface font-name 'Inter 10'
gsettings set org.gnome.desktop.interface document-font-name 'Sans 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Bold 10'
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
gsettings set org.gnome.desktop.interface font-hinting 'medium'
gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
gsettings set org.gnome.desktop.input-sources show-all-sources false
gsettings set org.gnome.desktop.interface gtk-key-theme 'Default'
gsettings set org.gnome.mutter overlay-key 'Super_L'
gsettings set org.gnome.desktop.interface locate-pointer false
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'fingers'
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'default'
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.calendar show-weekdate false
gsettings set org.gnome.desktop.wm.preferences action-double-click-titlebar 'toggle-maximize'
gsettings set org.gnome.desktop.wm.preferences action-middle-click-titlebar 'none'
gsettings set org.gnome.desktop.wm.preferences action-right-click-titlebar 'menu'
gsettings set org.gnome.mutter attach-modal-dialogs true
gsettings set org.gnome.mutter center-new-windows false
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button false
gsettings set org.gnome.desktop.wm.preferences mouse-button-modifier '<Super>'
gsettings set org.gnome.desktop.wm.preferences focus-mode 'click'
gsettings set org.gnome.desktop.wm.preferences auto-raise false
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent false
```


## File Manager

### Nautilus

Install [nautilus-admin](https://github.com/brunonova/nautilus-admin) to maintain the "Open as Root" feature in Nautilus. If you are using an alternative default text editor and do not wish to include `gedit`, you may run the following command:

```bash
sudo apt install --no-install-recommends nautilus-admin
```

Reference: [`2950-install-nautilus-admin-no-recommends.hook.chroot.overlay.tmpl`](../overlays/File%20Manager/lb/hooks/normal/2950-install-nautilus-admin-no-recommends.hook.chroot.overlay.tmpl)

## Terminal

Ghostty reads its configuration from `~/.config/ghostty/config.ghostty`. Use the commands below to apply the configuration:

```bash
mkdir -p ~/.config/ghostty
tee ~/.config/ghostty/config.ghostty <<'EOF'
# palette=1 (Tango); colorset1: foreground rgb(192,192,192), background black, cursor white
theme = Builtin Tango Dark
foreground = #c0c0c0
# Sakura highlights selections in reverse video instead of the theme's light blue
selection-background =
selection-foreground =

# blinking_cursor=No. `no-cursor` keeps the shell integration from switching to a blinking bar at the prompt.
cursor-style-blink = false
shell-integration-features = no-cursor

# Conservatively add color for user@host and prevent xterm-ghostty terminfo
term = xterm-256color
EOF
```

Reference: [`config.ghostty`](../overlays/Terminal/filesystem/live_installed/etc/skel/.config/ghostty/config.ghostty)

The specific Ghostty Debian package for this liveCD does not register itself as the default terminal, which is what applications such as Nautilus' "Open in Terminal" launch. Register it as `x-terminal-emulator`, with priority 50 to outrank gnome-terminal (40):

```bash
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ghostty 50 \
    --slave /usr/share/man/man1/x-terminal-emulator.1.gz x-terminal-emulator.1.gz /usr/share/man/man1/ghostty.1.gz
```

Reference: [`2900-register-ghostty-terminal.hook.chroot.overlay.tmpl`](../overlays/Terminal/lb/hooks/normal/2900-register-ghostty-terminal.hook.chroot.overlay.tmpl)

## Text Editor

elementary Code is installed via the [elementary Stable PPA](https://launchpad.net/~elementary-os/+archive/ubuntu/stable).

To ensure the underlying editor color scheme (GtkSourceView) aligns with our current GTK theme, a `theme_sync` plugin is provided ("GTK Theme Colors" under Preferences > Extensions). On each start it regenerates the user's `elementary-light`/`elementary-dark` editor schemes from the current GTK theme's colors, so turning it off there restores the stock look on the next start.

The plugin is not part of elementary Code, so you may install it by writing these two files into Code's plugin folder and enabling it.

```bash
sudo mkdir -p /usr/lib/x86_64-linux-gnu/io.elementary.code/plugins/theme-sync
sudo tee /usr/lib/x86_64-linux-gnu/io.elementary.code/plugins/theme-sync/theme-sync.plugin <<'EOF'
[Plugin]
Module=theme_sync
Loader=python
IAge=2
Name=GTK Theme Colors
Description=Matches the editor colors to the GTK theme when Code starts
Website=https://github.com/cnshing/debian-livecd
EOF
sudo tee /usr/lib/x86_64-linux-gnu/io.elementary.code/plugins/theme-sync/theme_sync.py <<'EOF'
'''
Ensures the underlying editor theme is consistent with the current GTK theme.
Regenerates the user's elementary-light/dark editor schemes on launch.
Note: Colors are re-read only at startup; any theme change that occurs while Code is running will require a restart.
'''

'''
This module assumes it is run before the color scheme is read at MainWindow's init_layout(), and it currently does that at libpeas import while the PluginsManager is created.
'''


import os
import re
import subprocess
import sys

STOCK = "/usr/share/gtksourceview-4/styles/elementary-%s.xml"
DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
DATA_DIRS = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
OUT_DIR = os.path.join(DATA_HOME, "gtksourceview-4", "styles")


def theme_css(name, filename):
    for d in [os.path.join(DATA_HOME, "themes"), os.path.expanduser("~/.themes")] + [os.path.join(d, "themes") for d in DATA_DIRS]:
        path = os.path.join(d, name, "gtk-3.0", filename)
        if os.path.isfile(path):
            with open(path) as f:
                return f.read()
    return None


def parse_color(value):
    # NOTE: hex, rgb()/rgba() and white/black only; anything else (@refs, shade(), other names) returns None and that variant falls back to the stock scheme.
    value = {"white": "#ffffff", "black": "#000000"}.get(value.lower(), value)
    m = re.fullmatch(r"#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})", value)
    if m:
        h = m.group(1) if len(m.group(1)) == 6 else "".join(c * 2 for c in m.group(1))
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    m = re.fullmatch(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,[^)]*)?\)", value)
    return tuple(min(int(v), 255) for v in m.groups()) if m else None


def theme_colors(css):
    colors = {}
    for key in ("base", "bg", "fg"):
        m = re.search(r"@define-color\s+theme_%s_color\s+([^;]+);" % key, css or "")
        rgb = parse_color(m.group(1).strip()) if m else None
        if rgb is None:
            return None
        colors[key] = "#%02x%02x%02x" % rgb
        colors[key + "_dark"] = (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255 < 0.5
    return colors


def write_scheme(variant, colors):
    path = os.path.join(OUT_DIR, "elementary-%s.xml" % variant)
    if colors is None:
        if os.path.exists(path):
            os.remove(path)  # fall back to the stock scheme
        return
    # Syntax colors come from the stock scheme that suits the background to ensure a dark-only theme still gets readable text in "light" mode.
    with open(STOCK % ("dark" if colors["base_dark"] else "light")) as f:
        xml = f.read()
    xml = re.sub(r'id="elementary-[a-z]+"', 'id="elementary-%s"' % variant, xml, count=1)
    xml = re.sub(r'(<style name="text"\s+foreground=)"[^"]*" background="[^"]*"',
                 r'\1"%s" background="%s"' % (colors["fg"], colors["base"]), xml)
    xml = re.sub(r'(<style name="(?:current-line|background-pattern)"\s+background=)"[^"]*"',
                 r'\1"%s"' % colors["bg"], xml)
    xml = re.sub(r'(<style name="line-numbers"\s+foreground="[^"]*" background=)"[^"]*"',
                 r'\1"%s"' % colors["bg"], xml)
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(path + ".tmp", "w") as f:
        f.write(xml)
    os.replace(path + ".tmp", path)


def sync_schemes():
    name, _, env_variant = os.environ.get("GTK_THEME", "").partition(":")
    if not name:
        r = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                           capture_output=True, text=True)
        name = r.stdout.strip().strip("'") if r.returncode == 0 else ""
    # Mirror GTK: the dark variant loads gtk-dark.css when the theme has one, else gtk.css.
    light_css = theme_css(name, "gtk.css") if name else None
    dark_css = (theme_css(name, "gtk-dark.css") if name else None) or light_css
    if os.environ.get("GTK_THEME"):  # GTK_THEME pins the variant; prefer-dark is ignored
        light_css = dark_css = dark_css if env_variant == "dark" else light_css
    write_scheme("light", theme_colors(light_css))
    write_scheme("dark", theme_colors(dark_css))


def _on_plugins_changed(settings, key):
    # Disabled in Preferences > Extensions: drop the generated schemes so the stock
    # look returns on the next start.
    if "theme_sync" not in settings.get_strv(key):
        write_scheme("light", None)
        write_scheme("dark", None)


try:
    sync_schemes()
    from gi.repository import Gio  # already imported by libpeas' Python loader
    _settings = Gio.Settings.new("io.elementary.code.settings")  # keep a reference
    _settings.connect("changed::plugins-enabled", _on_plugins_changed)
except Exception as e:  # never break Code's startup
    print("theme_sync plugin: skipped: %s" % e, file=sys.stderr)
EOF
gsettings set io.elementary.code.settings plugins-enabled "['brackets-completion', 'detect-indent', 'editorconfig', 'theme_sync']"
```

Reference: [`theme-sync.plugin`](../overlays/Text%20Editor/filesystem/live_installed/usr/lib/x86_64-linux-gnu/io.elementary.code/plugins/theme-sync/theme-sync.plugin), [`theme_sync.py`](../overlays/Text%20Editor/filesystem/live_installed/usr/lib/x86_64-linux-gnu/io.elementary.code/plugins/theme-sync/theme_sync.py), [`06-elementary-code`](../overlays/Text%20Editor/filesystem/live_installed/etc/dconf/db/desktop.d/06-elementary-code)

## Audio Effects

To ensure [Easy Effects](https://github.com/wwmm/easyeffects) is always running in the background, a manually created `easyeffects.service` is enabled for every non-system user:

```bash
sudo tee /etc/systemd/user/easyeffects.service <<'EOF'
[Unit]
Description=Easy Effects
PartOf=graphical-session.target
After=graphical-session.target
ConditionUser=!@system

[Service]
ExecStart=/usr/bin/easyeffects --gapplication-service
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
sudo systemctl --global enable easyeffects.service
```

Reference: [`easyeffects.service`](../overlays/Audio%20Effects/filesystem/live_installed/etc/systemd/user/easyeffects.service), [`2810-enable-easyeffects.hook.chroot.overlay.tmpl`](../overlays/Audio%20Effects/lb/hooks/normal/2810-enable-easyeffects.hook.chroot.overlay.tmpl)

AutoEQ community headphone presets are built from the [OPRA](https://github.com/opra-project/OPRA) database with `overlays/Audio Effects/lb/hooks/normal/scripts/opra2ee.py`. It is a script that fetches all the parametric EQ data for Harman, matching IE 2019 or OE 2018 depending on whether the device is in-ear or over-ear, respectively.

```bash
curl -fsSL https://opra.roonlabs.net/database_v1.jsonl -o database_v1.jsonl
sudo python3 opra2ee.py database_v1.jsonl /usr/share/easyeffects/output/OPRA
```

Reference: [`opra2ee.py`](../overlays/Audio%20Effects/lb/hooks/normal/scripts/opra2ee.py), [`2800-install-opra-presets.hook.chroot.overlay.tmpl`](../overlays/Audio%20Effects/lb/hooks/normal/2800-install-opra-presets.hook.chroot.overlay.tmpl)

## AppImages

Open [Gear Lever](https://github.com/mijorus/gearlever)'s preferences and set the default AppImages folder to `~/AppImages`.

Gear Lever only adds an application when the user approves it in its app or opens an AppImage with it. To integrate any new `.AppImage` placed into that folder automatically, a daemon must watch the folder and hand each new file to Gear Lever.

Reference: [`keyfile.overlay.tmpl`](../overlays/AppImages/filesystem/live_installed/etc/skel/.var/app/it.mijorus.gearlever/config/glib-2.0/settings/keyfile.overlay.tmpl), [`watch-appimages.path.overlay.tmpl`](../overlays/AppImages/filesystem/live_installed/etc/systemd/user/watch-appimages.path.overlay.tmpl), [`watch-appimages.service.overlay.tmpl`](../overlays/AppImages/filesystem/live_installed/etc/systemd/user/watch-appimages.service.overlay.tmpl), [`watch-appimages.tmpl`](../overlays/AppImages/filesystem/live_installed/usr/local/libexec/watch-appimages.tmpl), [`2600-enable-watch-appimages.hook.chroot.overlay.tmpl`](../overlays/AppImages/lb/hooks/normal/2600-enable-watch-appimages.hook.chroot.overlay.tmpl)

## Networking

`network-manager-config-connectivity-debian` needs to be installed alongside NetworkManager so captive portals (e.g. public Wi-Fi sign-in pages) are detected.

Reference: [`networkmanager.yaml`](../overlays/Networking/packages/networkmanager.yaml)

## Remote Desktop

Enable GNOME's RDP, or Settings > System > Remote Desktop, with control allowed:

```bash
gsettings set org.gnome.desktop.remote-desktop.rdp enable true
gsettings set org.gnome.desktop.remote-desktop.rdp negotiate-port true
gsettings set org.gnome.desktop.remote-desktop.rdp view-only false
```

Reference: [`02-gnome-rdp`](../overlays/Remote%20Desktop/filesystem/live_installed/etc/dconf/db/desktop.d/02-gnome-rdp)
