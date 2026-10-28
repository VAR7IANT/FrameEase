import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FrameEase

// One mixer channel: name, pan, meter + fader, mute / solo, insert list.
Rectangle {
    id: root
    property string name
    property string chanId
    property color swatch: Theme.tx
    property real db: 0
    property real pan: 0
    property bool muted: false
    property bool soloed: false
    property real meterL: 0
    property real meterR: 0
    property var inserts: []
    property bool master: false

    signal dbMoved(real v)
    signal panMoved(real v)
    signal muteToggled()
    signal soloToggled()

    implicitWidth: master ? 176 : 156
    radius: 14
    color: master ? "#17191D" : Theme.p1
    border.color: master ? Theme.line2 : Theme.line
    Accessible.role: Accessible.Grouping
    Accessible.name: name + " channel"

    function signed(n) { return (n > 0 ? "+" : n < 0 ? "−" : "") + Math.abs(Math.round(n * 10) / 10) }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; anchors.topMargin: 14; spacing: 12

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle { width: 8; height: 8; radius: 2; color: root.swatch }
            Text { text: root.name; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Text { visible: !root.master; text: root.chanId; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
        }

        ColumnLayout {
            visible: !root.master
            Layout.fillWidth: true; spacing: 2
            RowLayout { Layout.fillWidth: true
                Text { text: "Pan"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall }
                Item { Layout.fillWidth: true }
                Text { text: root.pan === 0 ? "C" : (root.pan < 0 ? "L" + (-root.pan) : "R" + root.pan); color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall } }
            Slider {
                Layout.fillWidth: true; from: -100; to: 100; value: root.pan; stepSize: 1
                Accessible.name: root.name + " pan"
                onMoved: root.panMoved(value)
                TapHandler { onDoubleTapped: root.panMoved(0) }
                background: Rectangle { x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - 2; width: parent.availableWidth; height: 4; radius: 2; color: "#0F1114"
                    border.color: Theme.line
                    Rectangle { x: parent.width / 2; width: 1; height: parent.height; color: Theme.tx3 } }
                handle: Rectangle { x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width); y: parent.topPadding + parent.availableHeight / 2 - height / 2
                    width: 12; height: 12; radius: 6; color: Theme.paper }
            }
        }
        // room for the loudness card the workspace overlays on the master strip
        Item { visible: root.master; Layout.preferredHeight: 104 }

        // meter + fader + scale
        Row {
            Layout.alignment: Qt.AlignHCenter; spacing: 10
            LevelMeter { width: 24; height: 290; left: root.meterL; right: root.meterR }
            FEFader { height: 290; value: root.db; onMoved: root.dbMoved(value); Accessible.name: root.name + " level" }
            Column {
                height: 290
                Repeater {
                    model: ["+12", "0", "−12", "−24", "−60"]
                    Text { required property string modelData; height: 290 / 5; verticalAlignment: Text.AlignTop
                           text: modelData; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.signed(root.db) + " dB"
            color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: 15; font.weight: Font.Medium
        }

        RowLayout {
            visible: !root.master
            Layout.alignment: Qt.AlignHCenter; spacing: 6
            Repeater {
                model: [ { t: "M", k: "mute" }, { t: "S", k: "solo" } ]
                delegate: AbstractButton {
                    id: b
                    required property var modelData
                    readonly property bool on: modelData.k === "mute" ? root.muted : root.soloed
                    implicitWidth: 34; implicitHeight: 28
                    focusPolicy: Qt.StrongFocus; hoverEnabled: true
                    Accessible.role: Accessible.CheckBox; Accessible.checked: on
                    Accessible.name: (modelData.k === "mute" ? "Mute " : "Solo ") + root.name
                    onClicked: modelData.k === "mute" ? root.muteToggled() : root.soloToggled()
                    background: Rectangle { radius: Theme.radiusM - 1
                        color: b.on ? (b.modelData.k === "mute" ? Theme.warn : "#6FD3C9") : "transparent"
                        border.width: b.visualFocus ? 2 : 1
                        border.color: b.visualFocus ? Theme.paper : (b.on ? "transparent" : (b.hovered ? "#5A606B" : Theme.line2)) }
                    contentItem: Text { text: b.modelData.t; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        color: b.on ? "#10130F" : Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: root.inserts
                Rectangle { required property string modelData
                    Layout.fillWidth: true; implicitHeight: 26; radius: 6; color: Theme.p3
                    Text { x: 9; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 } }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
