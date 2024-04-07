# Configuration

The following document describes all the high level configurations of the liveCD.

## AppImages

AppImages will replace packages not available through the Debian repositories in the `$HOME/AppImages` directory.

Managing and integrating these AppImages into the desktop environment will be up to [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher) Lite, where it will be configured to look for `$HOME/AppImages`. The AppImageLauncher AppImage wil also be placed in the same directory.

## Audio Effects

Ideally, there should be an application that automatically applies an [AutoEQ](https://autoeq.app/) filter for whatever audio device you happen to listen on. Since there isn't any such application yet, [EasyEffects](https://github.com/wwmm/easyeffects) should be already installed so that the user can at least quickly import an impulse response.

## Battery Management

[TLP](https://github.com/linrunner/TLP) will be used to optimize battery with performance. Preferentially, any laptop devices should use full computing power when charging and switch to power-saving mode within `0%` - `40%` battery thresholds.

### NVIDIA Optimus

If possible, there should be a separate boot entry from the standard one that explicitly enables screen rendering from a dedicated GPU, allowing the user to choose which use-case is most appropriate for their battery and performance needs.

## Browser

There will be [Firefox](https://www.mozilla.org/en-US/firefox/browsers/), [Google Chrome](https://www.google.com/chrome/), and [Ungoogled Chromium](https://ungoogled-software.github.io/) all of whom will share the same extensions listed below.

### Password Management

Both [Bitwarden](https://bitwarden.com/) and [Proton Pass](https://proton.me/pass) will be installed by default for password management.

### Ad blocking

[UBlock Origin](https://ublockorigin.com/) will be installed by default for ad blocking.

## Display Manager

[LighDM](https://github.com/canonical/lightdm) will be the display manager using the default GTK [theme](#theming).

## Desktop Environment

[GNOME](https://www.gnome.org/) will be our desktop environment with extensions to support the below functionalities:
 
### Phone Sync

With [GSConnect](https://extensions.gnome.org/extension/1319/gsconnect/), a GNOME [KDEConnect](https://kdeconnect.kde.org/) implementation, installed and automatically enabled, users can pair and sync communications with the liveCD.

### Shell

The desktop shell should traditionally include a [start menu](https://extensions.gnome.org/extension/3628/arcmenu/), an application [taskbar](https://extensions.gnome.org/extension/1160/dash-to-panel/), [system tray](https://extensions.gnome.org/extension/615/appindicator-support/) and [desktop icons](https://extensions.gnome.org/extension/2087/desktop-icons-ng-ding/) support.

### Theming

Enable the User Themes GNOME extension and [gnome-tweaks](https://gitlab.gnome.org/GNOME/gnome-tweaks). Then install the ZorinOS [desktop](https://github.com/ZorinOS/zorin-desktop-themes), [icon](https://github.com/ZorinOS/zorin-icon-themes), and special LibreOffice themes. Most of the liveCD look-and-feel should come from [ZorinOS](https://zorin.com/os/).

[comment - Update the desktop background picture-uri once a path of known background images are found]: #

### Thumbnailers

Content based files should always have a preview thumbnail.

### Tweaks

`gnome-shell-extension-prefs` should be installed with these gsettings [configuration](settings.md#tweaks).

Additionally, the "Window is ready" popup whenever any application opens should be disabled. Extensions accomplishing this are usually initially developed and created only to be subsequently unmaintained with each new GNOME version. The current extension for GNOME 45 would be [NoAnnoyance](https://extensions.gnome.org/extension/6109/noannoyance-fork/).

[comment - Always update this section's current working extension for "Window is ready" for the liveCD's current version]: #

### Window Tiling

Applications should be able to be tiled to the top, bottom, left, and right halves of the screen identically to Window snap tiles via [WinTile](https://extensions.gnome.org/extension/1723/wintile-windows-10-window-tiling-for-gnome/).

## File Manager

There are some instances with GTK File Picker where it is hard coded such that only Gnome's [Nautilus](https://github.com/GNOME/nautilus) file manager can be opened, regardless of any other default file manager in the system. To remedy this there will be a primary file manager, [Thunar](https://gitlab.xfce.org/xfce/thunar), for daily use and a secondary file manager used for any situation where the primary file manager cannot be used. 

[comment - Make an explicit reference to the GNOME section in the future]: #

## Networking

[NetworkManager](https://networkmanager.dev/) is sufficient for Internet with ease of use and GNOME integration. 

### VPN

VPNs should be supported via [GNOME](#desktop-environment) with as many VPN plugins and/or VPN format compatibilities as reasonably possible. 

## Mail Client

Each mail service should be accompanied by corresponding web-app based client. In practice, these web-app implementations are often based off Electron.

## Remote Desktop

[Parsec](https://parsec.app) and [Rustdesk](https://rustdesk.com/) should be in the liveCD.

### Parsec

The app should "just work", with no artificial barrier of access other than standard authentication.

### Rustdesk

[Rustdesk](https://rustdesk.com/) should be automatically running on boot with a custom static password configuration and LAN direct IP access enabled. The configuration file itself should be located at the root directory of the liveCD medium. If this configuration is not available however, Rustdesk should then revert to it's default settings. 

> [!WARNING]\
> :warning: This process of automatically exposing unattended access to a network is essentially a backdoor. Do not attempt to set a known and public Rustdesk password!

## Terminal

[Sakura](https://github.com/dabisu/sakura) will used with [scollbar enabled](settings.md#terminal). 

## Text Editor

For basic text editing, [mousepad](https://github.com/xfce-mirror/mousepad) can do the job with these [preferences](settings.md#text-editor).

For note taking and general document processing work, [LibreOffice](https://www.libreoffice.org/) should be setup with ZorinOS's [special](#theming) icons.

## Video Player

[mpv](https://mpv.io/) shall be used as the default video player.
