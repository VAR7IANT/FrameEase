import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FrameEase

// Program monitor: 16:9 frame that always fits, plus a transport.
// The "video" is a procedural coastal scene whose palette follows the clip under the playhead.
Rectangle {
    id: root
    color: Theme.void_

    property real playhead: 0
    property bool playing: false
    property string palName: "sun"
    property string titleText: ""          // active clip on V3, "" when none
    property bool safeZones: false

    signal togglePlay()
    signal seek(real t)

    readonly property var p: MockProject.pal[palName]

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // header
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 40; Layout.leftMargin: 14; Layout.rightMargin: 14; spacing: 10
            Text { text: "PROGRAM"; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 1; font.weight: Font.DemiBold; font.letterSpacing: 0.6 }
            Text { text: "1920×1080 · 24p"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 }
            Item { Layout.fillWidth: true }
            FEIconButton { iconPath: "M3 5h18v14H3zM7 8.5h10v7H7z"; tip: "Safe zones"; checked: root.safeZones; onClicked: root.safeZones = !root.safeZones }
            FEIconButton { iconPath: "M3 17c3 0 3-10 6-10s3 12 6 12 3-7 6-7"; tip: "Scopes" }
        }

        // stage: the frame is the largest 16:9 rect that fits
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Item {
                id: frame
                readonly property real maxW: parent.width - 40
                readonly property real maxH: parent.height - 14
                width: Math.min(maxW, maxH * 16 / 9); height: width * 9 / 16
                anchors.centerIn: parent

                Rectangle { anchors.fill: parent; anchors.margins: -1; color: "black"; radius: 3 }
                Item {
                    anchors.fill: parent; clip: true
                    CoastalScene { anchors.fill: parent; palName: root.palName }

                    // title overlay (from the V3 clip under the playhead)
                    Text {
                        visible: root.titleText.length > 0
                        x: frame.width * 0.08; y: frame.height * 0.54
                        text: root.titleText.split(" · ")[0]
                        color: "#F8F1E4"
                        font.family: Theme.fontDisplay; font.italic: true
                        font.pixelSize: frame.width * 0.085
                        style: Text.Raised; styleColor: "#59000000"
                    }

                    // vignette
                    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#40000000" } } }
                    Rectangle { visible: root.safeZones; anchors.fill: parent; anchors.margins: parent.width * 0.05; color: "transparent"; border.color: "#8CFFFFFF"; border.width: 1 }
                    Rectangle { visible: root.safeZones; anchors.fill: parent; anchors.margins: parent.width * 0.10; color: "transparent"; border.color: "#59FFFFFF"; border.width: 1 }
                }
            }
        }

        // transport
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 64; Layout.leftMargin: 18; Layout.rightMargin: 18; spacing: 16
            ColumnLayout {
                Layout.preferredWidth: 210; spacing: 3
                Text { text: MockProject.timecode(root.playhead); color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: 24; font.weight: Font.Medium }
                Text { text: "of " + MockProject.timecode(MockProject.total) + " · 24 fps"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
            }
            Item { Layout.fillWidth: true }
            Row {
                spacing: 6
                FEIconButton { iconPath: "M6 5v14M19 5l-9 7 9 7z"; tip: "Go to start (Home)"; onClicked: root.seek(0) }
                FEIconButton { iconPath: "M15 6l-6 6 6 6"; tip: "Previous frame (←)"; onClicked: root.seek(Math.max(0, root.playhead - 1 / MockProject.fps)) }
                AbstractButton {
                    id: play
                    width: 42; height: 42; focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.Button; Accessible.name: root.playing ? "Pause" : "Play"
                    onClicked: root.togglePlay()
                    background: Rectangle { radius: 21; color: Theme.paper; scale: play.down ? 0.94 : 1
                        border.width: play.visualFocus ? 3 : 0; border.color: Theme.accent
                        Behavior on scale { NumberAnimation { duration: Theme.durFast } } }
                    contentItem: FEIcon {
                        anchors.centerIn: parent; size: 16; color: "#17140F"; strokeWidth: 2.4
                        path: root.playing ? "M7 5v14M17 5v14" : "M8 5l11 7-11 7z"
                    }
                }
                FEIconButton { iconPath: "M9 6l6 6-6 6"; tip: "Next frame (→)"; onClicked: root.seek(Math.min(MockProject.total, root.playhead + 1 / MockProject.fps)) }
                FEIconButton { iconPath: "M18 5v14M5 5l9 7-9 7z"; tip: "Go to end (End)"; onClicked: root.seek(MockProject.total) }
            }
            Item { Layout.fillWidth: true }
            Item { Layout.preferredWidth: 210 }
        }
    }
}
