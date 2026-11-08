import QtQuick
import org.kde.kirigami as Kirigami

import "Format.js" as Fmt

Item {
    id: graph

    required property var meter
    readonly property var cfg: meter.cfg

    readonly property int mode: cfg.graphMode     // 0 overlay, 1 split, 2 mirrored
    readonly property int style: cfg.graphStyle   // 0 line, 1 area, 2 bars
    readonly property bool logScale: cfg.logScale
    readonly property bool stripLabels: cfg.axisLabelStyle === 1 && cfg.showAxisLabels
    readonly property real fixedMax: cfg.fixedScale * [1000, 1e6, 125000, 1.25e8][cfg.fixedScaleUnit]
    readonly property color bgColor: cfg.backgroundColor
    readonly property color gridColor: cfg.customGridColor ? cfg.gridColor : Kirigami.Theme.textColor
    // Grid lines need more alpha when the user picked an explicit color.
    readonly property real gridAlpha: cfg.customGridColor ? 0.8 : 0.12
    readonly property real labelAlpha: cfg.customGridColor ? 1 : 0.55
    readonly property bool lightBackground: cfg.customBackground
        && (0.299 * bgColor.r + 0.587 * bgColor.g + 0.114 * bgColor.b) > 0.55
    readonly property color labelColor: cfg.customBackground
        ? (lightBackground ? "#202020" : "#e8e8e8")
        : Kirigami.Theme.textColor

    // Hovered sample index, or -1.
    property int hoverIndex: -1

    readonly property int labelPx: Math.max(9, Math.round(Kirigami.Theme.smallFont.pointSize * 4 / 3))
    readonly property string labelFont: labelPx + "px \"" + Kirigami.Theme.smallFont.family + "\""
    // Width of the rotated-label strip on the left (0 when not used).
    readonly property int stripWidth: stripLabels ? labelPx + 6 : 0
    readonly property int border: cfg.graphBorder ? 1 : 0

    // Plot rectangle (inside the strip and border).
    readonly property real plotX: border + stripWidth
    readonly property real plotY: border
    readonly property real plotW: Math.max(1, width - plotX - border)
    readonly property real plotH: Math.max(1, height - 2 * border)

    // Floor for the log scale: values below this sit on the baseline.
    readonly property real logFloor: 1000

    function rgba(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function niceMax(v) {
        if (logScale)
            return Math.max(logFloor * 100, Math.pow(10, Math.ceil(Math.log10(Math.max(v, 1)))));
        const lines = Math.max(1, cfg.gridLines);
        return Fmt.niceStep(Math.max(v, 1000), lines, meter.useBits, meter.binary) * lines;
    }

    function norm(v, max) {
        if (logScale) {
            if (v <= logFloor)
                return 0;
            return Math.min(1, Math.log(v / logFloor) / Math.log(max / logFloor));
        }
        return Math.min(1, v / max);
    }

    function maxOf(arr, start) {
        let m = 0;
        for (let i = start; i < arr.length; i++)
            if (arr[i] > m)
                m = arr[i];
        return m;
    }

    Rectangle {
        anchors.fill: parent
        visible: graph.cfg.customBackground
        color: graph.bgColor
        opacity: graph.cfg.backgroundOpacity / 100
        radius: graph.cfg.graphBorder ? 0 : Kirigami.Units.cornerRadius
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        Connections {
            target: graph.meter
            function onRevisionChanged() {
                canvas.requestPaint();
            }
        }
        Connections {
            target: graph.cfg
            ignoreUnknownSignals: true
            function onValueChanged() {
                canvas.requestPaint();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 4 || height <= 4)
                return;

            const m = graph.meter;
            const cfg = graph.cfg;
            const X0 = graph.plotX, Y0 = graph.plotY, W = graph.plotW, H = graph.plotH;
            const dl = m.history.dl, ul = m.history.ul;
            const cap = m.capacity;
            const start = Math.max(0, dl.length - cap);
            const last = dl.length - 1;
            const dx = W / (cap - 1);
            const xOf = i => X0 + W - (last - i) * dx;
            const gridStroke = graph.rgba(graph.gridColor, graph.gridAlpha);
            const labelFill = graph.rgba(graph.labelColor, graph.labelAlpha);

            // ---- scales ----------------------------------------------------
            let dlMax, ulMax;
            if (cfg.scaleMode === 1) {
                dlMax = ulMax = graph.fixedMax;
            } else {
                const a = graph.maxOf(dl, start) * 1.05, b = graph.maxOf(ul, start) * 1.05;
                if (graph.mode !== 0 && cfg.independentScales) {
                    dlMax = graph.niceMax(a);
                    ulMax = graph.niceMax(b);
                } else {
                    dlMax = ulMax = graph.niceMax(Math.max(a, b));
                }
            }
            if (graph.logScale) {
                dlMax = Math.max(dlMax, graph.logFloor * 10);
                ulMax = Math.max(ulMax, graph.logFloor * 10);
            }

            // ---- panes -----------------------------------------------------
            // A pane maps a value to y: base + dir * norm(v) * h
            const gap = Kirigami.Units.smallSpacing;
            let panes;
            if (graph.mode === 1) {
                const h = (H - gap) / 2;
                panes = [
                    { top: Y0, base: Y0 + h, dir: -1, h: h, max: dlMax, series: [[dl, m.downloadColor]] },
                    { top: Y0 + h + gap, base: Y0 + H, dir: -1, h: h, max: ulMax, series: [[ul, m.uploadColor]] }
                ];
            } else if (graph.mode === 2) {
                const h = H / 2;
                panes = [
                    { top: Y0, base: Y0 + h, dir: -1, h: h, max: dlMax, series: [[dl, m.downloadColor]] },
                    { top: Y0 + h, base: Y0 + h, dir: 1, h: h, max: ulMax, series: [[ul, m.uploadColor]] }
                ];
            } else {
                panes = [{ top: Y0, base: Y0 + H, dir: -1, h: H, max: dlMax, series: [[dl, m.downloadColor], [ul, m.uploadColor]] }];
            }

            ctx.font = graph.labelFont;
            ctx.textBaseline = "middle";

            // ---- left strip with rotated scale labels ----------------------
            if (graph.stripLabels) {
                ctx.fillStyle = graph.lightBackground ? Qt.rgba(0.25, 0.4, 0.6, 0.45)
                                                      : graph.rgba(Kirigami.Theme.textColor, 0.08);
                ctx.fillRect(graph.border, Y0, graph.stripWidth, H);
                ctx.fillStyle = graph.rgba(graph.labelColor, 0.9);
                for (const p of panes) {
                    const text = Fmt.axis(p.max, m.useBits, m.binary);
                    ctx.save();
                    const cx = graph.border + graph.stripWidth / 2;
                    if (p.dir < 0) {
                        // reads bottom-to-top, anchored at the top of the pane
                        ctx.translate(cx, p.base - p.h + 4);
                        ctx.rotate(-Math.PI / 2);
                        ctx.textAlign = "right";
                    } else {
                        ctx.translate(cx, p.base + p.h - 4);
                        ctx.rotate(-Math.PI / 2);
                        ctx.textAlign = "left";
                    }
                    ctx.fillText(text, 0, 0);
                    ctx.restore();
                }
                ctx.textAlign = "left";
            }

            // ---- clip to plot area ----------------------------------------
            ctx.save();
            ctx.beginPath();
            ctx.rect(X0, Y0, W, H);
            ctx.clip();

            // ---- horizontal grid -------------------------------------------
            if (cfg.showGrid) {
                ctx.lineWidth = 1;
                for (const p of panes) {
                    const levels = [];
                    if (graph.logScale) {
                        for (let v = graph.logFloor * 10; v <= p.max * 1.0001; v *= 10)
                            levels.push(v);
                    } else {
                        const lines = Math.max(1, cfg.gridLines);
                        for (let k = 1; k <= lines; k++)
                            levels.push(p.max * k / lines);
                    }
                    for (const v of levels) {
                        const y = Math.round(p.base + p.dir * graph.norm(v, p.max) * p.h) + 0.5;
                        ctx.strokeStyle = gridStroke;
                        ctx.beginPath();
                        ctx.moveTo(X0, y);
                        ctx.lineTo(X0 + W, y);
                        ctx.stroke();
                        if (cfg.showAxisLabels && !graph.stripLabels) {
                            ctx.fillStyle = labelFill;
                            // label sits just inside the area under (or above, when mirrored) the line
                            const ly = Math.min(Y0 + H - graph.labelPx / 2,
                                                Math.max(Y0 + graph.labelPx / 2, y - p.dir * graph.labelPx * 0.65));
                            ctx.fillText(Fmt.axis(v, m.useBits, m.binary), X0 + 4, ly);
                        }
                    }
                }
            }

            // ---- vertical time grid ----------------------------------------
            if (cfg.showTimeGrid) {
                const total = (cap - 1) * m.interval / 1000;   // seconds shown
                const steps = [5, 10, 15, 30, 60, 120, 300, 600, 900, 1800];
                let step = steps[steps.length - 1];
                for (const s of steps) {
                    if (total / s <= (graph.stripLabels ? 12 : 6)) {
                        step = s;
                        break;
                    }
                }
                const pxPerSec = W / total;
                ctx.lineWidth = 1;
                ctx.textBaseline = "bottom";
                if (cfg.dottedTimeGrid && ctx.setLineDash)
                    ctx.setLineDash([1, 2]);
                for (let t = step; t < total; t += step) {
                    const x = Math.round(X0 + W - t * pxPerSec) + 0.5;
                    ctx.strokeStyle = cfg.customGridColor ? gridStroke : graph.rgba(graph.gridColor, 0.08);
                    ctx.beginPath();
                    ctx.moveTo(x, Y0);
                    ctx.lineTo(x, Y0 + H);
                    ctx.stroke();
                    if (cfg.showAxisLabels && !graph.stripLabels) {
                        ctx.fillStyle = labelFill;
                        ctx.fillText(Fmt.ago(t), x + 3, Y0 + H - 1);
                    }
                }
                if (ctx.setLineDash)
                    ctx.setLineDash([]);
                ctx.textBaseline = "middle";
            }

            // ---- baselines -------------------------------------------------
            if (cfg.showGrid || graph.mode !== 0) {
                ctx.lineWidth = 1;
                ctx.strokeStyle = cfg.customGridColor ? gridStroke : graph.rgba(graph.gridColor, 0.25);
                for (const p of panes) {
                    const y = Math.round(p.base) + (p.dir < 0 ? -0.5 : 0.5);
                    ctx.beginPath();
                    ctx.moveTo(X0, y);
                    ctx.lineTo(X0 + W, y);
                    ctx.stroke();
                }
            }

            // ---- data ------------------------------------------------------
            const alpha = cfg.fillOpacity / 100;
            for (const p of panes) {
                for (const s of p.series) {
                    const arr = s[0], c = s[1];
                    const yOf = v => p.base + p.dir * graph.norm(v, p.max) * p.h;
                    if (dl.length < 1)
                        break;
                    if (graph.style === 2) {
                        // Bars: one column per sample, right edge at the sample time.
                        const bw = Math.max(1, dx > 3 ? dx - 1 : dx);
                        ctx.fillStyle = graph.rgba(c, Math.max(alpha, 0.35));
                        for (let i = start; i <= last; i++) {
                            const y = yOf(arr[i]);
                            const hh = Math.abs(y - p.base);
                            if (hh < 0.5)
                                continue;
                            ctx.fillRect(xOf(i) - bw, Math.min(y, p.base), bw, hh);
                        }
                        continue;
                    }
                    const trace = () => {
                        ctx.beginPath();
                        for (let i = start; i <= last; i++) {
                            const x = xOf(i), y = yOf(arr[i]);
                            if (i === start)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                    };
                    if (graph.style === 1 && last > start) {
                        trace();
                        ctx.lineTo(xOf(last), p.base);
                        ctx.lineTo(xOf(start), p.base);
                        ctx.closePath();
                        ctx.fillStyle = graph.rgba(c, alpha);
                        ctx.fill();
                    }
                    trace();
                    ctx.lineJoin = "round";
                    ctx.lineWidth = cfg.lineWidth;
                    ctx.strokeStyle = graph.rgba(c, 1);
                    ctx.stroke();
                }
            }

            // ---- hover crosshair --------------------------------------------
            if (graph.hoverIndex >= start && graph.hoverIndex <= last) {
                const x = Math.round(xOf(graph.hoverIndex)) + 0.5;
                ctx.strokeStyle = graph.rgba(graph.labelColor, 0.6);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(x, Y0);
                ctx.lineTo(x, Y0 + H);
                ctx.stroke();
                for (const p of panes) {
                    for (const s of p.series) {
                        const y = p.base + p.dir * graph.norm(s[0][graph.hoverIndex], p.max) * p.h;
                        ctx.fillStyle = graph.rgba(s[1], 1);
                        ctx.beginPath();
                        ctx.arc(x, y, 3, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
            }
            ctx.restore();
        }
    }

    // Inset frame.
    Rectangle {
        anchors.fill: parent
        visible: graph.cfg.graphBorder
        color: "transparent"
        border.width: 1
        border.color: graph.rgba(Kirigami.Theme.textColor, 0.35)
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        function update() {
            const m = graph.meter;
            const last = m.history.dl.length - 1;
            if (!containsMouse || last < 0 || mouseX < graph.plotX) {
                graph.hoverIndex = -1;
            } else {
                const dx = graph.plotW / (m.capacity - 1);
                const i = last - Math.round((graph.plotX + graph.plotW - mouseX) / dx);
                graph.hoverIndex = i >= Math.max(0, last - m.capacity + 1) ? i : -1;
            }
            canvas.requestPaint();
        }
        onPositionChanged: update()
        onContainsMouseChanged: update()
    }

    // Tooltip box for the hovered sample.
    Rectangle {
        id: tip
        readonly property int idx: graph.hoverIndex
        readonly property var m: graph.meter
        visible: idx >= 0 && idx < m.history.dl.length
        color: Kirigami.Theme.backgroundColor
        border.color: graph.rgba(Kirigami.Theme.textColor, 0.25)
        radius: Kirigami.Units.cornerRadius
        width: tipCol.implicitWidth + 2 * Kirigami.Units.smallSpacing
        height: tipCol.implicitHeight + 2 * Kirigami.Units.smallSpacing
        x: Math.min(graph.width - width - 2, Math.max(2, hoverArea.mouseX + 12))
        y: Math.min(graph.height - height - 2, Math.max(2, hoverArea.mouseY - height - 8))

        Column {
            id: tipCol
            anchors.centerIn: parent
            Text {
                // references revision so the text stays right while samples scroll
                text: tip.visible ? Fmt.ago((tip.m.history.dl.length - 1 - tip.idx + 0 * tip.m.revision) * tip.m.interval / 1000).replace("-0s", "now") : ""
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
            Text {
                text: tip.visible ? "↓ " + Fmt.rate(tip.m.history.dl[tip.idx] + 0 * tip.m.revision, tip.m.useBits, tip.m.binary) : ""
                color: tip.m.downloadColor
                font.features: { "tnum": 1 }
            }
            Text {
                text: tip.visible ? "↑ " + Fmt.rate(tip.m.history.ul[tip.idx] + 0 * tip.m.revision, tip.m.useBits, tip.m.binary) : ""
                color: tip.m.uploadColor
                font.features: { "tnum": 1 }
            }
        }
    }

    // Keep the hovered sample pinned under the cursor while new data arrives.
    Connections {
        target: graph.meter
        function onRevisionChanged() {
            if (hoverArea.containsMouse)
                hoverArea.update();
        }
    }
}
