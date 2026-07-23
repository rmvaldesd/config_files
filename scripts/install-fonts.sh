#!/usr/bin/env bash
# Instala las fuentes versionadas en config_files/fonts como fuentes del usuario.
# Funciona en cualquier distro (Arch, Fedora, etc.): no depende de paquetes del sistema.
# En Arch lo invoca archdesktopinstall.sh; en Fedora ejecútalo a mano una vez:
#   bash ~/config_files/scripts/install-fonts.sh
set -e

mkdir -p "$HOME/.local/share/fonts"

# Symlink al directorio del repo: si agregas más fuentes a config_files/fonts,
# basta re-ejecutar este script (o solo fc-cache) para que aparezcan.
ln -sfn "$HOME/config_files/fonts" "$HOME/.local/share/fonts/config_files-fonts"

# Regenera el cache de fontconfig para que las apps vean las fuentes de inmediato
fc-cache -f "$HOME/.local/share/fonts" > /dev/null

echo "-> Fuentes de ~/config_files/fonts instaladas para el usuario (via ~/.local/share/fonts)."
