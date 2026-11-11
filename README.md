# aio-debian
AIO app for configuring and maintaining Debian.

Install with:
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

This adds the repository and the signing key, installs the package, and creates an “AiO Debian” launcher in the menu. The --force-confnew option prevents `dpkg` from prompting about the source file, which is also installed by the package.

After installation

To update to the latest version, run: `sudo apt update && sudo apt upgrade`. If you wish to update only this application, use: `sudo apt install --only-upgrade aio-debian`.
To launch the application, run `aio-debian` or select it from your applications menu.
To uninstall it, run `sudo apt remove aio-debian`. Note that this does not remove the repository; to remove it as well, use `sudo apt purge aio-debian`, which also deletes the source file.

