#!/bin/bash
# Construye el .deb, genera el repositorio APT firmado en ./docs y lo deja
# listo para publicar con GitHub Pages.
#
# Uso:  ./publicar.sh [VERSION]     (ej.: ./publicar.sh 1.1.0)
# Si no indicas versión, se usa la de ./VERSION (por defecto 1.0.0).
set -euo pipefail
cd "$(dirname "$0")"
export LC_ALL=C

# shellcheck disable=SC1091
source ./config.env
[ "$GH_USER" != "TU_USUARIO_GITHUB" ] || { echo "Edita config.env y pon tu usuario de GitHub." >&2; exit 1; }
for c in dpkg-deb gpg gzip sha256sum md5sum convert; do
    command -v "$c" >/dev/null || { echo "Falta '$c'. Instálalo (p. ej. sudo apt install dpkg gnupg imagemagick)." >&2; exit 1; }
done

PAQUETE="aio-debian"
[ -f VERSION ] || echo "1.0.0" > VERSION
if [ $# -ge 1 ]; then echo "$1" > VERSION; fi
VERSION=$(tr -d '[:space:]' < VERSION)
URL="https://${GH_USER}.github.io/${REPO_NAME}"
KEY_UID="${PAQUETE} repositorio <${MAINTAINER_EMAIL}>"
DEB="${PAQUETE}_${VERSION}_all.deb"

# --- 1. Clave GPG de firma (se crea una sola vez, en TU equipo) -------------
if ! gpg --list-secret-keys "$KEY_UID" >/dev/null 2>&1; then
    echo "[*] Creando clave GPG de firma (te pedirá una contraseña)..."
    if [ "${GPG_SIN_PASSPHRASE:-0}" = "1" ]; then
        gpg --batch --passphrase '' --quick-generate-key "$KEY_UID" rsa4096 sign 5y
    else
        gpg --quick-generate-key "$KEY_UID" rsa4096 sign 5y
    fi
fi
FPR=$(gpg --list-secret-keys --with-colons "$KEY_UID" | awk -F: '/^fpr:/ {print $10; exit}')

# --- 2. Construir el .deb ----------------------------------------------------
echo "[*] Construyendo $DEB ..."
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
P="$W/pkg"
mkdir -p "$P/DEBIAN" "$P/usr/bin" "$P/usr/share/applications" \
         "$P/usr/share/doc/$PAQUETE" "$P/usr/share/keyrings" "$P/etc/apt/sources.list.d"
install -m 0755 src/aio-debian.sh "$P/usr/bin/$PAQUETE"
for s in 48 64 128 256 512; do
    mkdir -p "$P/usr/share/icons/hicolor/${s}x${s}/apps"
    convert src/aio-debian.png -resize "${s}x${s}" "$P/usr/share/icons/hicolor/${s}x${s}/apps/$PAQUETE.png"
done
gpg --export "$FPR" > "$P/usr/share/keyrings/$PAQUETE.gpg"

cat > "$P/etc/apt/sources.list.d/$PAQUETE.sources" <<EOT
Types: deb
URIs: $URL
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/$PAQUETE.gpg
EOT

cat > "$P/usr/share/applications/$PAQUETE.desktop" <<'EOT'
[Desktop Entry]
Type=Application
Name=AiO Debian
GenericName=Mantenimiento del sistema
Comment=Mantenimiento y configuración todo en uno para Debian
Exec=sh -c 'if [ "$(id -u)" -eq 0 ]; then exec aio-debian; elif command -v sudo >/dev/null 2>&1; then exec sudo aio-debian; else exec su -c aio-debian; fi'
Icon=aio-debian
Terminal=true
Categories=System;Settings;PackageManager;
Keywords=apt;flatpak;update;actualizar;mantenimiento;
EOT

cat > "$P/usr/share/doc/$PAQUETE/copyright" <<EOT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: $PAQUETE
Upstream-Contact: $MAINTAINER_NAME <$MAINTAINER_EMAIL>

Files: *
Copyright: $MAINTAINER_NAME
License: All-rights-reserved
EOT

cat > "$P/DEBIAN/control" <<EOT
Package: $PAQUETE
Version: $VERSION
Section: admin
Priority: optional
Architecture: all
Depends: bash, apt, coreutils, util-linux, gawk, sed, grep
Recommends: sudo
Maintainer: $MAINTAINER_NAME <$MAINTAINER_EMAIL>
Homepage: $URL
Description: Script AiO de mantenimiento y configuración para Debian
 Actualiza el sistema con apt (update, dist-upgrade, autoremove, autoclean),
 habilita contrib y non-free, sincroniza el reloj, añade soporte Flatpak con
 Flathub, ofrece complementos para GNOME y comprueba si hace falta reiniciar.
 Este paquete configura su propio repositorio APT para recibir actualizaciones.
EOT
# El .sources de /etc es conffile automáticamente (dpkg lo marca al estar en /etc)
find "$P" -type d -exec chmod 0755 {} +
chmod 0644 "$P/DEBIAN/control" "$P/etc/apt/sources.list.d/$PAQUETE.sources" \
           "$P/usr/share/applications/$PAQUETE.desktop" "$P/usr/share/keyrings/$PAQUETE.gpg"
mkdir -p dist
dpkg-deb --root-owner-group --build "$P" "dist/$DEB" >/dev/null

# --- 3. Repositorio APT (./docs) --------------------------------------------
echo "[*] Generando repositorio APT en ./docs ..."
D=docs
mkdir -p "$D/pool/main" "$D/dists/stable/main/binary-all"
cp "dist/$DEB" "$D/pool/main/"

PK="$D/dists/stable/main/binary-all/Packages"
: > "$PK"
for f in "$D"/pool/main/*.deb; do
    {
        dpkg-deb -f "$f"
        echo "Filename: pool/main/$(basename "$f")"
        echo "Size: $(stat -c %s "$f")"
        echo "MD5sum: $(md5sum "$f" | cut -d' ' -f1)"
        echo "SHA256: $(sha256sum "$f" | cut -d' ' -f1)"
        echo
    } >> "$PK"
done
gzip -9nkf "$PK"

REL="$D/dists/stable/Release"
{
    echo "Origin: $PAQUETE"
    echo "Label: $PAQUETE"
    echo "Suite: stable"
    echo "Codename: stable"
    echo "Date: $(date -Ru | sed 's/+0000/UTC/')"
    echo "Architectures: all"
    echo "Components: main"
    echo "Description: Repositorio APT de $PAQUETE"
    echo "MD5Sum:"
    for f in main/binary-all/Packages main/binary-all/Packages.gz; do
        printf ' %s %16d %s\n' "$(md5sum "$D/dists/stable/$f" | cut -d' ' -f1)" "$(stat -c %s "$D/dists/stable/$f")" "$f"
    done
    echo "SHA256:"
    for f in main/binary-all/Packages main/binary-all/Packages.gz; do
        printf ' %s %16d %s\n' "$(sha256sum "$D/dists/stable/$f" | cut -d' ' -f1)" "$(stat -c %s "$D/dists/stable/$f")" "$f"
    done
} > "$REL"

gpg --batch --yes --pinentry-mode "${GPG_PINENTRY:-default}" --default-key "$FPR" --clearsign -o "$D/dists/stable/InRelease" "$REL"
gpg --batch --yes --pinentry-mode "${GPG_PINENTRY:-default}" --default-key "$FPR" -abs -o "$D/dists/stable/Release.gpg" "$REL"
gpg --export "$FPR" > "$D/$PAQUETE.gpg"
touch "$D/.nojekyll"
cat > "$D/index.html" <<EOT
<!doctype html><meta charset="utf-8"><title>aio-debian</title>
<h1>aio-debian</h1>
<p>Instalación (una sola vez):</p>
<pre>curl -fsSLO $URL/pool/main/$DEB
sudo apt install ./$DEB</pre>
<p>Después se actualiza con <code>sudo apt update &amp;&amp; sudo apt upgrade</code>.</p>
EOT

echo
echo "[✔] Versión $VERSION lista."
echo "    .deb:        dist/$DEB"
echo "    Repositorio: ./docs  ->  $URL"
echo
echo "Para publicar: git add -A && git commit -m \"aio-debian $VERSION\" && git push"
echo "y en GitHub: Settings > Pages > Branch: main, carpeta /docs."
