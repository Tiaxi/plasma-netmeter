import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_panelShowArrows: arrowsCheck.checked
    property alias cfg_panelColoredText: coloredCheck.checked
    property alias cfg_panelShowUnit: unitCheck.checked
    property int cfg_panelDecimals
    property alias cfg_panelUnitSpace: unitSpaceCheck.checked
    property int cfg_panelArrowStyle
    property alias cfg_panelBold: boldCheck.checked
    property alias cfg_panelFontScale: scaleSpin.value
    property int cfg_panelGraph
    property alias cfg_panelGraphSeconds: secondsSpin.value
    property alias cfg_panelGraphHeight: heightSpin.value
    property alias cfg_panelGraphOpacity: opacitySpin.value
    property alias cfg_tooltipShowTitle: ttTitle.checked
    property alias cfg_tooltipShowSpeed: ttSpeed.checked
    property alias cfg_tooltipShowPeakAverage: ttPeak.checked
    property alias cfg_tooltipShowToday: ttToday.checked
    property alias cfg_tooltipShowMonth: ttMonth.checked

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Arrows:")
            QQC2.CheckBox {
                id: arrowsCheck
                text: i18n("Show")
            }
            QQC2.ComboBox {
                enabled: arrowsCheck.checked
                model: [i18n("Triangles ▼▲"), i18n("Thin arrows ↓↑")]
                currentIndex: page.cfg_panelArrowStyle
                onActivated: index => page.cfg_panelArrowStyle = index
            }
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Number format:")
            readonly property var values: [-1, 0, 1, 2]
            model: [i18n("Automatic (4.83, 48.3, 483)"), i18n("No decimals (483)"), i18n("One decimal (483.2)"), i18n("Two decimals (483.21)")]
            currentIndex: Math.max(0, values.indexOf(page.cfg_panelDecimals))
            onActivated: index => page.cfg_panelDecimals = values[index]
        }
        QQC2.CheckBox {
            id: unitCheck
            Kirigami.FormData.label: i18n("Unit:")
            text: i18n("Show unit letter (K, M, G)")
        }
        QQC2.CheckBox {
            id: unitSpaceCheck
            enabled: unitCheck.checked
            text: i18n("Space between number and unit")
        }
        QQC2.CheckBox {
            id: coloredCheck
            Kirigami.FormData.label: i18n("Text:")
            text: i18n("Color the numbers")
        }
        QQC2.CheckBox {
            id: boldCheck
            text: i18n("Bold")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Maximum text size:")
            QQC2.SpinBox {
                id: scaleSpin
                from: 50
                to: 300
                stepSize: 10
            }
            QQC2.Label { text: i18n("% of the system font") }
        }
        QQC2.Label {
            text: i18n("On a vertical panel the text also shrinks to fit the panel width.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: graphCombo
            Kirigami.FormData.label: i18n("Mini graph:")
            model: [i18n("None"), i18n("Below the numbers"), i18n("Behind the numbers")]
            currentIndex: page.cfg_panelGraph
            onActivated: index => page.cfg_panelGraph = index
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Time span:")
            enabled: page.cfg_panelGraph !== 0
            QQC2.SpinBox {
                id: secondsSpin
                from: 10
                to: 600
                stepSize: 10
            }
            QQC2.Label { text: i18n("seconds") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Height:")
            enabled: page.cfg_panelGraph === 1
            QQC2.SpinBox {
                id: heightSpin
                from: 4
                to: 100
            }
            QQC2.Label { text: i18n("px") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Opacity behind numbers:")
            enabled: page.cfg_panelGraph === 2
            QQC2.SpinBox {
                id: opacitySpin
                from: 5
                to: 100
                stepSize: 5
            }
            QQC2.Label { text: i18n("%") }
        }
    
        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: ttTitle
            Kirigami.FormData.label: i18n("Tooltip shows:")
            text: i18n("Title (interface name)")
        }
        QQC2.CheckBox {
            id: ttSpeed
            text: i18n("Current speed")
        }
        QQC2.CheckBox {
            id: ttPeak
            text: i18n("Peak and average (over the graph's history)")
        }
        QQC2.CheckBox {
            id: ttToday
            text: i18n("Today's total")
        }
        QQC2.CheckBox {
            id: ttMonth
            text: i18n("This month's total")
        }
        QQC2.Label {
            text: i18n("With nothing selected, no tooltip is shown.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
