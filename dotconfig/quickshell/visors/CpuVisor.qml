import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Smooth CPU visor, revealed by clicking the Waybar CPU module.
//
// It is a small layer-shell panel anchored under the icon that was clicked: the
// wrapper reads the pointer with hyprctl and passes it to openAt/toggleAt, and
// the panel centres on it (clamped to the screen). With no pointer info it
// falls back to the bar's right corner. The surface is only as large as the
// card, so it never covers or blocks anything else on screen. Visibility is
// toggled over Quickshell IPC:
//
//   qs ipc -c visors call cpuvisor toggle
//
// (bin_configs/cpu-visor wraps that, and starts the daemon on the first click).
//
// The palette mirrors the Tailwind Zinc scale used by waybar/hyprland/rofi/mako,
// with the same cyan for progress and coral for pressure, so the visor reads as
// part of the dark desktop instead of a separate app.
PanelWindow {
    id: win

    // ---- palette (Tailwind Zinc, see dotconfig/waybar/style.css) ----
    readonly property color cBg: "#18181b"      // zinc-950
    readonly property color cSurface: "#27272a" // zinc-800
    readonly property color cRule: "#3f3f46"    // zinc-700
    readonly property color cMuted: "#71717a"   // zinc-500
    readonly property color cSoft: "#a1a1aa"    // zinc-400
    readonly property color cText: "#fafafa"    // zinc-50
    readonly property color cAccent: "#75f1fa"  // cyan (progress)
    readonly property color cUrgent: "#e35149"  // coral (pressure)

    readonly property string mono: "JetBrains Mono"
    readonly property int cardWidth: 430
    readonly property int pad: 16
    readonly property int highWater: 85 // when a value turns coral

    property bool shown: false

    /// The other visor in this shell. Opening one dismisses the other so they
    /// never stack in the same corner; wired in shell.qml.
    property var sibling: null

    /// Pointer position at open time, passed by the wrapper (hyprctl cursorpos).
    /// -1 = unknown -> fall back to hugging the bar's right corner.
    property int pointerX: -1
    property int pointerY: -1

    function screenAt(x, y) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                return s;
        }
        return null;
    }

    // Left margin of the panel within its screen: centred under the icon that was
    // clicked, clamped so the panel never leaves the screen.
    function horizontalMargin() {
        const s = win.screen;
        if (win.pointerX < 0)
            return s ? Math.max(0, s.width - win.cardWidth - 8) : 8;
        const sx = s ? s.x : 0;
        const sw = s ? s.width : 1920;
        let left = win.pointerX - win.cardWidth / 2;
        left = Math.max(sx, Math.min(sx + sw - win.cardWidth, left));
        return Math.max(0, left - sx);
    }

    function toggle() {
        if (shown)
            dismiss();
        else
            open();
    }

    function open() {
        win.pointerX = -1;
        win.pointerY = -1;
        reveal();
    }

    function openAt(x, y) {
        const s = screenAt(x, y);
        if (s)
            win.screen = s;
        win.pointerX = x;
        win.pointerY = y;
        reveal();
    }

    function reveal() {
        if (sibling && sibling.dismiss)
            sibling.dismiss();
        hideTimer.stop();
        shown = true;
    }

    function dismiss() {
        if (!shown)
            return;
        shown = false;
        hideTimer.restart(); // keep the surface mapped through the fade-out
    }

    function barColor(v) {
        return v >= win.highWater ? win.cUrgent : win.cAccent;
    }

    function loadText() {
        if (!sampler.load || sampler.load.length < 3)
            return "\u2014  \u2014  \u2014";
        return sampler.load[0].toFixed(2) + "  "
             + sampler.load[1].toFixed(2) + "  "
             + sampler.load[2].toFixed(2);
    }

    // Reserve the final layout before the first sample lands, so the reveal never
    // resizes as data arrives. `coreCount` comes from nproc; the process list is
    // padded to `topN` rows with inert placeholders.
    readonly property int topN: 5

    function zeroList(n) {
        var a = [];
        for (var i = 0; i < n; i++)
            a.push(0);
        return a;
    }

    readonly property var coreModel:
        sampler.cores.length > 0 ? sampler.cores : zeroList(sampler.coreCount)

    readonly property var procModel: {
        if (sampler.procs.length > 0)
            return sampler.procs;
        var a = [];
        for (var i = 0; i < topN; i++)
            a.push({ name: "\u2014", pid: 0, cpu: -1, machine: -1, rss_mb: -1 });
        return a;
    }

    function pidText(p) {
        return p.pid > 0 ? "#" + p.pid : "";
    }

    // Main figure: the process's share of the whole machine, so it shares its
    // denominator with the overall percentage (0..100, never >100).
    function cpuText(p) {
        return p.machine >= 0 ? p.machine.toFixed(1) + "%" : "";
    }

    // Second figure: the same work as the sum of load across cores (top/htop
    // scale), so a process on two full threads reads as 200%.
    function perCoreText(p) {
        return p.cpu >= 0 ? p.cpu.toFixed(1) + "%" : "";
    }

    function memText(p) {
        return p.rss_mb >= 0 ? p.rss_mb.toFixed(0) + "M" : "";
    }

    // Mapped while shown and, briefly, while the exit animation plays.
    visible: shown || hideTimer.running
    Timer {
        id: hideTimer
        interval: 220
    }

    anchors {
        top: true
        left: true
    }
    // 41 = WAYBAR_HEIGHT (35, ~/.local_host_settings) + a small gap. 'left' is
    // computed from the click position (see horizontalMargin); with no pointer
    // info it lands at the bar's right corner, like before.
    margins {
        top: 41
        left: win.horizontalMargin()
    }
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"

    WlrLayershell.namespace: "cpuvisor"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand: the visor takes keyboard focus only once it is clicked, so Esc
    // below works while typing in the app underneath is never interrupted.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    // Esc closes the visor while it holds focus (after clicking it). See the
    // keyboardFocus note above.
    Shortcut {
        sequence: "Escape"
        onActivated: win.dismiss()
    }

    IpcHandler {
        target: "cpuvisor"

        function toggle() { win.toggle(); }
        function open() { win.open(); }
        function close() { win.dismiss(); }

        // Positioned at the click: see openAt/horizontalMargin. Typed ints because
        // IPC cannot marshal untyped QVariant arguments.
        function openAt(x: int, y: int) { win.openAt(x, y); }
        function toggleAt(x: int, y: int) {
            if (win.shown)
                win.dismiss();
            else
                win.openAt(x, y);
        }
    }

    CpuSampler {
        id: sampler
        active: win.shown
    }

    Rectangle {
        id: card

        width: win.cardWidth
        height: layout.implicitHeight + 2 * win.pad
        radius: 14
        color: win.cBg
        border.width: 1
        border.color: win.cRule

        // Reveal: fade in while growing down from the clicked icon (top-center).
        // The Behaviors also run backwards when toggling off, so hide is smooth.
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.95
        transformOrigin: Item.Top
        transform: Translate {
            y: win.shown ? 0 : -10
            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: layout

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: win.pad
            }
            spacing: 12

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "CPU"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "\u2715"
                    color: win.cMuted
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.toggle()
                    }
                }
            }

            // ---- overall usage + load average ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: sampler.ready ? sampler.total + "%" : "\u2014"
                    color: sampler.total >= win.highWater ? win.cUrgent : win.cText
                    font.family: win.mono
                    font.pixelSize: 36
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignBottom
                    spacing: 1
                    Text {
                        text: "LOAD AVG"
                        color: win.cMuted
                        font.family: win.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    Text {
                        text: win.loadText()
                        color: win.cSoft
                        font.family: win.mono
                        font.pixelSize: 11
                    }
                }
            }

            // ---- overall bar ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: win.cSurface

                Rectangle {
                    width: parent.width * Math.min(1, sampler.total / 100)
                    height: parent.height
                    radius: 3
                    color: win.barColor(sampler.total)
                    Behavior on width {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: win.cRule
            }

            // ---- per-core grid ----
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "PER-CORE"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: (sampler.cores.length > 0 ? sampler.cores.length : sampler.coreCount)
                          + " threads"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 9
                }
            }

            Flow {
                id: coreFlow

                Layout.fillWidth: true
                Layout.preferredHeight: Math.ceil(win.coreModel.length / 7) * 48
                spacing: 0

                readonly property int columns: 7
                // Floor, not the exact division: 7 * (width / 7) can come out a
                // hair above width in floating point, which makes Flow wrap at 6
                // per row and overflow its reserved height.
                readonly property real cellW: Math.floor(width / columns)

                Repeater {
                    model: win.coreModel

                    delegate: Item {
                        id: cell
                        width: coreFlow.cellW
                        height: 48

                        property int value: modelData

                        Rectangle {
                            id: track
                            width: 18
                            height: 30
                            radius: 4
                            color: win.cSurface
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                radius: 4
                                color: win.barColor(cell.value)
                                height: parent.height * Math.max(
                                    cell.value > 0 ? 0.04 : 0,
                                    Math.min(1, cell.value / 100))
                                Behavior on height {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                        Text {
                            anchors {
                                top: track.bottom
                                topMargin: 3
                                horizontalCenter: parent.horizontalCenter
                            }
                            text: index
                            color: win.cMuted
                            font.family: win.mono
                            font.pixelSize: 9
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: win.cRule
            }

            // ---- top processes ----
            // MACHINE is the process's share of every CPU combined (matches the
            // overall %); CPU is the same work summed across cores (top/htop
            // scale, can exceed 100%). A process using >=1 full core turns coral.
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Text {
                    text: "TOP PROCESSES"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                Item { Layout.preferredWidth: 44 }
                Text {
                    text: "MACHINE"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 52
                }
                Text {
                    text: "CPU"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 52
                }
                Text {
                    text: "MEM"
                    color: win.cMuted
                    font.family: win.mono
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 48
                }
            }

            Repeater {
                model: win.procModel

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: win.cText
                        font.family: win.mono
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        text: win.pidText(modelData)
                        color: win.cMuted
                        font.family: win.mono
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 44
                    }
                    Text {
                        text: win.cpuText(modelData)
                        color: modelData.cpu >= 100 ? win.cUrgent : win.cAccent
                        font.family: win.mono
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 52
                    }
                    Text {
                        text: win.perCoreText(modelData)
                        color: win.cSoft
                        font.family: win.mono
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 52
                    }
                    Text {
                        text: win.memText(modelData)
                        color: win.cMuted
                        font.family: win.mono
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 48
                    }
                }
            }
        }
    }
}
