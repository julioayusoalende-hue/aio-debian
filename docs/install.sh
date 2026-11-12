#!/bin/bash
# Instalador de aio-debian (Debian y derivadas).
#
#   curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo bash
#
# Si el equipo no tiene curl, usa una de estas dos formas:
#   wget -qO- https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo bash
#   sudo sh -c 'apt-get update -qq && apt-get install -y curl ca-certificates' && curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo bash
#
# Canal de pruebas (opcional):
#   curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo AIO_SUITE=testing bash
#
# Qué hace: instala la clave de firma, añade el repositorio APT de aio-debian
# e instala el paquete. Es idempotente: puedes ejecutarlo otra vez sin problema.
# Licencia: GNU GPL v3 o posterior. Sin ninguna garantía.
set -euo pipefail

main() {
    local base_url="https://julioayusoalende-hue.github.io/aio-debian"
    local keyring="${AIO_KEYRING:-/usr/share/keyrings/aio-debian.gpg}"
    local sources="${AIO_SOURCES:-/etc/apt/sources.list.d/aio-debian.sources}"
    local suite="${AIO_SUITE:-stable}"
    case "$suite" in
        stable|testing) ;;
        *) echo "AIO_SUITE debe ser 'stable' o 'testing'." >&2; exit 1 ;;
    esac

    command -v apt-get >/dev/null 2>&1 || {
        echo "Este instalador es solo para Debian y derivadas (necesita apt)." >&2
        exit 1
    }

    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 || {
            echo "Ejecútalo como root o instala sudo." >&2
            exit 1
        }
        SUDO="sudo"
    fi

    # Dependencias para descargar por HTTPS: curl y los certificados de confianza
    local faltan=""
    command -v curl >/dev/null 2>&1 || faltan="curl"
    dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q "install ok installed" \
        || faltan="$faltan ca-certificates"
    if [ -n "$faltan" ]; then
        echo "[*] Instalando dependencias:$faltan ..."
        $SUDO apt-get update -qq
        # shellcheck disable=SC2086
        $SUDO apt-get install -y $faltan
    fi

    TMP_KEY=$(mktemp)
    trap 'rm -f "$TMP_KEY"' EXIT

    echo "[*] Descargando la clave de firma..."
    curl -fsSL "$base_url/aio-debian.gpg" -o "$TMP_KEY"
    [ -s "$TMP_KEY" ] || { echo "La clave descargada está vacía." >&2; exit 1; }
    $SUDO install -D -m 0644 "$TMP_KEY" "$keyring"

    echo "[*] Añadiendo el repositorio de aio-debian..."
    $SUDO tee "$sources" >/dev/null <<EOT
Types: deb
URIs: $base_url
Suites: $suite
Components: main
Architectures: all
Signed-By: $keyring
EOT

    echo "[*] Instalando aio-debian..."
    $SUDO apt-get update
    $SUDO apt-get install -y -o Dpkg::Options::=--force-confnew aio-debian

    echo
    echo "[✔] Listo. Ejecútalo con: sudo aio-debian"
    echo "    Se actualiza con: sudo apt update && sudo apt upgrade"
}

# Todo dentro de main(): si la descarga se corta, no se ejecuta nada a medias.
main "$@"
