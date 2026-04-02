#!/bin/sh

ARCH="$(flatpak --default-arch)"

# Template-provided package list
PKGS="{{ overlay.config.packages | join(' ') }}"

{
  flatpak search "" --columns=application,version,branch
  flatpak remote-ls flathub --arch="$ARCH" \
    --columns=application,ref,version,branch
} | awk -v pkgs="$PKGS" '
BEGIN {
    FS="[[:space:]]+"

    # Build wanted app set
    split(pkgs, w, /[[:space:]]+/)
    for (i in w) {
        want_app[w[i]] = 1
        found[w[i]] = 0
    }
}

NR==1 { next }

# Collect desired (appid, version, branch)
NF==3 {
    app=$1; ver=$2; branch=$3
    key = app "|" ver "|" branch

    if (app in want_app) {
        want[key] = 1
    }
    next
}

# Match against remote-ls
NF>=4 {
    app=$1; ref=$2; ver=$3; branch=$4
    key = app "|" ver "|" branch

    if (key in want) {
        map[app] = ref
        found[app] = 1
    }
}

END {
    # Print pulls for found apps
    for (app in map) {
        ref = map[app]
        printf "echo \"[INFO] Pulling %s\"\n", app
        printf "echo ostree pull --repo=/var/lib/flatpak/repo flathub %s\n", ref
    }

    # Warn for missing apps
    for (app in want_app) {
        if (!found[app]) {
            printf "echo \"[WARN] Could not resolve %s\" >&2\n", app
        }
    }
}
' | sh