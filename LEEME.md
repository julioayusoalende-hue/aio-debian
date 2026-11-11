# aio-debian — repositorio APT

## Primera vez
1. Crea un repositorio en GitHub llamado `aio-debian` (público).
2. Edita `config.env` y pon tu usuario de GitHub.
3. Ejecuta `./publicar.sh` (crea tu clave GPG de firma, construye el .deb y el repo en `docs/`).
4. Sube todo:
   ```
   git init && git add -A && git commit -m "aio-debian 1.0.0"
   git branch -M main
   git remote add origin git@github.com:TU_USUARIO/aio-debian.git
   git push -u origin main
   ```
5. En GitHub: Settings > Pages > Source: rama `main`, carpeta `/docs`.

## Instalar en un equipo
```
curl -fsSLO https://TU_USUARIO.github.io/aio-debian/pool/main/aio-debian_1.0.0_all.deb
sudo apt install ./aio-debian_1.0.0_all.deb
```
El .deb añade el repositorio y la clave; a partir de ahí:
`sudo apt update && sudo apt upgrade` (o tu propio script) actualiza la app.

## Publicar una actualización
1. Edita `src/aio-debian.sh`.
2. `./publicar.sh 1.1.0`
3. `git add -A && git commit -m "aio-debian 1.1.0" && git push`

## Importante
- Tu clave privada vive en tu `~/.gnupg`: haz copia de seguridad. Si la pierdes,
  los equipos instalados no aceptarán un repo firmado con otra clave.
- La clave caduca a los 5 años; renuévala antes con `gpg --quick-set-expire`.
