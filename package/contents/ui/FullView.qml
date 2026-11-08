import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt

ColumnLayout {
    id: full

    required property var meter
    readonly property var cfg: meter.cfg
    readonly property bool readoutsBelow: cfg.readoutPosition === 1
    readonly property bool headerVisible: !readoutsBelow || cfg.showToolbar

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 9
    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.preferredHeight: Kirigami.Units.gridUnit * ((cfg.showStats ? 4 : 0) + (headerVisible ? 2 : 0) + (readoutsBelow ? 1.5 : 0) + 12)
    spacing: Kirigami.Units.smallSpacing

    // ---- statistics over the visible window ------------------------------
    property var stats: ({ dlPeak: 0, ulPeak: 0, dlAvg: 0, ulAvg: 0 })
    function computeStats() {
        const dl = meter.history.dl, ul = meter.history.ul;
        let dp = 0, up = 0, ds = 0, us = 0;
        for (let i = 0; i < dl.length; i++) {
            dp = Math.max(dp, dl[i]);
            up = Math.max(up, ul[i]);
            ds += dl[i];
            us += ul[i];
        }
        const n = Math.max(1, dl.length);
        stats = { dlPeak: dp, ulPeak: up, dlAvg: ds / n, ulAvg: us / n };
    }
    Connections {
        target: full.meter
        function onRevisionChanged() {
            if (full.cfg.showStats)
                full.computeStats();
        }
    }
    Component.onCompleted: computeStats()

    function rate(v) {
        return Fmt.rate(v, meter.useBits, meter.binary);
    }

    // ---- header ---------------------------------------------------------
    RowLayout {
        visible: full.headerVisible
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        BigReadout {
            visible: !full.readoutsBelow
            label: "↓"
            value: full.rate(full.meter.download)
            accent: full.meter.downloadColor
        }
        BigReadout {
            visible: !full.readoutsBelow
            label: "↑"
            value: full.rate(full.meter.upload)
            accent: full.meter.uploadColor
        }
        Item { Layout.fillWidth: true }

        PlasmaComponents.ComboBox {
            visible: full.cfg.showToolbar
            readonly property var minutes: [1, 2, 5, 10, 15, 30, 60]
            model: minutes.map(m => i18np("%1 min", "%1 min", m))
            currentIndex: Math.max(0, minutes.indexOf(full.cfg.historyMinutes))
            onActivated: index => full.cfg.historyMinutes = minutes[index]
            PlasmaComponents.ToolTip.text: i18n("History length")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ComboBox {
            visible: full.cfg.showToolbar
            model: [i18n("Overlay"), i18n("Split"), i18n("Mirrored")]
            currentIndex: full.cfg.graphMode
            onActivated: index => full.cfg.graphMode = index
            PlasmaComponents.ToolTip.text: i18n("Graph layout")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ComboBox {
            visible: full.cfg.showToolbar
            model: [i18n("Line"), i18n("Area"), i18n("Bars")]
            currentIndex: full.cfg.graphStyle
            onActivated: index => full.cfg.graphStyle = index
            PlasmaComponents.ToolTip.text: i18n("Graph style")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ToolButton {
            visible: full.cfg.showToolbar
            icon.name: "configure"
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Configure…")
            onClicked: full.meter.configure()
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    // ---- graph ----------------------------------------------------------
    Graph {
        id: graphItem
        Layout.fillWidth: true
        Layout.fillHeight: true
        meter: full.meter
    }

    // ---- classic readout boxes under the graph ---------------------------
    RowLayout {
        visible: full.readoutsBelow
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        ReadoutBox {
            value: full.rate(full.meter.download)
            accent: full.meter.downloadColor
        }
        ReadoutBox {
            value: full.rate(full.meter.upload)
            accent: full.meter.uploadColor
        }
    }

    // ---- stats ----------------------------------------------------------
    GridLayout {
        visible: full.cfg.showStats
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        columns: 5
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: 0

        StatLabel { text: "" }
        StatLabel { text: i18n("Peak"); dim: true }
        StatLabel { text: i18n("Average"); dim: true }
        StatLabel { text: i18n("Today"); dim: true }
        StatLabel { text: i18n("This month"); dim: true }

        StatLabel { text: i18n("Download"); color: full.meter.downloadColor }
        StatLabel { text: full.rate(full.stats.dlPeak) }
        StatLabel { text: full.rate(full.stats.dlAvg) }
        StatLabel { text: Fmt.size(full.meter.usageToday[0], full.meter.binary) }
        StatLabel { text: Fmt.size(full.meter.usageMonth[0], full.meter.binary) }

        StatLabel { text: i18n("Upload"); color: full.meter.uploadColor }
        StatLabel { text: full.rate(full.stats.ulPeak) }
        StatLabel { text: full.rate(full.stats.ulAvg) }
        StatLabel { text: Fmt.size(full.meter.usageToday[1], full.meter.binary) }
        StatLabel { text: Fmt.size(full.meter.usageMonth[1], full.meter.binary) }
    }

    component BigReadout: RowLayout {
        id: big
        property string label
        property string value
        property color accent
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents.Label {
            text: big.label
            color: big.accent
            font.pixelSize: Kirigami.Theme.defaultFont.pointSize * 4 / 3 * 1.5
            font.bold: true
        }
        PlasmaComponents.Label {
            id: bigValue
            text: big.value
            font.pixelSize: Kirigami.Theme.defaultFont.pointSize * 4 / 3 * 1.3
            font.features: { "tnum": 1 }
            Layout.minimumWidth: bigMetrics.advanceWidth
            TextMetrics {
                id: bigMetrics
                font: bigValue.font
                text: "888 MiB/s"
            }
        }
    }

    // Boxed value under the graph, tinted like the graph background.
    component ReadoutBox: Rectangle {
        id: box
        property string value
        property color accent
        readonly property bool useGraphBg: full.cfg.customBackground
        Layout.fillWidth: true
        implicitHeight: boxLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
        color: useGraphBg ? graphItem.bgColor : Qt.rgba(accent.r, accent.g, accent.b, 0.12)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.6)
        PlasmaComponents.Label {
            id: boxLabel
            anchors.centerIn: parent
            text: box.value
            font.features: { "tnum": 1 }
            // On a light custom background, darken the series color so it stays readable.
            color: box.useGraphBg && graphItem.lightBackground ? Qt.darker(box.accent, 1.8)
                 : box.useGraphBg ? Qt.lighter(box.accent, 1.3)
                 : Kirigami.Theme.textColor
        }
    }

    component StatLabel: PlasmaComponents.Label {
        property bool dim: false
        Layout.fillWidth: true
        font: Kirigami.Theme.smallFont
        opacity: dim ? 0.6 : 1
        elide: Text.ElideRight
    }
}
