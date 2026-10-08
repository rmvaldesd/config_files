// Quickshell entry point for the desktop visors.
//
// Run standalone for testing:
//   qs -c visors
//
// One daemon hosts every visor (a Quickshell instance costs ~150 MB idle, so they
// share it). Each panel is toggled over its own IPC target:
//
//   qs ipc -c visors call cpuvisor toggle     (bin_configs/cpu-visor)
//   qs ipc -c visors call powervisor toggle   (bin_configs/power-visor)
//
// They all anchor to the same corner, so `sibling` makes opening one dismiss the
// other. The configuration is a named directory under ~/.config/quickshell, which
// this repo links from dotconfig/quickshell (see scripts/update.sh); Hyprland
// starts it at login.
import QtQuick
import Quickshell

ShellRoot {
    CpuVisor {
        id: cpuVisor
        sibling: powerVisor
    }

    PowerVisor {
        id: powerVisor
        sibling: cpuVisor
    }
}
