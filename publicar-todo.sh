#!/bin/bash
# Publica de una vez las dos ramas (canales) de aio-debian y sube todo a GitHub:
#   testing -> versión con driver NVIDIA   (aio-debian.sh)
#   stable  -> versión sin NVIDIA          (aio-debian-estable.sh)
#
# Uso (desde la carpeta del proyecto):
#   ./publicar-todo.sh [CARPETA_DE_DESCARGAS]        (por defecto ~/Descargas)
# Versiones (cámbialas si hace falta):
#   V_STABLE=1.0.7 V_TESTING=1.1.4 ./publicar-todo.sh
set -euo pipefail
cd "$(dirname "$0")"

DESC="${1:-$HOME/Descargas}"
V_STABLE="${V_STABLE:-1.0.7}"
V_TESTING="${V_TESTING:-1.1.4}"
NVIDIA="$DESC/aio-debian.sh"
ESTABLE="$DESC/aio-debian-estable.sh"

# --- Comprobaciones previas -------------------------------------------------
for f in "$NVIDIA" "$ESTABLE" ./publicar.sh src/aio-debian.sh src/aio-debian.png; do
    [ -f "$f" ] || { echo "Falta el archivo: $f" >&2; exit 1; }
done
# Cada script debe traer la entrada de novedades de la versión que se publica
grep -q "^        ${V_TESTING})" "$NVIDIA"  || { echo "aio-debian.sh no tiene novedades para $V_TESTING (añade su entrada en novedades_de_version)." >&2; exit 1; }
grep -q "^        ${V_STABLE})"  "$ESTABLE" || { echo "aio-debian-estable.sh no tiene novedades para $V_STABLE (añade su entrada en novedades_de_version)." >&2; exit 1; }
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "[!] Hay cambios sin confirmar en git; se incluirán en el commit."
fi

# Copia de seguridad del script actual; se restaura si algo falla
BK=$(mktemp); cp src/aio-debian.sh "$BK"
OK=0
trap '[ "$OK" = 1 ] || { cp "$BK" src/aio-debian.sh; echo "[!] Algo falló: se restauró src/aio-debian.sh." >&2; }; rm -f "$BK"' EXIT

# --- 1. testing (con NVIDIA) ------------------------------------------------
echo "=== Canal testing: $V_TESTING ==="
cp "$NVIDIA" src/aio-debian.sh
./publicar.sh "$V_TESTING" testing

# --- 2. stable (sin NVIDIA) -------------------------------------------------
echo "=== Canal stable: $V_STABLE ==="
cp "$ESTABLE" src/aio-debian.sh
./publicar.sh "$V_STABLE"

# --- 3. Dejar en src/ la versión de desarrollo (con NVIDIA) y subir ---------
cp "$NVIDIA" src/aio-debian.sh
git add -A
git commit -m "aio-debian: stable $V_STABLE y testing $V_TESTING" || echo "(nada nuevo que confirmar)"
git push -u origin HEAD
OK=1
echo
echo "[✔] Publicado: stable $V_STABLE y testing $V_TESTING."
echo "    Espera 1-2 minutos a GitHub Pages y actualiza con: sudo apt update && sudo apt upgrade"
