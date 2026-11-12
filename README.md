# aio-debian

Script todo en uno de **mantenimiento y configuración para Debian**.

## Qué hace

- Muestra información del sistema (versión, kernel, disco, antigüedad de la instalación),
  además de la versión de aio-debian y sus novedades.
- Sincroniza el reloj por NTP si hace falta.
- Añade los componentes `contrib` y `non-free` a los repositorios oficiales de Debian
  (hace una copia `.bak` de cada archivo que modifica; no toca repositorios de terceros).
- Actualiza el sistema (`apt-get update`, `dist-upgrade`, `autoremove`, `autoclean`).
- Instala automáticamente `needrestart`, `fastfetch`, `kitty` y `synaptic` si no están.
- Ofrece instalar Flatpak + Flathub, el plugin de Flatpak para GNOME Software y
  Extension Manager (con confirmación previa).
- Actualiza Flatpak y pregunta si reiniciar cuando kernel o servicios críticos lo requieren.
- **Solo en el canal `testing`:** detecta una gráfica NVIDIA y ofrece instalar el driver
  adecuado (con confirmación previa).

> Necesita permisos de administrador y **modifica la configuración de APT**. Revisa el
> script ([`src/aio-debian.sh`](src/aio-debian.sh)) antes de ejecutarlo si quieres saber
> exactamente qué hace.

## Instalación

### Instalación rápida (una línea)

```
curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo bash
```

Si tu equipo no tiene `curl`, este comando lo instala primero:

```
sudo sh -c 'apt-get update -qq && apt-get install -y curl ca-certificates' && curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo bash
```

### Paso a paso

Una sola vez, en cualquier Debian (o derivada):

```
sudo apt install -y curl ca-certificates
sudo curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/aio-debian.gpg -o /usr/share/keyrings/aio-debian.gpg
sudo tee /etc/apt/sources.list.d/aio-debian.sources >/dev/null <<'EOF'
Types: deb
URIs: https://julioayusoalende-hue.github.io/aio-debian
Suites: stable
Components: main
Architectures: all
Signed-By: /usr/share/keyrings/aio-debian.gpg
EOF
sudo apt update
sudo apt install -o Dpkg::Options::=--force-confnew aio-debian
```

### Canal de pruebas (testing)

Para recibir antes las novedades, aún sin estabilizar (incluye el driver NVIDIA):

```
curl -fsSL https://julioayusoalende-hue.github.io/aio-debian/install.sh | sudo AIO_SUITE=testing bash
```

Para volver al canal estable, edita `/etc/apt/sources.list.d/aio-debian.sources` y pon
`Suites: stable`.

## Uso

```
sudo aio-debian
```

O desde el menú de aplicaciones: **AiO Debian**.

## Actualizar

```
sudo apt update && sudo apt upgrade
```

## Desinstalar

```
sudo apt purge aio-debian
```

Esto también elimina el archivo de fuentes del repositorio.

## Licencia

GNU GPL v3 o posterior. Ver [LICENSE](LICENSE).
