import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

import "Format.js" as Fmt

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal

    readonly property string iface: cfg.interfaceName || "all"
    readonly property int interval: Math.max(250, cfg.sampleInterval)
    // Number of samples the history graph spans.
    readonly property int capacity: Math.max(2, Math.ceil(cfg.historyMinutes * 60000 / interval) + 1)
    readonly property bool useBits: cfg.useBits
    readonly property bool binary: cfg.binaryPrefixes
    readonly property color downloadColor: cfg.downloadColor
    readonly property color uploadColor: cfg.uploadColor

    // Sample history. Arrays are mutated in place; `revision` bumps on every
    // sample so views know to repaint.
    readonly property var history: ({ dl: [], ul: [] })
    property int revision: 0

    property real download: 0
    property real upload: 0

    function sample() {
        const d = Math.max(0, Number(dlSensor.value) || 0);
        const u = Math.max(0, Number(ulSensor.value) || 0);
        download = d;
        upload = u;
        history.dl.push(d);
        history.ul.push(u);
        const excess = history.dl.length - capacity;
        if (excess > 0) {
            history.dl.splice(0, excess);
            history.ul.splice(0, excess);
        }
        countUsage();
        revision++;
    }

    function resetHistory() {
        history.dl.length = 0;
        history.ul.length = 0;
        revision++;
    }

    onIfaceChanged: {
        resetHistory();
        // counters of the new interface are unrelated to the old baseline
        lastTotalDown = -1;
        lastTotalUp = -1;
    }
    onIntervalChanged: resetHistory()

    Sensors.Sensor {
        id: dlSensor
        sensorId: "network/" + root.iface + "/download"
        updateRateLimit: root.interval
    }
    Sensors.Sensor {
        id: ulSensor
        sensorId: "network/" + root.iface + "/upload"
        updateRateLimit: root.interval
    }
    // Kernel byte counters since boot (exact), used for the usage totals.
    Sensors.Sensor {
        id: totalDlSensor
        sensorId: "network/" + root.iface + "/totalDownload"
        updateRateLimit: root.interval
    }
    Sensors.Sensor {
        id: totalUlSensor
        sensorId: "network/" + root.iface + "/totalUpload"
        updateRateLimit: root.interval
    }

    // ---- daily / monthly usage totals --------------------------------------
    // Bytes per day and per month, persisted in the config. Counted as the
    // growth of the kernel counters between samples. If the counters go
    // backwards (reboot, interface reset) counting resumes from the new value.
    property var usage: ({ days: {}, months: {} })
    property int usageRevision: 0
    property real lastTotalDown: -1
    property real lastTotalUp: -1
    property bool usageDirty: false

    function dayKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }
    function monthKey(date) {
        return Qt.formatDate(date, "yyyy-MM");
    }
    // [down, up] in bytes
    function usageFor(table, key) {
        return usage[table][key] || [0, 0];
    }
    readonly property var usageToday: { usageRevision; return usageFor("days", dayKey(new Date())); }
    readonly property var usageMonth: { usageRevision; return usageFor("months", monthKey(new Date())); }

    function loadUsage() {
        try {
            const u = JSON.parse(cfg.usageData || "{}");
            usage = { days: u.days || {}, months: u.months || {} };
        } catch (e) {
            usage = { days: {}, months: {} };
        }
        const b = (cfg.usageBaseline || "").split(" ");
        if (b.length === 3 && b[0] === iface) {
            lastTotalDown = Number(b[1]);
            lastTotalUp = Number(b[2]);
        }
        usageRevision++;
    }

    function countUsage() {
        const td = Number(totalDlSensor.value), tu = Number(totalUlSensor.value);
        if (!(td > 0 || tu > 0))
            return; // sensor not ready yet
        if (lastTotalDown >= 0 && td >= lastTotalDown && tu >= lastTotalUp) {
            const dd = td - lastTotalDown, du = tu - lastTotalUp;
            if (dd > 0 || du > 0) {
                const now = new Date();
                for (const [table, key] of [["days", dayKey(now)], ["months", monthKey(now)]]) {
                    const v = usage[table][key] || [0, 0];
                    usage[table][key] = [v[0] + dd, v[1] + du];
                }
                usageDirty = true;
                usageRevision++;
            }
        } else if (lastTotalDown !== td || lastTotalUp !== tu) {
            usageDirty = true; // new baseline to save
        }
        lastTotalDown = td;
        lastTotalUp = tu;
    }

    // Keep the newest `keep` keys of a table (keys sort chronologically).
    function prune(table, keep) {
        const keys = Object.keys(table).sort();
        for (let i = 0; i < keys.length - keep; i++)
            delete table[keys[i]];
    }
    function saveUsage() {
        if (!usageDirty)
            return;
        prune(usage.days, 62);
        prune(usage.months, 36);
        cfg.usageData = JSON.stringify(usage);
        if (lastTotalDown >= 0)
            cfg.usageBaseline = iface + " " + lastTotalDown + " " + lastTotalUp;
        usageDirty = false;
    }
    Component.onCompleted: loadUsage()
    Component.onDestruction: saveUsage()
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.saveUsage()
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        onTriggered: root.sample()
    }

    Plasmoid.icon: "network-transmit-receive"
    // ---- hover tooltip (contents chosen in Settings → Panel) ---------------
    // Both texts empty means Plasma shows no tooltip at all.
    toolTipMainText: !cfg.tooltipShowTitle ? ""
        : root.iface === "all" ? i18n("Network (all interfaces)") : i18n("Network: %1", root.iface)
    toolTipSubText: {
        const rate = v => Fmt.rate(v, useBits, binary);
        const size = v => Fmt.size(v, binary);
        const pair = (label, d, u) => label + ": ↓ " + d + "  ↑ " + u;
        const lines = [];
        if (cfg.tooltipShowSpeed)
            lines.push("↓ " + rate(download), "↑ " + rate(upload));
        if (cfg.tooltipShowPeakAverage) {
            revision; // recompute as samples arrive
            const dl = history.dl, ul = history.ul;
            let dp = 0, up = 0, ds = 0, us = 0;
            for (let i = 0; i < dl.length; i++) {
                dp = Math.max(dp, dl[i]);
                up = Math.max(up, ul[i]);
                ds += dl[i];
                us += ul[i];
            }
            const n = Math.max(1, dl.length);
            lines.push(pair(i18n("Peak"), rate(dp), rate(up)), pair(i18n("Average"), rate(ds / n), rate(us / n)));
        }
        if (cfg.tooltipShowToday)
            lines.push(pair(i18n("Today"), size(usageToday[0]), size(usageToday[1])));
        if (cfg.tooltipShowMonth)
            lines.push(pair(i18n("This month"), size(usageMonth[0]), size(usageMonth[1])));
        return lines.join("\n");
    }

    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactView { meter: root }
    fullRepresentation: FullView { meter: root }

    function configure() {
        Plasmoid.internalAction("configure").trigger();
    }

    // ---- styles -----------------------------------------------------------
    // A style is a named set of appearance keys. Switching away from a style
    // remembers its current values (in savedStyles) so tweaks survive a
    // round trip; "Reset Style" goes back to the built-in values.
    readonly property var presets: ({
        classic: {
            downloadColor: "#d42a00", uploadColor: "#e8c200", useBits: true,
            graphMode: 0, graphStyle: 2, fillOpacity: 100, lineWidth: 1, scaleMode: 0, logScale: false,
            showGrid: false, showTimeGrid: true, dottedTimeGrid: true, showAxisLabels: true, axisLabelStyle: 1,
            customGridColor: true, gridColor: "#ffffff",
            customBackground: true, backgroundColor: "#c6dada", backgroundOpacity: 100, graphBorder: true,
            readoutPosition: 1, showToolbar: false, showStats: false
        },
        plasma: {
            downloadColor: "#3daee9", uploadColor: "#e9783d", useBits: false,
            graphMode: 0, graphStyle: 1, fillOpacity: 30, lineWidth: 2, scaleMode: 0, logScale: false,
            showGrid: true, showTimeGrid: true, dottedTimeGrid: false, showAxisLabels: true, axisLabelStyle: 0,
            customGridColor: false, gridColor: "#ffffff",
            customBackground: false, backgroundColor: "#14161a", backgroundOpacity: 100, graphBorder: false,
            readoutPosition: 0, showToolbar: true, showStats: true
        }
    })
    readonly property string activeStyle: presets[cfg.activeStyle] ? cfg.activeStyle : "plasma"

    function savedStyles() {
        try {
            const v = JSON.parse(cfg.savedStyles || "{}");
            return v && typeof v === "object" ? v : {};
        } catch (e) {
            return {};
        }
    }
    function applyValues(values) {
        for (const key in values)
            cfg[key] = values[key];
    }
    function switchStyle(name) {
        if (name === activeStyle)
            return;
        const store = savedStyles();
        const snapshot = {};
        for (const key in presets[activeStyle])
            snapshot[key] = cfg[key];
        store[activeStyle] = snapshot;
        applyValues(Object.assign({}, presets[name], store[name] || {}));
        cfg.savedStyles = JSON.stringify(store);
        cfg.activeStyle = name;
    }
    function resetStyle() {
        const store = savedStyles();
        delete store[activeStyle];
        cfg.savedStyles = JSON.stringify(store);
        applyValues(presets[activeStyle]);
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Plasma Style")
            icon.name: "office-chart-area"
            checkable: true
            checked: root.activeStyle === "plasma"
            onTriggered: {
                root.switchStyle("plasma");
                // clicking toggles `checked`; restore the binding
                checked = Qt.binding(() => root.activeStyle === "plasma");
            }
        },
        PlasmaCore.Action {
            text: i18n("Classic Meter Style")
            icon.name: "office-chart-bar"
            checkable: true
            checked: root.activeStyle === "classic"
            onTriggered: {
                root.switchStyle("classic");
                // clicking toggles `checked`; restore the binding
                checked = Qt.binding(() => root.activeStyle === "classic");
            }
        },
        PlasmaCore.Action {
            text: i18n("Reset Style to Defaults")
            icon.name: "edit-reset"
            onTriggered: root.resetStyle()
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Reset History")
            icon.name: "edit-clear-history"
            onTriggered: root.resetHistory()
        }
    ]
}
