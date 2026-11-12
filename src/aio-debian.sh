#!/bin/bash
# aio-debian - Mantenimiento y configuración todo en uno para Debian
# Copyright (C) 2026 Julio Ayuso
# Licencia: GNU GPL v3 o posterior (ver LICENSE o https://www.gnu.org/licenses/gpl-3.0.html)
# Este programa se distribuye SIN NINGUNA GARANTÍA.

# Definición de colores profesionales (todos con $'...' para que funcionen con o sin echo -e)
ROJO=$'\e[1;31m'
BLANCO=$'\e[1;37m'
VERDE=$'\e[1;32m'
AMARILLO=$'\e[1;33m'
AZUL=$'\e[1;36m'
NARANJA=$'\e[38;5;208m'
RESET=$'\e[0m'

# Restaurar siempre el color del terminal al salir, ocurra lo que ocurra
trap 'printf "%s" "$RESET"' EXIT

# ==============================================================================
# Script AiO de Mantenimiento y configuración para Debian
# Sigue las recomendaciones de la política de Debian y el manual de APT.
# ==============================================================================

# Verificar que el script se ejecute con privilegios de superusuario (root)
if [ "$EUID" -ne 0 ]; then
  echo "${NARANJA}[-] Error: Este script debe ejecutarse con privilegios de administrador (usa sudo).${RESET}" >&2
  exit 1
fi
echo ""
echo ""

# ------------------------------------------------------------------------------
# Versión del script y novedades
# La versión es la del paquete .deb instalado (aio-debian). Las novedades se
# registran aquí: al publicar una versión nueva, añade su entrada en el 'case'.
# ------------------------------------------------------------------------------
novedades_de_version() {
    case "$1" in
        1.1.4)
            echo "Instala Synaptic automáticamente si no está instalado."
            ;;
        1.1.3)
            echo "Evita los avisos de arquitectura (i386/amd64) en 'apt update'."
            ;;
        1.1.2)
            echo "Muestra la versión del script y sus novedades al iniciar."
            ;;
        1.1.1)
            echo "Nuevo icono de la aplicación."
            ;;
        1.1.0)
            echo "Detecta una gráfica NVIDIA y ofrece instalar el driver adecuado (nvidia-detect)."
            ;;
        *) return 1 ;;
    esac
}

VERSION_SCRIPT=$(dpkg-query -W -f='${Status}|${Version}' aio-debian 2>/dev/null \
    | awk -F'|' '$1 ~ /install ok installed/ {print $2}')
[ -n "$VERSION_SCRIPT" ] || VERSION_SCRIPT="desarrollo (no instalado desde paquete)"

# --- INFORMACIÓN DEL SISTEMA ---
echo "${AZUL}Información del Sistema:${RESET}"
echo "${AZUL}------------------------${RESET}"
echo ""

# Obtener versión del SO
if command -v lsb_release &> /dev/null; then
    SO_VERSION=$(lsb_release -ds)
else
    SO_VERSION=$(grep "PRETTY_NAME" /etc/os-release | cut -d'=' -f2 | tr -d '"')
fi
echo "${AZUL}    Sistema Operativo: ${SO_VERSION}${RESET}"

# Obtener versión del Kernel
echo "${AZUL}    Kernel actual: $(uname -r)${RESET}"

# Obtener espacio en disco de la partición raíz
ESPACIO_RAIZ=$(df -h / | awk 'NR==2 {print "Usado: " $3 " / Total: " $2 " (" $5 " ocupado)"}')
echo "${AZUL}    Espacio en disco (/): ${ESPACIO_RAIZ}${RESET}"

# Calcular fecha de instalación (de más a menos fiable)
FECHA_INSTALACION=""

# 1) Fecha de creación del sistema de archivos raíz (ext2/3/4)
DISPOSITIVO_RAIZ=$(findmnt -no SOURCE / 2>/dev/null)
if [ -n "$DISPOSITIVO_RAIZ" ] && command -v tune2fs &> /dev/null; then
    FECHA_INSTALACION=$(tune2fs -l "$DISPOSITIVO_RAIZ" 2>/dev/null \
        | grep -i 'Filesystem created' | sed 's/^[^:]*:[[:space:]]*//')
    if [ -n "$FECHA_INSTALACION" ]; then
        FECHA_INSTALACION=$(date -d "$FECHA_INSTALACION" +%Y-%m-%d 2>/dev/null || echo "$FECHA_INSTALACION")
    fi
fi

# 2) Fecha de nacimiento de / si el sistema de archivos la soporta
if [ -z "$FECHA_INSTALACION" ]; then
    FECHA_INSTALACION=$(stat -c %w / 2>/dev/null | cut -d' ' -f1)
    [ "$FECHA_INSTALACION" = "-" ] && FECHA_INSTALACION=""
fi

# 3) Último recurso: fecha de modificación de /lost+found
if [ -z "$FECHA_INSTALACION" ] && [ -d /lost+found ]; then
    FECHA_INSTALACION=$(stat -c %y /lost+found | cut -d' ' -f1)
fi

if [ -n "$FECHA_INSTALACION" ]; then
    echo "${AZUL}    Fecha de instalación: ${FECHA_INSTALACION}${RESET}"

    # Calcular la antigüedad (años, meses y días) a partir de la fecha de instalación
    if date -d "$FECHA_INSTALACION" +%s &> /dev/null; then
        ANIO_I=$((10#$(date -d "$FECHA_INSTALACION" +%Y)))
        MES_I=$((10#$(date -d "$FECHA_INSTALACION" +%m)))
        DIA_I=$((10#$(date -d "$FECHA_INSTALACION" +%d)))
        ANIO_H=$((10#$(date +%Y)))
        MES_H=$((10#$(date +%m)))
        DIA_H=$((10#$(date +%d)))

        ANTIG_ANIOS=$((ANIO_H - ANIO_I))
        ANTIG_MESES=$((MES_H - MES_I))
        ANTIG_DIAS=$((DIA_H - DIA_I))

        if [ "$ANTIG_DIAS" -lt 0 ]; then
            DIAS_MES_ANTERIOR=$((10#$(date -d "$(date +%Y-%m-01) -1 day" +%d)))
            ANTIG_DIAS=$((ANTIG_DIAS + DIAS_MES_ANTERIOR))
            ANTIG_MESES=$((ANTIG_MESES - 1))
        fi
        if [ "$ANTIG_MESES" -lt 0 ]; then
            ANTIG_MESES=$((ANTIG_MESES + 12))
            ANTIG_ANIOS=$((ANTIG_ANIOS - 1))
        fi

        DIAS_TOTALES=$(( ( $(date +%s) - $(date -d "$FECHA_INSTALACION" +%s) ) / 86400 ))
        echo "${AZUL}    Antigüedad del sistema: ${ANTIG_ANIOS} años, ${ANTIG_MESES} meses y ${ANTIG_DIAS} días (${DIAS_TOTALES} días en total)${RESET}"
    fi
fi
echo "${AZUL}    Versión de aio-debian: ${VERSION_SCRIPT}${RESET}"
if NOVEDADES=$(novedades_de_version "$VERSION_SCRIPT"); then
    echo "${AZUL}    Novedades de esta versión:${RESET}"
    while IFS= read -r linea; do
        echo "${AZUL}      - ${linea}${RESET}"
    done <<< "$NOVEDADES"
fi
echo ""
echo "${AZUL}==================================================${RESET}"
echo ""
echo ""


echo "======================================================================"
echo "  INICIANDO SCRIPT AIO DE MANTENIMIENTO Y CONFIGURACIÓN PARA DEBIAN"
echo "======================================================================"
echo ""

# ------------------------------------------------------------------------------
# Funciones auxiliares
# ------------------------------------------------------------------------------

# Indica si ya se ejecutó apt-get update en esta sesión
LISTAS_ACTUALIZADAS=0

# Se pone a 1 si se instala un driver NVIDIA (hace falta reiniciar para cargarlo)
REINICIO_NVIDIA=0

# Instala Flatpak (si el usuario acepta) y configura el repositorio Flathub
instalar_soporte_flatpak() {
    echo -e "${AMARILLO}[!] Flatpak no está instalado en este sistema.${RESET}"
    read -r -p "¿Deseas instalar el soporte para Flatpak y añadir el repositorio Flathub ahora? (s/N): " resp_flatpak
    case "$resp_flatpak" in
        [sS]|[sS][iI])
            # Si aún no se sincronizaron las listas, hacerlo antes de instalar
            if [ "$LISTAS_ACTUALIZADAS" -eq 0 ]; then
                echo -e "${VERDE}[*] Sincronizando listas de paquetes...${RESET}"
                apt-get update && LISTAS_ACTUALIZADAS=1
            fi

            echo -e "${VERDE}[*] Instalando flatpak...${RESET}"
            export DEBIAN_FRONTEND=noninteractive
            apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install flatpak ca-certificates
            unset DEBIAN_FRONTEND

            if command -v flatpak &> /dev/null; then
                echo -e "${VERDE}[✔] Flatpak instalado correctamente.${RESET}"
                echo -e "${VERDE}[*] Añadiendo el repositorio de Flathub...${RESET}"
                update-ca-certificates &> /dev/null
                if flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
                    echo -e "${VERDE}[✔] Repositorio Flathub configurado con éxito.${RESET}\n"
                else
                    echo -e "${NARANJA}[-] No se pudo añadir Flathub (error de certificado o de red).${RESET}"
                    echo -e "${NARANJA}    Fecha del sistema: $(date)${RESET}"
                    echo -e "${NARANJA}    Reloj sincronizado: $(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo desconocido)${RESET}"
                    echo -e "${NARANJA}    Si la fecha es correcta, puede que tu red intercepte HTTPS (proxy/antivirus).${RESET}"
                    echo -e "${NARANJA}    Puedes reintentarlo luego con: sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo${RESET}\n"
                fi
            else
                echo -e "${NARANJA}[-] No se pudo instalar Flatpak. Comprueba tus repositorios.${RESET}\n"
            fi
            ;;
        *)
            echo -e "${AZUL}[*] Omitiendo la instalación de Flatpak.${RESET}\n"
            ;;
    esac
}

# Añade 'contrib' y 'non-free' a los repositorios oficiales de Debian
# Soporta formato clásico (.list) y deb822 (.sources)
anadir_componentes() {
    local f="$1" copia
    copia=$(mktemp)
    cp -a "$f" "$copia"

    case "$f" in
        *.sources)
            # Solo si apunta a servidores oficiales de Debian (no a repos de terceros
            # cuyo nombre contenga 'debian', como .../aio-debian)
            if ! grep -qiE '^URIs:.*(debian\.org|/debian/?([[:space:]]|$))' "$f"; then rm -f "$copia"; return 1; fi
            sed -i -E '/^Components:/ {
                /(^|[[:space:]])contrib([[:space:]]|$)/! s/[[:space:]]*$/ contrib/
                /(^|[[:space:]])non-free([[:space:]]|$)/! s/[[:space:]]*$/ non-free/
            }' "$f"
            ;;
        *.list)
            # Solo líneas deb/deb-src de Debian que tengan el componente 'main'
            sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]].*(debian\.org|\/debian\/?[[:space:]])/ {
                /[[:space:]]main([[:space:]]|$)/ {
                    /[[:space:]]contrib([[:space:]]|$)/! s/[[:space:]]*$/ contrib/
                    /[[:space:]]non-free([[:space:]]|$)/! s/[[:space:]]*$/ non-free/
                }
            }' "$f"
            ;;
    esac

    if ! cmp -s "$f" "$copia"; then
        cp -a "$copia" "${f}.bak"     # copia de seguridad (apt ignora .bak)
        rm -f "$copia"
        return 0                      # hubo cambios
    fi
    rm -f "$copia"
    return 1                          # sin cambios
}

# Instala un paquete de forma automática y silenciosa si no está presente
instalar_si_falta() {
    local cmd="$1" aviso_fallo="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${AMARILLO}[*] '${cmd}' no detectado. Instalando automáticamente en segundo plano...${RESET}"
        export DEBIAN_FRONTEND=noninteractive
        apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install "$cmd" &> /dev/null
        unset DEBIAN_FRONTEND

        if command -v "$cmd" &> /dev/null; then
            echo -e "${VERDE}[✔] '${cmd}' se instaló correctamente.${RESET}\n"
        else
            echo -e "${NARANJA}[!] ${aviso_fallo}${RESET}\n"
        fi
    fi
}

# Devuelve 0 si el paquete Debian indicado está instalado
paquete_instalado() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Instala un paquete (por su nombre de paquete Debian) de forma automática y
# silenciosa si no está instalado. Útil cuando el comando no se llama como el paquete.
instalar_paquete_si_falta() {
    local pkg="$1" aviso_fallo="$2"
    paquete_instalado "$pkg" && return 0

    echo -e "${AMARILLO}[*] '${pkg}' no detectado. Instalando automáticamente en segundo plano...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install "$pkg" &> /dev/null
    unset DEBIAN_FRONTEND

    if paquete_instalado "$pkg"; then
        echo -e "${VERDE}[✔] '${pkg}' se instaló correctamente.${RESET}\n"
    else
        echo -e "${NARANJA}[!] ${aviso_fallo}${RESET}\n"
    fi
}

# Si GNOME está instalado y Flatpak disponible, ofrece instalar el plugin de
# Flatpak para GNOME Software (permite gestionar apps Flatpak desde la tienda)
ofrecer_plugin_gnome_software() {
    command -v flatpak &> /dev/null || return 0
    paquete_instalado gnome-shell || return 0
    paquete_instalado gnome-software-plugin-flatpak && return 0

    echo -e "${AMARILLO}[!] GNOME detectado, pero falta el plugin de Flatpak para GNOME Software.${RESET}"
    read -r -p "¿Deseas instalar 'gnome-software-plugin-flatpak' ahora? (s/N): " resp_plugin
    case "$resp_plugin" in
        [sS]|[sS][iI])
            if [ "$LISTAS_ACTUALIZADAS" -eq 0 ]; then
                echo -e "${VERDE}[*] Sincronizando listas de paquetes...${RESET}"
                apt-get update && LISTAS_ACTUALIZADAS=1
            fi

            echo -e "${VERDE}[*] Instalando gnome-software-plugin-flatpak...${RESET}"
            export DEBIAN_FRONTEND=noninteractive
            apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install gnome-software-plugin-flatpak
            unset DEBIAN_FRONTEND

            if paquete_instalado gnome-software-plugin-flatpak; then
                echo -e "${VERDE}[✔] Plugin instalado correctamente.${RESET}"
                echo -e "${AZUL}    Cierra y vuelve a abrir GNOME Software (o reinicia la sesión) para verlo.${RESET}\n"
            else
                echo -e "${NARANJA}[-] No se pudo instalar el plugin. Comprueba tus repositorios.${RESET}\n"
            fi
            ;;
        *)
            echo -e "${AZUL}[*] Omitiendo la instalación del plugin de GNOME Software.${RESET}\n"
            ;;
    esac
}

# Si GNOME está instalado, ofrece instalar Extension Manager (app para buscar,
# instalar y gestionar extensiones de GNOME Shell). En Debian el paquete se
# llama 'gnome-shell-extension-manager'.
ofrecer_extension_manager() {
    paquete_instalado gnome-shell || return 0
    paquete_instalado gnome-shell-extension-manager && return 0

    echo -e "${AMARILLO}[!] GNOME detectado, pero falta Extension Manager (gestor de extensiones).${RESET}"
    read -r -p "¿Deseas instalar 'gnome-shell-extension-manager' ahora? (s/N): " resp_extmgr
    case "$resp_extmgr" in
        [sS]|[sS][iI])
            if [ "$LISTAS_ACTUALIZADAS" -eq 0 ]; then
                echo -e "${VERDE}[*] Sincronizando listas de paquetes...${RESET}"
                apt-get update && LISTAS_ACTUALIZADAS=1
            fi

            # No está disponible en versiones antiguas de Debian
            if ! apt-cache show gnome-shell-extension-manager &> /dev/null; then
                echo -e "${NARANJA}[-] 'gnome-shell-extension-manager' no está disponible en tus repositorios.${RESET}\n"
                return 0
            fi

            echo -e "${VERDE}[*] Instalando gnome-shell-extension-manager...${RESET}"
            export DEBIAN_FRONTEND=noninteractive
            apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install gnome-shell-extension-manager
            unset DEBIAN_FRONTEND

            if paquete_instalado gnome-shell-extension-manager; then
                echo -e "${VERDE}[✔] Extension Manager instalado correctamente.${RESET}\n"
            else
                echo -e "${NARANJA}[-] No se pudo instalar Extension Manager. Comprueba tus repositorios.${RESET}\n"
            fi
            ;;
        *)
            echo -e "${AZUL}[*] Omitiendo la instalación de Extension Manager.${RESET}\n"
            ;;
    esac
}

# Devuelve 0 si hay una GPU NVIDIA en el bus PCI (vendor 0x10de, clase 0x03xx).
# Lee /sys directamente, así no depende de que pciutils esté instalado.
hay_gpu_nvidia() {
    local d dir="${AIO_PCI_DIR:-/sys/bus/pci/devices}"
    for d in "$dir"/*; do
        [ -r "$d/vendor" ] && [ -r "$d/class" ] || continue
        if [ "$(cat "$d/vendor")" = "0x10de" ] && [[ "$(cat "$d/class")" == 0x03* ]]; then
            return 0
        fi
    done
    return 1
}

# Devuelve 0 si además de la NVIDIA hay otra gráfica (portátil híbrido)
hay_otra_gpu() {
    local d dir="${AIO_PCI_DIR:-/sys/bus/pci/devices}"
    for d in "$dir"/*; do
        [ -r "$d/vendor" ] && [ -r "$d/class" ] || continue
        if [ "$(cat "$d/vendor")" != "0x10de" ] && [[ "$(cat "$d/class")" == 0x03* ]]; then
            return 0
        fi
    done
    return 1
}

# Devuelve 0 si Secure Boot está activado
secure_boot_activo() {
    if command -v mokutil &> /dev/null; then
        mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'
        return
    fi
    local v=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
    [ -r "$v" ] && [ "$(od -An -t u1 "$v" 2>/dev/null | awk '{print $NF}')" = "1" ]
}

# Si hay una gráfica NVIDIA y no hay driver propietario instalado, ofrece
# instalar el adecuado. El paquete lo decide 'nvidia-detect' (herramienta
# oficial de Debian); requiere el componente 'non-free' habilitado.
ofrecer_driver_nvidia() {
    hay_gpu_nvidia || return 0

    # Si ya hay un driver propietario de NVIDIA instalado, no hay nada que ofrecer
    if dpkg -l 'nvidia-*driver' nvidia-kernel-dkms 2>/dev/null | grep -q '^ii'; then
        echo -e "${VERDE}[✔] Gráfica NVIDIA detectada y driver propietario ya instalado.${RESET}\n"
        return 0
    fi

    echo -e "${AMARILLO}[!] Gráfica NVIDIA detectada, sin driver propietario instalado:${RESET}"
    if command -v lspci &> /dev/null; then
        lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | grep -i nvidia | sed 's/^/    /'
    fi

    instalar_si_falta nvidia-detect "No se pudo instalar 'nvidia-detect' (¿está 'non-free' habilitado?)."
    command -v nvidia-detect &> /dev/null || return 0

    local salida paq
    salida=$(LC_ALL=C nvidia-detect 2>/dev/null)
    paq=$(echo "$salida" | grep -iA3 'recommended to install' | grep -oE 'nvidia-[a-z0-9.-]*driver' | head -1)

    if [ -z "$paq" ]; then
        echo -e "${AZUL}[*] nvidia-detect no recomienda ningún driver propietario para esta tarjeta."
        echo -e "    Se seguirá usando 'nouveau', el driver libre.${RESET}\n"
        return 0
    fi
    if ! apt-cache show "$paq" &> /dev/null; then
        echo -e "${NARANJA}[-] El driver recomendado ('${paq}') no está en tus repositorios.${RESET}\n"
        return 0
    fi

    echo -e "${AZUL}    Driver recomendado por nvidia-detect: ${paq}${RESET}"
    if hay_otra_gpu; then
        echo -e "${AMARILLO}    Aviso: hay otra gráfica además de la NVIDIA (portátil híbrido). El driver se"
        echo -e "    instala igualmente, pero cambiar entre gráficas (PRIME) puede requerir configuración.${RESET}"
    fi
    if secure_boot_activo; then
        echo -e "${AMARILLO}    Aviso: Secure Boot está activado. El módulo del driver debe estar firmado: puede"
        echo -e "    que tengas que registrar la clave de firma de DKMS (MOK) y confirmarla en el próximo"
        echo -e "    arranque (pantalla 'Enroll MOK'). Si no, el driver no se cargará.${RESET}"
    fi

    read -r -p "¿Deseas instalar '${paq}' y las cabeceras del kernel ahora? (s/N): " resp_nvidia
    case "$resp_nvidia" in
        [sS]|[sS][iI])
            local paquetes=("$paq" "linux-headers-$(dpkg --print-architecture)")
            if apt-cache show "linux-headers-$(uname -r)" &> /dev/null; then
                paquetes+=("linux-headers-$(uname -r)")
            fi

            echo -e "${VERDE}[*] Instalando: ${paquetes[*]}${RESET}"
            # Sin DEBIAN_FRONTEND=noninteractive: así puede mostrar avisos de debconf
            apt-get -y install "${paquetes[@]}"

            if paquete_instalado "$paq"; then
                REINICIO_NVIDIA=1
                echo -e "${VERDE}[✔] Driver NVIDIA instalado. Hay que reiniciar para cargarlo.${RESET}"
                echo -e "${AZUL}    Después comprueba que funciona con: nvidia-smi${RESET}\n"
            else
                echo -e "${NARANJA}[-] No se pudo instalar el driver. Revisa los mensajes anteriores.${RESET}\n"
            fi
            ;;
        *)
            echo -e "${AZUL}[*] Omitiendo la instalación del driver NVIDIA.${RESET}\n"
            ;;
    esac
}

# Comprueba si el reloj está sincronizado por NTP y, si no, intenta sincronizarlo.
# Un reloj desfasado rompe la validación de certificados SSL (apt, Flathub...).
sincronizar_reloj() {
    command -v timedatectl &> /dev/null || return 0

    local estado
    estado=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
    if [ "$estado" = "yes" ]; then
        echo -e "${VERDE}[✔] Reloj del sistema sincronizado.${RESET}\n"
        return 0
    fi

    echo -e "${AMARILLO}[!] El reloj del sistema no está sincronizado. Intentando sincronizarlo...${RESET}"

    # Activar NTP; si no hay servicio de hora instalado, instalar systemd-timesyncd
    if ! timedatectl set-ntp true &> /dev/null; then
        echo -e "${AMARILLO}[*] Servicio de hora no disponible. Instalando systemd-timesyncd...${RESET}"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update &> /dev/null
        apt-get -y install systemd-timesyncd &> /dev/null
        unset DEBIAN_FRONTEND
        timedatectl set-ntp true &> /dev/null
    fi

    # Esperar hasta 30 segundos a que se sincronice
    local i
    for i in $(seq 1 30); do
        estado=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
        [ "$estado" = "yes" ] && break
        sleep 1
    done

    if [ "$estado" = "yes" ]; then
        echo -e "${VERDE}[✔] Reloj sincronizado correctamente: $(date)${RESET}\n"
    else
        echo -e "${NARANJA}[-] No se pudo sincronizar el reloj (¿sin red o puerto NTP bloqueado?).${RESET}"
        echo -e "${NARANJA}    Fecha actual del sistema: $(date)${RESET}\n"
    fi
}

mostrar_final() {
    echo ""
    echo "=================================================="
    echo "  [✔] ¡Mantenimiento completado con éxito!"
    echo "=================================================="
    echo "         ❤️ Made by JULIO AYUSO"
    echo ""
    read -r -p "Presiona [Enter] para cerrar esta ventana..."
}

# ------------------------------------------------------------------------------
# Opción para saltar directamente a Flatpak desde el inicio
# ------------------------------------------------------------------------------
echo -e "${AMARILLO}[*] Comprobando la sincronización del reloj...${RESET}"
sincronizar_reloj

read -r -p "¿Deseas actualizar únicamente Flatpak y saltarte el mantenimiento de APT? (s/N): " opcion_flatpak
case "$opcion_flatpak" in
    [sS]|[sS][iI])
        echo -e "\n${AMARILLO}[*] Saltando directamente a la actualización de Flatpak...${RESET}\n"

        # Si Flatpak no está, ofrecer instalarlo
        if ! command -v flatpak &> /dev/null; then
            instalar_soporte_flatpak
        fi

        # Si GNOME está instalado, ofrecer el plugin de Flatpak para GNOME Software
        ofrecer_plugin_gnome_software
        ofrecer_extension_manager

        if command -v flatpak &> /dev/null; then
            echo -e "${VERDE}[*] Actualizando aplicaciones Flatpak...${RESET}"
            flatpak update -y && flatpak uninstall --unused -y
            echo -e "\n${VERDE}¡Proceso de Flatpak completado con éxito!${RESET}"
        else
            echo -e "${NARANJA}Flatpak no está instalado. Nada que actualizar.${RESET}"
        fi

        mostrar_final
        exit 0
        ;;
esac
echo ""

# ------------------------------------------------------------------------------
# Repositorios 'contrib' y 'non-free'
# ------------------------------------------------------------------------------
echo "${AMARILLO}[*] Verificando los repositorios 'contrib' y 'non-free'...${RESET}"
CAMBIOS=0
shopt -s nullglob
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    if anadir_componentes "$f"; then
        echo "${VERDE}[✔] Actualizado: $f (copia en ${f}.bak)${RESET}"
        CAMBIOS=1
    fi
done
shopt -u nullglob

if [ "$CAMBIOS" -eq 0 ]; then
    echo "${VERDE}[✔] 'contrib' y 'non-free' ya estaban configurados.${RESET}"
fi
echo ""

# 1. Sincronizar la base de datos local con los repositorios configurados
echo "${VERDE}[*] Sincronizando listas de paquetes (apt-get update)...${RESET}"
if ! apt-get update; then
  echo "${ROJO}[-] Error al actualizar las listas de paquetes. Comprueba tu conexión.${RESET}" >&2
  exit 1
fi
LISTAS_ACTUALIZADAS=1
echo ""

# Comprobar e instalar soporte para Flatpak de forma interactiva si no está presente
# (se hace después del update para que las listas estén al día)
if ! command -v flatpak &> /dev/null; then
    instalar_soporte_flatpak
fi

# Si GNOME está instalado, ofrecer el plugin de Flatpak para GNOME Software
# y el gestor de extensiones
ofrecer_plugin_gnome_software
ofrecer_extension_manager

# Herramientas auxiliares (instalación automática y silenciosa)
instalar_si_falta needrestart "No se pudo instalar 'needrestart'. Se usará el método manual."
instalar_si_falta fastfetch   "No se pudo instalar 'fastfetch'. Puede que no esté disponible en tus repositorios."
instalar_si_falta kitty       "No se pudo instalar 'kitty'. Puede que no esté disponible en tus repositorios."
instalar_paquete_si_falta synaptic "No se pudo instalar 'synaptic'. Puede que no esté disponible en tus repositorios."

# 2. Actualizar de forma segura los paquetes instalados
echo "${VERDE}[*] Actualizando los paquetes del sistema (apt-get dist-upgrade)...${RESET}"
if ! apt-get dist-upgrade -y; then
  echo "${ROJO}[-] Error durante la actualización de paquetes.${RESET}" >&2
  exit 1
fi
echo ""

# 2b. Si hay gráfica NVIDIA, ofrecer el driver adecuado (tras actualizar el kernel)
ofrecer_driver_nvidia

# 3. Eliminar dependencias huérfanas que ya no son necesarias
echo "${VERDE}[*] Eliminando dependencias huérfanas (apt-get autoremove)...${RESET}"
apt-get autoremove -y
echo ""

# 4. Limpiar el caché de archivos .deb obsoletos
echo "${VERDE}[*] Limpiando paquetes .deb obsoletos del caché (apt-get autoclean)...${RESET}"
apt-get autoclean
echo "Limpieza realizada [✔]"
echo ""

# 5. Bloque de actualización Flatpak (comprueba si está instalado)
if command -v flatpak &> /dev/null; then
    echo -e "${VERDE}[*] Actualizando aplicaciones Flatpak...${RESET}"
    flatpak update -y && flatpak uninstall --unused -y
else
    echo -e "Flatpak no está instalado en este sistema. Omitiendo..."
fi

echo -e "¡Proceso de actualización completado con éxito!"
echo ""

# 6. Comprobación y gestión de reinicio requerido al finalizar
NECESITA_REINICIO=0

if [ -f /var/run/reboot-required ]; then
    NECESITA_REINICIO=1
fi

if [ "$REINICIO_NVIDIA" -eq 1 ]; then
    NECESITA_REINICIO=1
fi

if command -v needrestart &> /dev/null; then
    echo -e "${VERDE}[*] Comprobación final de servicios y kernel con needrestart...${RESET}"
    SALIDA_NEEDRESTART=$(needrestart -b 2>/dev/null)
    echo "$SALIDA_NEEDRESTART"

    if echo "$SALIDA_NEEDRESTART" | grep -qE "^NEEDRESTART-KSTA: [23]"; then
        NECESITA_REINICIO=1
    fi

    SERVICIOS_CRITICOS="dbus|dbus-broker|gdm|gdm3|lightdm|sddm|systemd-logind|systemd-udevd"
    if echo "$SALIDA_NEEDRESTART" | grep -qE "^NEEDRESTART-SVC: (${SERVICIOS_CRITICOS})\.service$"; then
        NECESITA_REINICIO=1
    fi
fi

if [ "$NECESITA_REINICIO" -eq 1 ]; then
    echo -e "${AMARILLO}--------------------------------------------------${RESET}"
    read -r -p "¿Deseas reiniciar el sistema ahora para aplicar los cambios críticos (Kernel/Servicios)? (s/N): " opcion_reinicio
    case "$opcion_reinicio" in
        [sS]|[sS][iI])
            echo -e "${VERDE}[*] Reiniciando el sistema...${RESET}"
            sleep 2
            reboot
            ;;
        *)
            echo -e "${AZUL}[*] Reinicio omitido. Recuerda reiniciar más tarde.${RESET}"
            ;;
    esac
fi

mostrar_final
