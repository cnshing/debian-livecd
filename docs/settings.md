# Settings

This document provides commands and application settings to reproduce the liveCD's [configuration](configuration.md) on an installed system. Follow each section's instructions directly; custom file contents are included so you can create them without a checkout of this repository.

The references identify the source files used by the build. When developers or coding assistants change those files, update the corresponding commands and embedded contents here so following the instructions produces identical files. Keep each section's references after its setup and verification instructions.

## Battery Management

The [Battery Management configuration](configuration.md#battery-management) uses TLP for power profiles and `tlp-pd` for GNOME's Power Mode switch. We shall configure the settings to performance while charging or at 41–100% on battery, and power saver at 0–40%, although you are free to adjust these numbers.

Install the dependencies. On  Trixie systems,`tlp-pd` is available from `trixie-backports`. 

```bash
sudo apt update
sudo apt install tlp tlp-pd upower jq
```

Let TLP switch profiles when the charger is connected or disconnected, using performance while plugged in:

```bash
sudo mkdir -p /etc/tlp.d
sudo tee /etc/tlp.d/50-battery-power-mode.conf <<'EOF'
# Configures TLP power mode switching when charging/discharging.
TLP_AUTO_SWITCH=1

# Profile while plugged in.
TLP_PROFILE_AC=PRF
EOF
```

TLP does not select profiles by battery percentage, so a monitoring service is needed. The below script configures a service that automatically changes performance profiles by percentage, until the current profile is externally overriden by the user. The monitoring service will also exit if no battery is present.

```bash
sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/battery-power-mode <<'EOF'
#!/bin/sh

set -eu

BAT_DEVICE="/org/freedesktop/UPower/devices/DisplayDevice"
PP="org.freedesktop.UPower.PowerProfiles"
PP_PATH="/org/freedesktop/UPower/PowerProfiles"
GSD_POWER="org.gnome.SettingsDaemon.Power"
PROFILES=""

# User overrides, kept until the service restarts:
# PICKED - Defer to any manually set power mode in GNOME while on battery.
# NO_SAVER - GNOME Settings Daemon held power-saver on low battery. When enabled, defer to this rather than our own configured values.
PICKED=0
NO_SAVER=0
# "<caller> <cookie>" of the last Set/HoldProfile call; it only counts once tlp-pd accepts it,
# since polkit rejects callers outside the active session.
PENDING_PICK=""
PENDING_HOLD=""

plugged_in() {
    # UPower Device.State: 1 charging, 4 fully charged, 5 pending charge.
    case "$STATE" in 1|4|5) return 0 ;; esac
    return 1
}

apply() {
    # Charging belongs to TLP (TLP_PROFILE_AC); only battery percentage is handled here.
    plugged_in && return 0
    [ "$PICKED" = 0 ] || return 0
    case "$PCT" in ''|*[!0-9]*) return 0 ;; esac
    want=""
    for p in $PROFILES; do
        start=${p%%,*}
        rest=${p#*,}
        end=${rest%%,*}
        profile=${rest#*,}
        [ "$NO_SAVER" = 1 ] && [ "$profile" = "power-saver" ] && continue
        if [ "$PCT" -ge "$start" ] && [ "$PCT" -le "$end" ]; then
            want="$profile"
            break
        fi
    done
    [ -n "$want" ] && [ "$want" != "$ACTIVE" ] || return 0
    # Defer to any ProfileHold currently active
    [ "$(busctl get-property "$PP" "$PP_PATH" "$PP" ActiveProfileHolds 2>/dev/null)" = "aa{sv} 0" ] || return 0
    if tlp "$want" >/dev/null 2>&1; then
        echo "battery-power-mode: ${PCT}% -> $want" >&2
        ACTIVE="$want"
    else
        echo "battery-power-mode: 'tlp $want' failed" >&2
    fi
}

# Loads the battery profiles only if the configuration defines them as non-empty values.
# Profile names are TLP's: performance, balanced, power-saver.
PROFILES="$PROFILES 41,100,performance"
PROFILES="$PROFILES 0,40,power-saver"

if [ -z "$PROFILES" ]; then
    echo "battery-power-mode: no usable profiles configured, exiting" >&2
    exit 0
fi

if ! upower -i "$BAT_DEVICE" 2>/dev/null | grep -qE '^[[:space:]]*power supply:[[:space:]]*yes'; then
    echo "battery-power-mode: no battery present, exiting" >&2
    exit 0
fi

# Plug/unplug events between this read and busctl subscribing are missed until the next State signal; start the monitor first and read inside the loop.
set -- $(busctl get-property org.freedesktop.UPower "$BAT_DEVICE" org.freedesktop.UPower.Device Percentage State)
PCT=${2%%.*}
STATE=${4:-}
# Reading ActiveProfile also makes tlp-pd emit PropertiesChanged on this interface: it only
# signals interfaces a client has used.
ACTIVE=$(busctl get-property "$PP" "$PP_PATH" "$PP" ActiveProfile 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p')
apply

# Events, one per line:
#   battery <percentage|-> <state|->  UPower DisplayDevice changed
#   profile <name>                    tlp-pd's ActiveProfile changed (by TLP, a hold, or us)
#   pick <caller> <cookie>            someone asked tlp-pd for a Power Mode (GNOME Settings/Shell)
#   hold <caller> <cookie>            GNOME Settings Daemon asked to hold power-saver
#   ok <caller> <cookie>              tlp-pd accepted that call
busctl monitor --system --json=short \
    --match="type=signal,sender=org.freedesktop.UPower,path=$BAT_DEVICE,interface=org.freedesktop.DBus.Properties,member=PropertiesChanged" \
    --match="type=signal,sender=$PP,path=$PP_PATH,interface=org.freedesktop.DBus.Properties,member=PropertiesChanged" \
    --match="type=method_call,destination=$PP,path=$PP_PATH,interface=org.freedesktop.DBus.Properties,member=Set" \
    --match="type=method_call,destination=$PP,path=$PP_PATH,interface=$PP,member=HoldProfile" \
    --match="type=method_return,sender=$PP" |
jq --unbuffered -r --arg bat "$BAT_DEVICE" --arg gsd "$GSD_POWER" '
    if .type == "signal" and .path == $bat then
        .payload.data[1] | select(has("Percentage") or has("State"))
        | "battery \(.Percentage.data // "-" | if . == "-" then . else floor end) \(.State.data // "-")"
    elif .type == "signal" then
        .payload.data[1].ActiveProfile.data // empty
        | select(. == "performance" or . == "balanced" or . == "power-saver") | "profile \(.)"
    elif .member == "Set" then
        select(.payload.data[1] == "ActiveProfile") | "pick \(.sender) \(.cookie)"
    elif .member == "HoldProfile" then
        select(.payload.data[0] == "power-saver" and .payload.data[2] == $gsd) | "hold \(.sender) \(.cookie)"
    elif .type == "method_return" then
        "ok \(.destination) \(.reply_cookie)"
    else empty end' |
while IFS=' ' read -r event a b; do
    case "$event" in
        battery)
            [ "$a" = "-" ] || PCT="$a"
            [ "$b" = "-" ] || STATE="$b"
            apply
            ;;
        profile)
            ACTIVE="$a"
            # Re-apply after TLP's own switch on unplug or a released hold reverting it.
            apply
            ;;
        pick) PENDING_PICK="$a $b" ;;
        hold) PENDING_HOLD="$a $b" ;;
        ok)
            if [ "$a $b" = "$PENDING_PICK" ]; then
                PENDING_PICK=""
                if plugged_in; then
                    echo "battery-power-mode: Power Mode picked in GNOME while charging; charging stays with TLP" >&2
                elif [ "$PICKED" = 0 ]; then
                    PICKED=1
                    echo "battery-power-mode: Power Mode picked in GNOME, percentage profiles off until restart" >&2
                fi
            elif [ "$a $b" = "$PENDING_HOLD" ]; then
                PENDING_HOLD=""
                if [ "$NO_SAVER" = 0 ]; then
                    NO_SAVER=1
                    echo "battery-power-mode: GNOME holds power-saver on low battery, power-saver profiles off until restart" >&2
                fi
            fi
            ;;
    esac
done
EOF
sudo chmod 0755 /usr/local/bin/battery-power-mode
```

We use the following trick to distinguish between an explicit performance setting change by a user vereus GNOME's power saver mode by disabling it outright: 

```bash
gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery false
```

Start the monitor automatically using the overlay's system service:

```bash
sudo tee /etc/systemd/system/battery-power-mode.service <<'EOF'
[Unit]
Description=Switch TLP profile by battery percentage (UPower monitor)
After=multi-user.target tlp.service

[Service]
Type=simple
ExecStart=/usr/local/bin/battery-power-mode
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo chmod 0644 /etc/systemd/system/battery-power-mode.service
sudo systemctl daemon-reload
sudo systemctl enable tlp.service battery-power-mode.service
sudo systemctl restart tlp.service battery-power-mode.service
```

To resume automatic percentage switching after a manual override, run `sudo systemctl restart battery-power-mode.service`.

Reference: [`config.yaml`](../overlays/Battery%20Management/config.yaml), [`config.yaml`](../os/config.yaml), [`batterymanagement.yaml`](../overlays/Battery%20Management/packages/batterymanagement.yaml), [`50-battery-power-mode.conf.overlay.tmpl`](../overlays/Battery%20Management/lb/includes.chroot/etc/tlp.d/50-battery-power-mode.conf.overlay.tmpl), [`battery-power-mode.overlay.tmpl`](../overlays/Battery%20Management/lb/includes.chroot/usr/local/bin/battery-power-mode.overlay.tmpl), [`10-battery-power-mode`](../overlays/Battery%20Management/filesystem/live_installed/etc/dconf/db/desktop.d/10-battery-power-mode), [`battery-power-mode.service`](../overlays/Battery%20Management/lb/includes.chroot/etc/systemd/system/battery-power-mode.service), [`2600-enable-battery-power-mode.hook.chroot.overlay.tmpl`](../overlays/Battery%20Management/lb/hooks/normal/2600-enable-battery-power-mode.hook.chroot.overlay.tmpl)

### Hybrid graphics

The [Hybrid graphics configuration](configuration.md#hybrid-graphics) adds **GNOME (Integrated Graphics)** and **GNOME (Dedicated Graphics)** to GDM's session chooser, configuring Mutter to render the session using those devices. It assumes an pre-existing working graphics driver to function properly.

Install the dependencies and refresh GPU classification:

```bash
sudo apt update
sudo apt install switcheroo-control pkexec
sudo udevadm control --reload
sudo udevadm trigger --action=change --subsystem-match=drm
sudo udevadm settle
sudo systemctl restart switcheroo-control
```

Write the script that selects Mutter's primary GPU:

```bash
sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/set-primary-gpu <<'EOF'
#!/bin/sh
# Override Mutter's primary GPU selection with 'dedicated' and 'integrated' GPUs.

# Mutter has its own method for selecting a GPU at compositor startup. The script leverages a `mutter-device-preferred-primary` udev tag to override this selection. See the udev tag in CURRENT_TAGS; see meta-udev.c:125, meta-backend-native.c:536, and meta-renderer-native.c:2346.

# We select the first "dedicated" and non-dedicated ("integrated") device in switcheroo-control's libudev enumeration order, where it is considered "dedicated" if the DRM render nodes are assigned a "switcheroo-discrete-gpu" tag. It uses this information along with other details to properly match this render node to a "card" node used by the `mutter-device-preferred-primary` udev tag.

set -eu

RULE=/run/udev/rules.d/61-mutter-preferred-primary.rules
TAG=mutter-device-preferred-primary
seat=seat0

log() { echo "set-primary-gpu: $*" >&2; }

if [ "$#" -ne 1 ]; then
    log "usage: set-primary-gpu <default|integrated|dedicated>"
    exit 2
fi
policy=$1
prop() { sed -n "s/^$1=//p"; }

# Print matching GPUs as "ID_PATH|DEVNAME|DEVPATH" in switcheroo-control's enumeration order.
cards() {
    want_discrete=$1
    udevadm trigger --dry-run --verbose --subsystem-match=drm --sysname-match='renderD*' 2>/dev/null |
        while read -r render; do
            [ -n "$render" ] || continue

            # Based on testing, the earlier boot/non-boot fallback seems sufficient for now.
            # TODO: Uncomment below and switch to tag-only classification once Debian stable switcheroo-control >= 3.0.
            # discrete=0
            # case $(udevadm info --query=property --path="$render" 2>/dev/null | prop CURRENT_TAGS) in
            #     *:switcheroo-discrete-gpu:*) discrete=1 ;;
            # esac

            discrete=0
            case $(udevadm info --query=property --path="$render" 2>/dev/null | prop CURRENT_TAGS) in
                *:switcheroo-discrete-gpu:*) discrete=1 ;;
                *)
                    # shortcut: boot/non-boot is not universal GPU classification; replace this fallback at the TODO above.
                    if [ ! -e /usr/lib/udev/rules.d/30-discrete-gpu.rules ] &&
                        [ "$(cat "$render/device/boot_vga" 2>/dev/null || true)" != 1 ]; then
                        discrete=1
                    fi
                    ;;
            esac
            [ "$discrete" = "$want_discrete" ] || continue

            # switcheroo classifies render nodes, but Mutter tags card nodes, so find the sibling card belonging to the same GPU.
            for card in "$(dirname "$render")"/card[0-9]*; do
                [ -d "$card" ] || continue
                props=$(udevadm info --query=property --path="$card" 2>/dev/null) || continue

                # Keep only DRM card devices that Mutter would enumerate for seat0; see meta_udev_is_drm_device() and meta_udev_list_drm_devices().
                [ "$(printf '%s\n' "$props" | prop DEVTYPE)" = drm_minor ] || continue
                devname=$(printf '%s\n' "$props" | prop DEVNAME)
                case $devname in /dev/dri/card*) ;; *) continue ;; esac
                dev_seat=$(printf '%s\n' "$props" | prop ID_SEAT)
                [ -n "$dev_seat" ] || dev_seat=seat0
                [ "$dev_seat" = "$seat" ] || continue
                case $(printf '%s\n' "$props" | prop TAGS) in *:seat:*) ;; *) continue ;; esac

                printf '%s|%s|%s\n' \
                    "$(printf '%s\n' "$props" | prop ID_PATH)" \
                    "$devname" \
                    "$(printf '%s\n' "$props" | prop DEVPATH)"
            done
        done
}

case $policy in
    default) target= ;;
    integrated) target=$(cards 0 | head -n1) ;;
    dedicated) target=$(cards 1 | head -n1) ;;
    *) log "unknown policy '$policy'"; exit 2 ;;
esac

if [ "$policy" != default ] && [ -z "$target" ]; then
    log "no $policy GPU on $seat; leaving Mutter's automatic selection alone"
fi

id_path=$(printf '%s' "$target" | cut -d'|' -f1)
devname=$(printf '%s' "$target" | cut -d'|' -f2)
devpath=$(printf '%s' "$target" | cut -d'|' -f3)

if [ -n "${DRY_RUN:-}" ]; then
    printf '%s\n' "${devname:-none}"
    exit 0
fi

if [ -z "$target" ]; then
    rm -f "$RULE"
else
    mkdir -p /run/udev/rules.d

    # ID_PATH is preferred because it persists under card-number changes across boots; fall back to DEVPATH for devices without one.
    if [ -n "$id_path" ]; then
        match="ENV{ID_PATH}==\"$id_path\""
    else
        match="DEVPATH==\"$devpath\""
    fi
    printf '# generated by set-primary-gpu, %s policy\nSUBSYSTEM=="drm", KERNEL=="card*", %s, TAG+="%s"\n' \
        "$policy" "$match" "$TAG" >"$RULE"
    log "primary GPU for '$policy': $devname ($id_path)"
fi

# Force udev to reload and reprocess the cards so the user's compositor is aware of the changes when it starts; the already-running GDM compositor ignores these change events for GPU selection.
udevadm control --reload
udevadm trigger --action=change --subsystem-match=drm --sysname-match='card*'
udevadm settle
EOF
sudo chmod 0755 /usr/local/bin/set-primary-gpu
```

Generate the Integrated Graphics and Dedicated Graphics login entries from your current `gnome.desktop`:

```bash
sudo sh <<'EOF'
#!/bin/sh
# Generates Integrated and Dedicated GPU GNOME session desktop files.
# Exec needs the explicit sh -c because GDM never runs it through a shell: it is split with g_shell_parse_argv and spawned directly (gdm daemon/gdm-wayland-session.c:306). If pkexec cannot apply the policy, its error lands in the journal and the session still starts on whichever GPU Mutter would have picked by itself.

set -eu

SRC=/usr/share/wayland-sessions/gnome.desktop
HELPER=/usr/local/bin/set-primary-gpu

echo "[Hybrid graphics] ==> Generating GPU session entries..."

if [ ! -f "$SRC" ]; then
    echo "[Hybrid graphics] ==> ERROR: $SRC not found; available sessions:" >&2
    ls -1 /usr/share/wayland-sessions/ >&2 || true
    exit 1
fi

exec_line=$(sed -n 's/^Exec=//p' "$SRC")
case $exec_line in
    *\'* | *\"* | *\\*)
        echo "[Hybrid graphics] ==> ERROR: $SRC Exec has quotes or backslashes, cannot wrap it: $exec_line" >&2
        exit 1
        ;;
esac

# Remove translated Name/Comment entries so they cannot override our custom labels, and don't advertise these GPU-specific sessions as being able to run in headless mode.
generate() {
    policy=$1
    label=$2
    out=/usr/share/wayland-sessions/gnome-gpu-$policy.desktop
    sed -e '/^Name\[/d' \
        -e '/^Comment\[/d' \
        -e '/^X-GDM-CanRunHeadless=/d' \
        -e "s|^Name=.*|Name=GNOME ($label)|" \
        -e "s|^Comment=.*|Comment=This session logs you into GNOME, preferring the $policy GPU|" \
        -e "s#^Exec=\(.*\)#Exec=sh -c 'pkexec $HELPER $policy || true; exec \1'#" \
        "$SRC" >"$out"
    echo "[Hybrid graphics] ==> Wrote $out"
}

generate integrated "Integrated Graphics"
generate dedicated "Dedicated Graphics"

echo "[Hybrid graphics] ==> Generated successfully"
EOF
```

We are not done yet as must provide permissions to maniuplate udev to the login user. Install the following polkit action to allow local sessions to run the helper without a password prompt, including during login.

```bash
sudo mkdir -p /usr/share/polkit-1/actions
sudo tee /usr/share/polkit-1/actions/debian.livecd.set-primary-gpu.policy <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
<policyconfig>
  <vendor>debian-livecd</vendor>

  <action id="debian.livecd.set-primary-gpu">
    <description>Select the primary GPU for the graphical session</description>
    <message>Authentication is required to select the primary GPU</message>
  <!-- Allow local sessions without authentication. The helper is invoked
      during GDM session startup, before logind necessarily marks the new
      session active, so both active and inactive local sessions must be
      permitted. Arbitrary/non-local callers are not allowed. -->
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>yes</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/set-primary-gpu</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">false</annotate>
  </action>
</policyconfig>
EOF
sudo chmod 0644 /usr/share/polkit-1/actions/debian.livecd.set-primary-gpu.policy
```

To ensure the GNOME session isn't "stuck" on any particular GPU, we configure the following cleanup hook to reset any GPU preferences back to its default.

```bash
sudo mkdir -p /etc/gdm3/PostSession
if [ -f /etc/gdm3/PostSession/Default ]; then
    sudo cp --backup=numbered /etc/gdm3/PostSession/Default /etc/gdm3/PostSession/Default.before-hybrid-graphics
fi
sudo tee /etc/gdm3/PostSession/Default <<'EOF'
#!/bin/sh
# GDM runs this as root when a session ends (gdm daemon/gdm-session-worker.c:1846).
# Resets the primary GPU to its default when any session ends for a clean state.

/usr/local/bin/set-primary-gpu default || true

exit 0
EOF
sudo chmod 0755 /etc/gdm3/PostSession/Default
```

The above script overwrites `/etc/gdm3/PostSession/Default` so a backup is made to `/etc/gdm3/PostSession/Default.before-hybrid-graphics` prior.

To check which GPU(s) identifies as integrated or dedicated, run the following command:

```bash
DRY_RUN=1 /usr/local/bin/set-primary-gpu integrated
DRY_RUN=1 /usr/local/bin/set-primary-gpu dedicated
```

Reference: [`gpu-selection.yaml`](../overlays/Battery%20Management+Hybrid%20graphics/packages/gpu-selection.yaml), [`set-primary-gpu`](../overlays/Battery%20Management+Hybrid%20graphics/filesystem/live_installed/usr/local/bin/set-primary-gpu), [`debian.livecd.set-primary-gpu.policy`](../overlays/Battery%20Management+Hybrid%20graphics/filesystem/live_installed/usr/share/polkit-1/actions/debian.livecd.set-primary-gpu.policy), [`Default`](../overlays/Battery%20Management+Hybrid%20graphics/filesystem/live_installed/etc/gdm3/PostSession/Default), [`2700-generate-gpu-sessions.hook.chroot.overlay.tmpl`](../overlays/Battery%20Management+Hybrid%20graphics/lb/hooks/normal/2700-generate-gpu-sessions.hook.chroot.overlay.tmpl)

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
- The main panel resides in GNOME's primary monitor. 
- ArcMenu uses the Redmond layout with the search bar at the bottom, a square avatar, and `bookmarks`, `external devices`, `open windows` and `recent files` enabled.
- Windows are set to display minimize, maximize and close buttons, as GNOME defaults to a close button only.

```bash
# Extension schemas are read from each extension's own folder, as they may not be installed system-wide
EXT=/usr/share/gnome-shell/extensions
DTP="gsettings --schemadir $EXT/dash-to-panel@jderose9.github.com/schemas set org.gnome.shell.extensions.dash-to-panel"
ARC="gsettings --schemadir $EXT/arcmenu@arcmenu.com/schemas set org.gnome.shell.extensions.arcmenu"

$DTP primary-monitor "''"
$DTP multi-monitors false

# Keyed by monitor index (0, 1, 2) since monitor IDs are hardware-specific
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

`gvfs-fuse` is also installed so that it is at least possible for thumbnailers to create previews of files on network shares, by allowing applications to work on those files as if they were on a regular filesystem.

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

Install these fonts for broader Unicode support including emojis:
```bash
sudo apt update
sudo apt install --install-recommends \
  fonts-noto \
  fonts-noto-color-emoji \
  fonts-dejavu \
  fonts-unifont
fc-cache -f
```

Reference: [`fonts.yaml`](../overlays/Desktop%20Environment+Tweaks/packages/fonts.yaml)

## File Manager

### Nautilus

Allow users to create an empty `New Text Document.txt` in the file manager through the following:

```bash
mkdir -p ~/Templates
touch ~/Templates/'New Text Document.txt'
```

Reference: [`New Text Document.txt`](../overlays/File%20Manager/filesystem/live_installed/etc/skel/Templates/New%20Text%20Document.txt)

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

### Open in Terminal

While Ghostty's own Nautilus extension adds "Open in Ghostty" to the context menu, it is not available in folders opened with `nautilus-admin`'s "Open as Administrator". The following adds an extension that enables it there, opening Ghostty with a root shell and requesting `sudo` elevation:
```bash
sudo tee /usr/share/nautilus-python/extensions/ghostty-admin.py <<'EOF'
import os
from gi.repository import Nautilus, GObject, Gio

try:
    from ghostty import get_paths_to_open, _
except ModuleNotFoundError as e:
    # Only ghostty.py itself missing, as when Ghostty is uninstalled, rather than anything it fails to import
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
EOF
nautilus -q
```

Reference: [`ghostty-admin.py`](../overlays/Terminal/filesystem/live_installed/usr/share/nautilus-python/extensions/ghostty-admin.py)

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
ConditionFileIsExecutable=/usr/bin/easyeffects

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

## Flatpaks

The *Flatpaks* overlay provides Flatpak support and `flatpak-chroot`, to assist in safely installing Flathub apps in a chrooted environment. Regular users should otherwise install Flatpaks through normal means.

```sh
flatpak-chroot install "{{ overlay.config.flatpakAppId }}"
```

After installing or changing an NVIDIA driver on the running system, refresh Flatpak's graphics extensions:

```sh
flatpak --gl-drivers
sudo flatpak update --system
```

The NVIDIA extension must match the loaded host driver. For example, the tested driver reports `nvidia-550-163-01` and needs `org.freedesktop.Platform.GL.nvidia-550-163-01//1.4`. If that extension is missing, install it explicitly with `sudo flatpak install --system flathub org.freedesktop.Platform.GL.nvidia-550-163-01//1.4`, using the version reported by `flatpak --gl-drivers`. Use `flatpak update --user` for a user installation. The host's Debian driver packages do not provide the graphics libraries inside Flatpak sandboxes. See [Flatpak's graphics extension documentation](https://docs.flatpak.org/en/latest/extension.html).

Reference: [`flatpak.yaml`](../overlays/Flatpaks/packages/flatpak.yaml), [`flatpak-chroot`](../overlays/Flatpaks/lb/includes.chroot/usr/local/sbin/flatpak-chroot), [`0010-enable-flatpak-chroot.hook.chroot`](../overlays/Flatpaks/lb/hooks/normal/0010-enable-flatpak-chroot.hook.chroot), [`2500-install-parsec-flatpak.hook.chroot.overlay.tmpl`](../overlays/Remote%20Desktop+Parsec/lb/hooks/normal/2500-install-parsec-flatpak.hook.chroot.overlay.tmpl)

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
