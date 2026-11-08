import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: page

    property string cfg_interfaceName
    property alias cfg_sampleInterval: intervalSpin.value
    property bool cfg_useBits
    property alias cfg_binaryPrefixes: binaryCheck.checked
    property string cfg_downloadColor
    property string cfg_uploadColor

    property var interfaces: ["all"]

    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["ls -1 /sys/class/net"]
        onNewData: (source, data) => {
            const names = (data["stdout"] || "").split("\n").map(s => s.trim()).filter(s => s.length > 0 && s !== "lo");
            const list = ["all"].concat(names);
            if (list.indexOf(page.cfg_interfaceName) < 0)
                list.push(page.cfg_interfaceName);
            page.interfaces = list;
            disconnectSource(source);
        }
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Interface:")
            model: page.interfaces.map(n => n === "all" ? i18n("All interfaces") : n)
            currentIndex: Math.max(0, page.interfaces.indexOf(page.cfg_interfaceName))
            onActivated: index => page.cfg_interfaceName = page.interfaces[index]
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Update every:")
            QQC2.SpinBox {
                id: intervalSpin
                from: 250
                to: 5000
                stepSize: 250
            }
            QQC2.Label { text: i18n("ms") }
        }
        QQC2.Label {
            text: i18n("Changing the interface or update rate clears the history.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Show speeds in:")
            model: [i18n("Bytes (kB/s, MB/s)"), i18n("Bits (kbit/s, Mbit/s)")]
            currentIndex: page.cfg_useBits ? 1 : 0
            onActivated: index => page.cfg_useBits = index === 1
        }
        QQC2.CheckBox {
            id: binaryCheck
            text: i18n("Use binary prefixes (1 KiB = 1024 B)")
        }

        Item { Kirigami.FormData.isSection: true }

        KQControls.ColorButton {
            Kirigami.FormData.label: i18n("Download color:")
            color: page.cfg_downloadColor
            onAccepted: c => page.cfg_downloadColor = c.toString()
        }
        KQControls.ColorButton {
            Kirigami.FormData.label: i18n("Upload color:")
            color: page.cfg_uploadColor
            onAccepted: c => page.cfg_uploadColor = c.toString()
        }
    }
}
