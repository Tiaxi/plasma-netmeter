import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "network-wired"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Panel")
        icon: "preferences-desktop-display"
        source: "ConfigPanel.qml"
    }
    ConfigCategory {
        name: i18n("Graph")
        icon: "office-chart-area"
        source: "ConfigGraph.qml"
    }
}
