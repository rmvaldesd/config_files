# Linux

OS, desktop, and command-line notes. This is a starter — add docs as you go and
link them below.

## Suggested topics

- Desktop / window manager. El entorno actual es Hyprland (ver
  [`../hyprland/`](../hyprland/)). Como referencia histórica queda `suckless/`
  con los parches de dwm, más [`../../notes_and_instructions/dwm_shortcuts`](../../notes_and_instructions/dwm_shortcuts)
  e `installed_programs_dwm.txt`. El `xinitrc` que lanzaba esa sesión se eliminó:
  estaba roto (invocaba un `bin_configs/dwm_status` inexistente) y ninguna de sus
  herramientas sigue instalada.
- Package management / provisioning — el script que reproduce el equipo entero es
  [`../../archdesktopinstall.sh`](../../archdesktopinstall.sh): paquetes,
  servicios, symlinks de los dotfiles y ajustes de sistema, todo comentado paso a
  paso. El `install-macos-brew-packages.sh` que se enlazaba acá ya no está en el
  repo.
- Common CLI recipes, systemd units, networking, troubleshooting.

## Docs

<!-- Add entries as you create them, e.g.:
- [dwm & X setup](./dwm.md)
- [CLI recipes](./cli-recipes.md)
-->

- [Impresión wifi (CUPS + Avahi)](./impresion.md) — cómo descubre la impresora,
  el conflicto mDNS con systemd-resolved, la regla de ufw, drivers por marca y
  diagnóstico.
- [DBeaver en Wayland](./dbeaver.md) — por qué no lleva configuración, por qué
  forzar XWayland lo empeora a escala 2x, y cómo subirle la memoria sin que la
  próxima actualización se lo lleve.
- [Spotify en Wayland](./spotify.md) — los flags de Ozone que lo sacan de
  XWayland para que deje de verse borroso, por qué
  `ELECTRON_OZONE_PLATFORM_HINT` no le aplica y por qué no hay que forzar la
  escala a mano.
- [Teams for Linux: la X y la bandeja que no existe](./teams.md) — por qué la
  ventana desaparecía sin dejar rastro (se escondía a una bandeja inexistente,
  porque waybar no tiene módulo `tray`), el `closeAppOnCross` que lo arregla, el
  bug de `Waiting for network...`, cómo rescatar una ventana ya escondida y el
  `.desktop` override que lo arranca en Wayland nativo.
