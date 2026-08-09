# Extras

Instaladores opcionales que **no** forman parte del entorno base
(`archdesktopinstall.sh` no los invoca): se corren a mano, sólo en las máquinas
donde hagan falta. Cada script sabe instalarse, desinstalarse y reportar su
estado.

Cada uno vive en su propia carpeta, junto a los archivos que despliegue. Varios tienen
un solo archivo adentro y la carpeta igual va: así el día que un instalador necesite
sumar una plantilla de config, una unit de systemd o una regla de udev, tiene dónde
ponerla sin ensuciar la raíz de `extras/` ni obligar a mover nada después. Los scripts
resuelven las rutas de sus archivos desde su propia ubicación (`BASH_SOURCE`) y no
desde `$PWD`, así que se pueden invocar desde donde sea.

| Carpeta | Qué instala | Uso |
|---|---|---|
| [`virtualization/`](./virtualization/) | QEMU/KVM + libvirt + virt-manager: todo lo necesario para crear y correr máquinas virtuales, incluido UEFI (edk2-ovmf) y TPM emulado (swtpm) para guests Windows 11. | `./virtualization/virtualization.sh install \| uninstall \| status` (sin argumentos: menú) |
| [`docker/`](./docker/) | Docker engine + Compose v2 + buildx: levantar servicios desde `docker-compose.yaml` con `docker compose up`. Suma al usuario al grupo `docker` y habilita el demonio al boot. | `./docker/docker.sh install \| uninstall \| status` (sin argumentos: menú) |
| [`mssql-odbc17/`](./mssql-odbc17/) | Driver Microsoft ODBC 17 for SQL Server (equivalente en Arch a msodbcsql17 + unixODBC-devel de Fedora), con `openssl-1.1`, que el driver necesita sí o sí. Viene de AUR: requiere `yay` ya instalado. `status` no se conforma con ver el driver registrado: comprueba también que el `.so` cargue y que haya un OpenSSL 1.x que el driver sepa abrir, así te dice si tu app va a poder usarlo. | `./mssql-odbc17/mssql-odbc17.sh install \| uninstall \| status` (sin argumentos: menú) |

## Modo de arranque

Los dos `install` preguntan cómo debe arrancar el demonio:

| Modo | Qué implica |
|---|---|
| **Al boot** (`.service`) | El demonio corre desde el arranque. Los contenedores con `restart: always` y las VMs con autostart vuelven solos tras un reboot. |
| **Bajo demanda** (`.socket`) | systemd escucha el socket sin el demonio; lo arranca al primer uso (`docker ps`, virt-manager). Nada vuelve solo tras un reboot. |

Medido en el notebook con los dos stacks activos: ~100 MB de RAM Docker
(dockerd + containerd), ~32 MB libvirtd, y unos 2.5 s de arranque entre los
tres. El consumo de CPU en reposo es nulo (≈10 s de CPU en un día entero): son
demonios dirigidos por eventos, no hacen polling.

Con eso, **bajo demanda conviene si no tenés servicios que deban sobrevivir a un
reboot**; el ahorro real es el tiempo de arranque y no gastar nada los días que
no usás el stack. Ojo: el socket arranca el demonio pero no lo apaga al quedar
ocioso — una vez levantado sigue vivo hasta el próximo reboot.

`status` informa en qué modo quedó cada uno, y volver a correr `install` permite
cambiarlo.

## Convenciones

- Una carpeta por entorno: el script, con `install`/`uninstall`/`status`, más los
  archivos que despliegue.
- No ejecutarlos como root: piden `sudo` puntualmente, igual que el instalador
  principal.
- `uninstall` nunca borra datos del usuario (discos de VMs, configs); dice dónde
  quedan y cómo borrarlos a mano.
