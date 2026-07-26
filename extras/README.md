# Extras

Instaladores opcionales que **no** forman parte del entorno base
(`archdesktopinstall.sh` no los invoca): se corren a mano, sólo en las máquinas
donde hagan falta. Cada script sabe instalarse, desinstalarse y reportar su
estado.

| Script | Qué instala | Uso |
|---|---|---|
| [`virtualization.sh`](./virtualization.sh) | QEMU/KVM + libvirt + virt-manager: todo lo necesario para crear y correr máquinas virtuales, incluido UEFI (edk2-ovmf) y TPM emulado (swtpm) para guests Windows 11. | `./virtualization.sh install \| uninstall \| status` (sin argumentos: menú) |
| [`docker.sh`](./docker.sh) | Docker engine + Compose v2 + buildx: levantar servicios desde `docker-compose.yaml` con `docker compose up`. Suma al usuario al grupo `docker` y habilita el demonio al boot. | `./docker.sh install \| uninstall \| status` (sin argumentos: menú) |

## Convenciones

- Un script por entorno, autocontenido, con `install`/`uninstall`/`status`.
- No ejecutarlos como root: piden `sudo` puntualmente, igual que el instalador
  principal.
- `uninstall` nunca borra datos del usuario (discos de VMs, configs); dice dónde
  quedan y cómo borrarlos a mano.
