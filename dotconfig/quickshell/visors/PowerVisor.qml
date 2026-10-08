import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Smooth power-profile visor, revealed by clicking the Waybar power-profile
// module. Same shell/daemon and positioning as the CPU visor (CpuVisor.qml), so
// `sibling` makes opening one dismiss the other.
//
//   qs ipc -c visors call powervisor toggle
//
// The profile is read and written through Quickshell's UPower service, so the
// panel is reactive: `PowerProfiles.profile` changes the moment the daemon
// reports a change, wherever it came from.
//
// Palette mirrors dotconfig/waybar/style.css (Tailwind Zinc + cyan/coral),
// duplicated from CpuVisor.qml on purpose: two small files, no shared singleton
// to wire up. Keep the two in sync if the theme shifts.
PanelWindow {
    id: pwin

    // ---- palette (Tailwind Zinc, see dotconfig/waybar/style.css) ----
    readonly property color cBg: "#18181b"      // zinc-950
    readonly property color cSurface: "#27272a" // zinc-800
    readonly property color cHover: Qt.rgba(0.98, 0.98, 1, 0.05)
    readonly property color cRule: "#3f3f46"    // zinc-700
    readonly property color cMuted: "#71717a"   // zinc-500
    readonly property color cSoft: "#a1a1aa"    // zinc-400
    readonly property color cText: "#fafafa"    // zinc-50
    readonly property color cAccent: "#75f1fa"  // cyan (current profile)

    readonly property string mono: "JetBrains Mono"
    readonly property int cardWidth: 300
    readonly property int pad: 14

    property var sibling: null
    property bool shown: false

    /// Pointer position at open time (from the wrapper's hyprctl cursorpos).
    /// -1 = unknown -> fall back to the bar's right corner.
    property int pointerX: -1
    property int pointerY: -1

    // Nerd Font glyph codepoints (same icons the old built-in Waybar module used):
    // performance, balanced, power-saver.
    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    readonly property var allProfiles: [
        { key: PowerProfile.Performance, name: "performance", label: "Performance",
          icon: 0xF04C5, hint: "Maximum clocks" },
        { key: PowerProfile.Balanced, name: "balanced", label: "Balanced",
          icon: 0xF0F85, hint: "Default" },
        { key: PowerProfile.PowerSaver, name: "power-saver", label: "Power Saver",
          icon: 0xF032A, hint: "Lower clocks, less heat" }
    ]

    // One less row on machines whose driver has no performance mode.
    readonly property var profiles: {
        const out = [];
        for (let i = 0; i < allProfiles.length; i++) {
            const p = allProfiles[i];
            if (p.key === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
                continue;
            out.push(p);
        }
        return out;
    }

    function select(key) {
        PowerProfiles.profile = key;
        // Tell Waybar to re-run custom/power-profile right away instead of waiting
        // for its (deliberately long) interval. See the module's "signal": 7.
        if (!signalWaybar.running)
            signalWaybar.running = true;
    }

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
        const s = pwin.screen;
        if (pwin.pointerX < 0)
            return s ? Math.max(0, s.width - pwin.cardWidth - 8) : 8;
        const sx = s ? s.x : 0;
        const sw = s ? s.width : 1920;
        let left = pwin.pointerX - pwin.cardWidth / 2;
        left = Math.max(sx, Math.min(sx + sw - pwin.cardWidth, left));
        return Math.max(0, left - sx);
    }

    function toggle() {
        if (shown)
            dismiss();
        else
            open();
    }

    function open() {
        pwin.pointerX = -1;
        pwin.pointerY = -1;
        reveal();
    }

    function openAt(x, y) {
        const s = screenAt(x, y);
        if (s)
            pwin.screen = s;
        pwin.pointerX = x;
        pwin.pointerY = y;
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
        hideTimer.restart();
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
        left: pwin.horizontalMargin()
    }
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"

    WlrLayershell.namespace: "powervisor"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand: takes keyboard focus only once clicked, so Esc closes it without
    // stealing keystrokes from the app below the rest of the time.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    Shortcut {
        sequence: "Escape"
        onActivated: pwin.dismiss()
    }

    IpcHandler {
        target: "powervisor"

        function toggle() { pwin.toggle(); }
        function open() { pwin.open(); }
        function close() { pwin.dismiss(); }

        // Positioned at the click: see openAt/horizontalMargin.
        function openAt(x: int, y: int) { pwin.openAt(x, y); }
        function toggleAt(x: int, y: int) {
            if (pwin.shown)
                pwin.dismiss();
            else
                pwin.openAt(x, y);
        }

        // Handy for keybinds and testing: "performance" | "balanced" | "power-saver".
        // The parameter is typed because IPC cannot marshal an untyped QVariant.
        function set(name: string) {
            for (let i = 0; i < pwin.allProfiles.length; i++) {
                if (pwin.allProfiles[i].name === name) {
                    pwin.select(pwin.allProfiles[i].key);
                    return;
                }
            }
        }
    }

    Process {
        id: signalWaybar
        command: ["pkill", "-SIGRTMIN+7", "waybar"]
        running: false
    }

    Rectangle {
        id: card

        width: pwin.cardWidth
        height: layout.implicitHeight + 2 * pwin.pad
        radius: 14
        color: pwin.cBg
        border.width: 1
        border.color: pwin.cRule

        opacity: pwin.shown ? 1 : 0
        scale: pwin.shown ? 1 : 0.95
        transformOrigin: Item.Top
        transform: Translate {
            y: pwin.shown ? 0 : -10
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
                margins: pwin.pad
            }
            spacing: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "POWER PROFILE"
                    color: pwin.cMuted
                    font.family: pwin.mono
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "\u2715"
                    color: pwin.cMuted
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pwin.dismiss()
                    }
                }
            }

            // ---- profile rows ----
            Repeater {
                model: pwin.profiles

                delegate: Rectangle {
                    id: row

                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 8
                    color: row.selected ? pwin.cSurface
                                        : (row.hovered ? pwin.cHover : "transparent")
                    border.width: row.selected ? 1 : 0
                    border.color: pwin.cRule

                    property bool selected: PowerProfiles.profile === modelData.key
                    property bool hovered: false

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 12

                        Text {
                            text: pwin.glyph(modelData.icon)
                            color: row.selected ? pwin.cAccent : pwin.cMuted
                            font.family: pwin.mono
                            font.pixelSize: 18
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: modelData.label
                                color: row.selected ? pwin.cText : pwin.cSoft
                                font.family: pwin.mono
                                font.pixelSize: 13
                                font.bold: row.selected
                            }
                            Text {
                                text: modelData.hint
                                color: pwin.cMuted
                                font.family: pwin.mono
                                font.pixelSize: 9
                            }
                        }
                        Text {
                            text: "\u2713"
                            visible: row.selected
                            color: pwin.cAccent
                            font.family: pwin.mono
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: row.hovered = true
                        onExited: row.hovered = false
                        onClicked: pwin.select(modelData.key)
                    }
                }
            }
        }
    }
}
