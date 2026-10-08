import QtQuick
import Quickshell
import Quickshell.Io

// Data bridge for the CPU visor.
//
// Runs `cpu-sampler` while `active` is true and exposes the last JSON sample as
// plain properties (total, cores, load, procs). The sampler streams one JSON
// object per line, so a SplitParser feeds it straight into _consume().
//
// `active` is wired to the panel's shown state: Quickshell kills the child
// process when it flips false, so the sampler does no work while the visor is
// off screen (it costs ~1% of one core while running).
//
// `coreCount` is read once at startup with nproc. The panel uses it to reserve
// the per-core grid before the first sample lands, so the first reveal does not
// resize as data arrives. See cpu-sampler for the wire format.
Item {
    id: root

    property bool active: false

    /// Number of logical CPUs, fetched once. 0 until nproc replies.
    property int coreCount: 0

    /// Absolute path of the sampler sitting next to this file. Quickshell
    /// resolves it even though the config is reached through a symlink.
    readonly property string samplerPath: Quickshell.shellDir + "/cpu-sampler"

    property int total: 0
    property var cores: []
    property var load: [0.0, 0.0, 0.0]
    property var procs: []
    property bool ready: false

    // The component is pure logic; it must not draw or take space in the panel.
    visible: false
    width: 0
    height: 0

    function _consume(line) {
        if (!line)
            return;
        try {
            const o = JSON.parse(line);
            root.total = o.total;
            root.cores = o.cores;
            root.load = o.load;
            root.procs = o.top;
            root.ready = true;
        } catch (e) {
            console.warn("cpuvisor: could not parse sample: " + e);
        }
    }

    Process {
        command: ["nproc"]
        running: true

        stdout: SplitParser {
            onRead: function(line) {
                const n = parseInt(line, 10);
                if (n > 0)
                    root.coreCount = n;
            }
        }
    }

    Process {
        command: [root.samplerPath, "--interval", "1.0", "--first-window", "0.4", "--top", "5"]
        running: root.active

        stdout: SplitParser {
            onRead: function(line) {
                root._consume(line);
            }
        }
    }
}
