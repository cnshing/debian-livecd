# Configuration

The following document describes all the high level configurations of the liveCD.

## AppImages

AppImages will replace packages not available through the Debian repositories in the `$HOME/AppImages` directory.

Managing and integrating these AppImages into the desktop environment will be up to [Gear Lever](https://github.com/mijorus/gearlever), where it will be configured to look for them in `$HOME/AppImages`.

## Audio Effects

Ideally, there should be an application that automatically applies an [AutoEQ](https://autoeq.app/) filter for whatever audio device you happen to listen on. Since there isn't any such application yet, [EasyEffects](https://github.com/wwmm/easyeffects) should be installed along with built-in AutoEQ presets for various devices, specifically targeting Harman IE 2019/OE 2018 so the user can at least quickly select a Parametric EQ.

## Battery Management

[TLP](https://github.com/linrunner/TLP) will be used to optimize battery with performance. Preferentially, any laptop devices should use full computing power when charging and switch to power-saving mode within `0%` - `40%` battery thresholds.

### NVIDIA Optimus

If possible, there should be a separate boot entry from the standard one that explicitly enables screen rendering from a dedicated GPU, allowing the user to choose which use-case is most appropriate for their battery and performance needs.

## Browser

There will be [Firefox](https://www.mozilla.org/en-US/firefox/browsers/), [Google Chrome](https://www.google.com/chrome/), and [Ungoogled Chromium](https://ungoogled-software.github.io/) all of whom will share the same extensions listed below.

### Password Management

Both [Bitwarden](https://bitwarden.com/) and [Proton Pass](https://proton.me/pass) will be installed by default for password management.

### Ad blocking

[UBlock Origin](https://ublockorigin.com/) will be installed by default for ad blocking. UBlock Origin Lite may be alternatively installed for browsers without Manifest V2 support. 

## Display Manager

[GDM3](https://gitlab.gnome.org/GNOME/gdm) will be the display manager using the default GTK [theme](#theming) and [Wayland](https://wayland.freedesktop.org/) protocol.

## Desktop Environment

[GNOME](https://www.gnome.org/) will be our desktop environment with extensions to support the below functionalities:
 
### Phone Sync

With [GSConnect](https://extensions.gnome.org/extension/1319/gsconnect/), a GNOME [KDEConnect](https://kdeconnect.kde.org/) implementation, installed and automatically enabled, users can pair and sync communications with the liveCD.

### System Monitor

[Mission Center](https://missioncenter.io/) should be installed to monitor CPU, memory, drives, network, GPU, fans and battery.

### Shell

The desktop shell should traditionally include a [start menu](https://extensions.gnome.org/extension/3628/arcmenu/), an application [taskbar](https://extensions.gnome.org/extension/1160/dash-to-panel/), [system tray](https://extensions.gnome.org/extension/615/appindicator-support/) and [desktop icons](https://extensions.gnome.org/extension/2087/desktop-icons-ng-ding/) support.

### Theming

Enable the User Themes GNOME extension and [gnome-tweaks](https://gitlab.gnome.org/GNOME/gnome-tweaks). Then install the WhiteSur [desktop](https://github.com/vinceliuice/WhiteSur-gtk-theme), Colloid [icon](https://github.com/vinceliuice/Colloid-icon-theme), and [colibre](https://packages.debian.org/stable/libreoffice-style-colibre) LibreOffice theme.

Any desktop wallpaper artwork should be encoded to AVIF at quality 92 from the highest-quality, full-resolution version available, whose files are separated by artist name under `/usr/share/backgrounds`.
Additionally, each photo should be properly attributed under `/usr/share/backgrounds/ATTRIBUTIONS.txt`, crediting each artist and photo.

### Thumbnailers

Content based files should always have a preview thumbnail.

### Tweaks

`gnome-shell-extension-prefs` should be installed with these gsettings [configuration](settings.md#tweaks).

Additionally, the "Window is ready" popup whenever any application opens should be disabled. Extensions accomplishing this are usually initially developed and created only to be subsequently unmaintained with each new GNOME version. The current extension for GNOME 45 would be [NoAnnoyance](https://extensions.gnome.org/extension/6109/noannoyance-fork/).

[comment - Always update this section's current working extension for "Window is ready" for the liveCD's current version]: #

### Window Tiling

Applications should be able to be tiled to the top, bottom, left, and right halves of the screen identically to Window snap tiles via [WinTile](https://extensions.gnome.org/extension/1723/wintile-windows-10-window-tiling-for-gnome/). Alternatively, if this package is not readily available through Debian's repository, you may use [Tiling Assistant](https://extensions.gnome.org/extension/3733/tiling-assistant/).

## File Manager

There are some instances with GTK File Picker where it is hard coded such that only Gnome's [Nautilus](https://github.com/GNOME/nautilus) file manager can be opened, regardless of any other default file manager in the system. To remedy this there will be a primary file manager, [Thunar](https://gitlab.xfce.org/xfce/thunar), for daily use and a secondary file manager used for any situation where the primary file manager cannot be used. 

[comment - Make an explicit reference to the GNOME section in the future]: #

## Flatpaks

Any packages not conveniently available as an AppImage or Debian package may use Flatpaks as an alternative source.

## Networking

[NetworkManager](https://networkmanager.dev/) is sufficient for Internet with ease of use and GNOME integration. 

### VPN

VPNs should be supported via [GNOME](#desktop-environment) with as many VPN plugins and/or VPN format compatibilities as reasonably possible. 

## Mail Client

Each mail service should be accompanied by corresponding web-app based client. In practice, these web-app implementations are often based off Electron.

## Miscellaneous

This section is for features which are technically useful but provides a less tangible obvious benefit.

### Load to RAM

Each boot entry should have an additional variant which copies the entire distribution to RAM storage, such that the live medium's Linux files are no longer required for general operation. 

### Virtualization

Various virtualization guest agents, such as [QEMU Guest Agent](https://gitlab.com/qemu-project/qemu/-/tree/master/qga), for example, should be installed for users virtualizing the distribution.

## Remote Desktop

[Parsec](https://parsec.app) and [Rustdesk](https://rustdesk.com/) should be in the liveCD.

### Parsec

The app should "just work", with no artificial barrier of access other than standard authentication.

### Rustdesk

[Rustdesk](https://rustdesk.com/) should be able to on boot automatically run with a custom static password configuration and LAN direct IP access enabled. The configuration file itself should be located at the root directory of the liveCD medium. If this configuration is not available however, Rustdesk should then revert to it's default settings. 

> [!WARNING]\
> :warning: This process of automatically exposing unattended access to a network is essentially a backdoor. Do not attempt to set a known and public Rustdesk password!

## Terminal

[Ghostty](https://ghostty.org/) will be used with GUI tab support, scrollbar enabled, and [Sakura](https://github.com/dabisu/sakura)'s default Tango color scheme.

## Text Editor

For basic text editing, [Elementary Code](https://github.com/elementary/code) will be used. Any text editor should have its color scheme automatically match the current GNOME theme.

For note taking and general document processing work, [LibreOffice](https://www.libreoffice.org/) should be setup.

## Video Player

[mpv](https://mpv.io/) shall be used as the default video player.
