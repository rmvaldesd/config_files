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
- Package management / provisioning — see
  [`../../install-macos-brew-packages.sh`](../../install-macos-brew-packages.sh).
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
