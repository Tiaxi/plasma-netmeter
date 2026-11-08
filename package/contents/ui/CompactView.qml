import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt

MouseArea {
    id: compact

    required property var meter
    readonly property var cfg: meter.cfg

    readonly property bool vertical: meter.vertical
    readonly property bool horizontal: meter.horizontal

    readonly property int graphMode: cfg.panelGraph          // 0 none, 1 below, 2 behind
    readonly property int graphBelowHeight: graphMode === 1 ? Math.max(4, cfg.panelGraphHeight) : 0
    readonly property int pad: Math.max(1, Math.round(Kirigami.Units.smallSpacing / 2))

    // --- font sizing -------------------------------------------------------
    // Size the text so the widest value we can ever print ("8.88M") fits the
    // panel width, so the numbers never jitter or get clipped.
    readonly property real baseFontPx: Kirigami.Theme.defaultFont.pixelSize > 0
        ? Kirigami.Theme.defaultFont.pixelSize
        : Kirigami.Theme.defaultFont.pointSize * 4 / 3
    readonly property bool thinArrows: cfg.panelArrowStyle === 1
    readonly property real arrowRatio: cfg.panelShowArrows ? (thinArrows ? 0.5 : 0.62) : 0
    readonly property real gapRatio: cfg.panelShowArrows ? 0.15 : 0
    readonly property real unitGapRatio: cfg.panelShowUnit && cfg.panelUnitSpace ? 0.22 : 0
    readonly property real refWidthAt100: refMetrics.advanceWidth + 100 * (arrowRatio + gapRatio + unitGapRatio)

    readonly property int fontPx: {
        const wanted = baseFontPx * cfg.panelFontScale / 100;
        let fit;
        if (horizontal) {
            const avail = height - 2 * pad - graphBelowHeight;
            fit = avail / 2 / 1.12;
        } else {
            fit = 100 * (width - 2 * pad) / Math.max(1, refWidthAt100);
        }
        return Math.max(6, Math.floor(Math.min(wanted, fit)));
    }
    readonly property int rowHeight: Math.ceil(fontPx * 1.12)
    readonly property int contentHeight: 2 * rowHeight + graphBelowHeight + (graphMode === 1 ? pad : 0) + 2 * pad
    readonly property int contentWidth: Math.ceil(refWidthAt100 * fontPx / 100) + 2 * pad

    TextMetrics {
        id: refMetrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 100
        font.bold: compact.cfg.panelBold
        font.features: { "tnum": 1 }
        // widest possible value for the chosen precision
        text: (compact.cfg.panelDecimals < 0 ? "8.88" : "888" + (compact.cfg.panelDecimals > 0 ? "." + "8".repeat(compact.cfg.panelDecimals) : ""))
              + (compact.cfg.panelShowUnit ? "M" : "")
    }

    Layout.minimumWidth: horizontal ? contentWidth : -1
    Layout.preferredWidth: horizontal ? contentWidth : -1
    Layout.maximumWidth: horizontal ? contentWidth : -1
    Layout.minimumHeight: vertical ? contentHeight : -1
    Layout.preferredHeight: vertical ? contentHeight : -1
    Layout.maximumHeight: vertical ? contentHeight : -1

    hoverEnabled: true
    onClicked: meter.expanded = !meter.expanded

    // --- mini graph -------------------------------------------------------
    Canvas {
        id: spark
        visible: compact.graphMode !== 0
        opacity: compact.graphMode === 2 ? compact.cfg.panelGraphOpacity / 100 : 1
        x: compact.pad
        width: parent.width - 2 * compact.pad
        y: compact.graphMode === 2 ? compact.pad : compact.pad + 2 * compact.rowHeight + compact.pad
        height: compact.graphMode === 2 ? parent.height - 2 * compact.pad : compact.graphBelowHeight

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: compact.meter
            function onRevisionChanged() {
                if (spark.visible)
                    spark.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const dl = compact.meter.history.dl;
            const ul = compact.meter.history.ul;
            if (dl.length < 2 || width <= 0 || height <= 0)
                return;
            const n = Math.max(2, Math.round(compact.cfg.panelGraphSeconds * 1000 / compact.meter.interval));
            const start = Math.max(0, dl.length - n);
            let max = 2048;
            for (let i = start; i < dl.length; i++)
                max = Math.max(max, dl[i], ul[i]);
            max *= 1.05;
            const dx = width / (n - 1);
            const last = dl.length - 1;

            function series(arr, c) {
                ctx.beginPath();
                for (let i = start; i <= last; i++) {
                    const x = width - (last - i) * dx;
                    const y = height - arr[i] / max * height;
                    if (i === start)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 1);
                ctx.lineWidth = 1;
                ctx.stroke();
                ctx.lineTo(width, height);
                ctx.lineTo(width - (last - start) * dx, height);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.5);
                ctx.fill();
            }
            series(dl, compact.meter.downloadColor);
            series(ul, compact.meter.uploadColor);
        }
    }

    // --- numbers ----------------------------------------------------------
    Column {
        x: compact.pad
        y: compact.pad
        width: parent.width - 2 * compact.pad
        spacing: 0

        SpeedRow {
            up: false
            value: compact.meter.download
            accent: compact.meter.downloadColor
        }
        SpeedRow {
            up: true
            value: compact.meter.upload
            accent: compact.meter.uploadColor
        }
    }

    component SpeedRow: Item {
        id: speedRow
        property bool up
        property real value
        property color accent
        readonly property var parts: Fmt.compact(value, compact.meter.useBits, compact.meter.binary, compact.cfg.panelDecimals)
        readonly property color textColor: compact.cfg.panelColoredText ? accent : Kirigami.Theme.textColor

        width: parent.width
        height: compact.rowHeight

        Shape {
            id: arrow
            visible: compact.cfg.panelShowArrows && !compact.thinArrows
            width: Math.round(compact.fontPx * compact.arrowRatio)
            height: Math.round(width * 0.78)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            // filled triangle
            ShapePath {
                fillColor: compact.thinArrows ? "transparent" : speedRow.accent
                strokeColor: "transparent"
                startX: 0
                startY: speedRow.up ? arrow.height : 0
                PathLine { x: arrow.width; y: speedRow.up ? arrow.height : 0 }
                PathLine { x: arrow.width / 2; y: speedRow.up ? 0 : arrow.height }
                PathLine { x: 0; y: speedRow.up ? arrow.height : 0 }
            }
        }
        // thin arrow (shaft + head), like the classic text arrows
        Shape {
            id: thin
            visible: compact.cfg.panelShowArrows && compact.thinArrows
            width: Math.round(compact.fontPx * compact.arrowRatio)
            height: Math.round(compact.fontPx * 0.8)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            readonly property real lw: Math.max(1, compact.fontPx / 11)
            readonly property real tipY: speedRow.up ? lw / 2 : height - lw / 2
            readonly property real tailY: speedRow.up ? height : 0
            readonly property real headY: speedRow.up ? tipY + width * 0.45 : tipY - width * 0.45
            ShapePath {
                strokeColor: speedRow.accent
                strokeWidth: thin.lw
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: thin.width / 2; startY: thin.tailY
                PathLine { x: thin.width / 2; y: thin.tipY }
                PathMove { x: thin.lw / 2; y: thin.headY }
                PathLine { x: thin.width / 2; y: thin.tipY }
                PathLine { x: thin.width - thin.lw / 2; y: thin.headY }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(compact.fontPx * compact.unitGapRatio)
            Text {
                text: speedRow.parts.num
                color: speedRow.textColor
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: compact.fontPx
                font.bold: compact.cfg.panelBold
                font.features: { "tnum": 1 }
            }
            Text {
                visible: compact.cfg.panelShowUnit
                text: speedRow.parts.unit
                color: speedRow.textColor
                opacity: 0.7
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: compact.fontPx
                font.bold: compact.cfg.panelBold
            }
        }
    }
}
