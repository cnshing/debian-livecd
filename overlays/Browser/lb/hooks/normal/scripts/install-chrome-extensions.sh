#!/bin/sh
# Manually installs chrome and chromium extensions via install_crx <id> <name> <dest_dir>
# Assumes dest_dir corresponds to the browser: /opt/google/chrome/extensions or /usr/share/chromium/extensions

install_crx() {
    id="$1"
    name="$2"
    dest_dir="$3"
    url="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=120.0&acceptformat=crx2,crx3&x=id%3D${id}%26installsource%3Dondemand%26uc"
    tmp_crx="/tmp/$id.crx"

    echo "[$name] ==> Downloading extension..."
    if ! curl -fL "$url" -o "$tmp_crx"; then
        echo "[$name] ==> ERROR: Failed to download $url" >&2
        exit 1
    fi

    version="$(unzip -p "$tmp_crx" manifest.json | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
    if [ -z "$version" ]; then
        rm -f "$tmp_crx"
        echo "[$name] ==> ERROR: Failed to read version from downloaded crx" >&2
        exit 1
    fi

    mkdir -p "$dest_dir"
    chmod 755 "$dest_dir"
    cp "$tmp_crx" "$dest_dir/$id.crx"
    chmod 644 "$dest_dir/$id.crx"
    cat > "$dest_dir/$id.json" <<EOF
{
  "external_crx": "$dest_dir/$id.crx",
  "external_version": "$version"
}
EOF
    chmod 644 "$dest_dir/$id.json"
    rm -f "$tmp_crx"

    echo "[$name] ==> Installed successfully to $dest_dir ($version)"
}
