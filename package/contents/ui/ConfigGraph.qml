import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls

KCM.SimpleKCM {
    id: page

    property alias cfg_historyMinutes: historySpin.value
    property int cfg_graphMode
    property int cfg_graphStyle
    property alias cfg_lineWidth: lineSpin.value
    property alias cfg_fillOpacity: fillSpin.value
    property int cfg_scaleMode
    property alias cfg_fixedScale: fixedSpin.value
    property int cfg_fixedScaleUnit
    property alias cfg_logScale: logCheck.checked
    property alias cfg_independentScales: independentCheck.checked
    property alias cfg_showGrid: gridCheck.checked
    property alias cfg_gridLines: gridSpin.value
    property alias cfg_showTimeGrid: timeGridCheck.checked
    property alias cfg_showAxisLabels: labelsCheck.checked
    property alias cfg_customBackground: bgCheck.checked
    property string cfg_backgroundColor
    property alias cfg_backgroundOpacity: bgOpacitySpin.value
    property alias cfg_showStats: statsCheck.checked
    property alias cfg_showToolbar: toolbarCheck.checked
    property int cfg_readoutPosition
    property int cfg_axisLabelStyle
    property alias cfg_dottedTimeGrid: dottedCheck.checked
    property alias cfg_customGridColor: gridColorCheck.checked
    property string cfg_gridColor
    property alias cfg_graphBorder: borderCheck.checked

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("History length:")
            QQC2.SpinBox {
                id: historySpin
                from: 1
                to: 120
            }
            QQC2.Label { text: i18n("minutes") }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Layout:")
            model: [i18n("Overlay download and upload"), i18n("Split: download above, upload below"), i18n("Mirrored: download up, upload down")]
            currentIndex: page.cfg_graphMode
            onActivated: index => page.cfg_graphMode = index
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Line"), i18n("Filled area"), i18n("Bars")]
            currentIndex: page.cfg_graphStyle
            onActivated: index => page.cfg_graphStyle = index
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Line width:")
            enabled: page.cfg_graphStyle !== 2
            QQC2.SpinBox {
                id: lineSpin
                from: 1
                to: 6
            }
            QQC2.Label { text: i18n("px") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Fill opacity:")
            enabled: page.cfg_graphStyle !== 0
            QQC2.SpinBox {
                id: fillSpin
                from: 0
                to: 100
                stepSize: 5
            }
            QQC2.Label { text: i18n("%") }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Vertical scale:")
            model: [i18n("Automatic"), i18n("Fixed maximum")]
            currentIndex: page.cfg_scaleMode
            onActivated: index => page.cfg_scaleMode = index
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Maximum:")
            enabled: page.cfg_scaleMode === 1
            QQC2.SpinBox {
                id: fixedSpin
                from: 1
                to: 100000
            }
            QQC2.ComboBox {
                model: ["kB/s", "MB/s", "Mbit/s", "Gbit/s"]
                currentIndex: page.cfg_fixedScaleUnit
                onActivated: index => page.cfg_fixedScaleUnit = index
            }
        }
        QQC2.CheckBox {
            id: logCheck
            text: i18n("Logarithmic scale")
        }
        QQC2.CheckBox {
            id: independentCheck
            enabled: page.cfg_graphMode !== 0 && page.cfg_scaleMode === 0
            text: i18n("Scale download and upload separately (split/mirrored)")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: gridCheck
            Kirigami.FormData.label: i18n("Grid:")
            text: i18n("Horizontal grid lines")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Grid lines:")
            enabled: gridCheck.checked && !logCheck.checked
            QQC2.SpinBox {
                id: gridSpin
                from: 1
                to: 10
            }
        }
        QQC2.CheckBox {
            id: timeGridCheck
            text: i18n("Vertical time lines")
        }
        QQC2.CheckBox {
            id: dottedCheck
            enabled: timeGridCheck.checked
            text: i18n("Dotted time lines")
        }
        QQC2.CheckBox {
            id: labelsCheck
            text: i18n("Axis labels")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Scale labels:")
            enabled: labelsCheck.checked
            model: [i18n("On the grid lines"), i18n("Rotated, in a strip on the left")]
            currentIndex: page.cfg_axisLabelStyle
            onActivated: index => page.cfg_axisLabelStyle = index
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Grid color:")
            QQC2.CheckBox {
                id: gridColorCheck
                text: i18n("Custom")
            }
            KQControls.ColorButton {
                enabled: gridColorCheck.checked
                color: page.cfg_gridColor
                onAccepted: c => page.cfg_gridColor = c.toString()
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: bgCheck
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Custom graph background")
        }
        KQControls.ColorButton {
            Kirigami.FormData.label: i18n("Color:")
            enabled: bgCheck.checked
            color: page.cfg_backgroundColor
            onAccepted: c => page.cfg_backgroundColor = c.toString()
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            enabled: bgCheck.checked
            QQC2.SpinBox {
                id: bgOpacitySpin
                from: 0
                to: 100
                stepSize: 5
            }
            QQC2.Label { text: i18n("%") }
        }
        QQC2.CheckBox {
            id: borderCheck
            text: i18n("Frame around the graph")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Current speed:")
            model: [i18n("Large, above the graph"), i18n("Boxed, below the graph")]
            currentIndex: page.cfg_readoutPosition
            onActivated: index => page.cfg_readoutPosition = index
        }
        QQC2.CheckBox {
            id: toolbarCheck
            Kirigami.FormData.label: i18n("Popup:")
            text: i18n("Show quick controls (history, layout, style)")
        }
        QQC2.CheckBox {
            id: statsCheck
            text: i18n("Show statistics (peak, average, totals)")
        }
    }
}
