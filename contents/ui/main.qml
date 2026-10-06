import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property bool aiOn: false
    property bool busy: false
    property int vramMB: 0
    property int vramTotalMB: 0

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property color onColor: "#2ecc71"
    readonly property color offColor: Kirigami.Theme.disabledTextColor

    // Polling: stato di ai.target + VRAM della GPU con più memoria
    readonly property string pollCmd:
        "systemctl --user is-active ai.target; " +
        "for d in /sys/class/drm/card*/device; do " +
        "[ -r $d/mem_info_vram_total ] && echo \"$(cat $d/mem_info_vram_total) $(cat $d/mem_info_vram_used)\"; " +
        "done | sort -n | tail -1"

    Plasma5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: [root.pollCmd]
        interval: 2000
        onNewData: (source, data) => {
            const lines = String(data["stdout"]).trim().split("\n")
            const active = lines[0] === "active"
            if (root.busy && active === root.aiOn) root.busy = false
            if (!root.busy) root.aiOn = active
            if (lines.length > 1) {
                const p = lines[1].split(" ")
                root.vramTotalMB = Math.round(Number(p[0]) / 1048576)
                root.vramMB = Math.round(Number(p[1]) / 1048576)
            }
        }
    }

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }

    function toggle() {
        busy = true
        aiOn = !aiOn
        runner.connectSource("systemctl --user " + (aiOn ? "start" : "stop") + " ai.target")
        busyTimeout.restart()
    }
    Timer { id: busyTimeout; interval: 15000; onTriggered: root.busy = false }

    toolTipMainText: "AI " + (aiOn ? "attiva" : "spenta")
    toolTipSubText: "VRAM: " + vramMB + " / " + vramTotalMB + " MB"

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumHeight: Kirigami.Units.gridUnit * 2
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2

        Rectangle {
            id: pill
            anchors.fill: parent
            anchors.margins: 2
            radius: height / 2
            color: root.aiOn ? Qt.rgba(root.onColor.r, root.onColor.g, root.onColor.b, 0.18)
                             : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
            border.width: 1.5
            border.color: root.aiOn ? root.onColor : Qt.rgba(root.offColor.r, root.offColor.g, root.offColor.b, 0.6)
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
            scale: mouse.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing * 2

                Rectangle {
                    id: dot
                    width: Kirigami.Units.gridUnit * 0.7
                    height: width
                    radius: width / 2
                    color: root.aiOn ? root.onColor : root.offColor
                    SequentialAnimation on opacity {
                        running: root.aiOn || root.busy
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        onRunningChanged: if (!running) dot.opacity = 1
                    }
                }
                Kirigami.Heading {
                    level: 4
                    text: "AI"
                    font.bold: true
                    color: root.aiOn ? root.onColor : Kirigami.Theme.textColor
                }
                Text {
                    text: root.vramMB + " MB"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.family: "monospace"
                    color: Kirigami.Theme.textColor
                    opacity: 0.85
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
            }
        }
    }
}
