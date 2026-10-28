import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FrameEase

// Media bin: search, filters, thumbnail grid. Mock data only; the grid binds to MockProject.media.
Rectangle {
    id: root
    color: Theme.p1
    property string selectedName: "Sunrise_Drone_04"
    property string filter: "All"

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.pad; spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Media"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { text: "48"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 }
            Item { Layout.fillWidth: true }
            FEButton { text: "+ Import"; implicitHeight: 26 }
        }

        // search
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 32
            radius: Theme.radiusM; color: "#0F1114"; border.color: search.activeFocus ? Theme.paper : Theme.line; border.width: search.activeFocus ? 2 : 1
            Row {
                anchors.fill: parent; anchors.leftMargin: 10; spacing: 8
                FEIcon { anchors.verticalCenter: parent.verticalCenter; path: "M11 11m-6 0a 6 6 0 1 0 12 0 6 6 0 1 0 -12 0M20 20l-4.5-4.5"; color: Theme.tx3 }
                TextField {
                    id: search
                    width: parent.width - 40; height: parent.height
                    placeholderText: "Search clips, tags, faces…"
                    placeholderTextColor: Theme.tx3
                    color: Theme.tx; background: null
                    font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                    Accessible.name: "Search media"
                }
            }
        }

        Flow {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: ["All", "Video", "Audio", "Image", "Unused"]
                FEChip { required property string modelData; text: modelData; checked: root.filter === modelData
                         onClicked: root.filter = modelData }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            readonly property int cols: Math.max(2, Math.floor(width / 112))
            cellWidth: Math.floor(width / cols); cellHeight: cellWidth * 0.625 + 30
            model: MockProject.media.filter(m => root.filter !== "Unused" || !m.used)
            ScrollBar.vertical: ScrollBar { }

            delegate: AbstractButton {
                id: item
                required property var modelData
                width: grid.cellWidth - 8; height: grid.cellHeight - 8
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.Button
                Accessible.name: modelData.n + ", " + modelData.d
                onClicked: root.selectedName = modelData.n
                background: null
                contentItem: Column {
                    spacing: 5
                    Rectangle {
                        id: thumb
                        width: item.width; height: item.width * 0.625; radius: Theme.radiusS; clip: true
                        readonly property var p: MockProject.pal[item.modelData.pal]
                        gradient: Gradient {
                            GradientStop { position: 0.0;  color: thumb.p.top }
                            GradientStop { position: 0.38; color: thumb.p.mid }
                            GradientStop { position: 0.56; color: thumb.p.hor }
                            GradientStop { position: 0.57; color: thumb.p.s1 }
                            GradientStop { position: 1.0;  color: thumb.p.s2 }
                        }
                        Rectangle { x: item.modelData.sx * parent.width - width / 2; y: parent.height * 0.55 - height / 2
                                    width: parent.width * 0.1; height: width; radius: width / 2; color: thumb.p.sun }
                        Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"
                                    border.width: root.selectedName === item.modelData.n ? 2 : (item.hovered ? 1 : 0)
                                    border.color: root.selectedName === item.modelData.n ? Theme.paper : "#47FFFFFF" }
                        Rectangle { visible: item.modelData.used; x: 5; y: 5; width: 8; height: 8; radius: 4; color: Theme.paper }
                        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 4
                                    width: dur.implicitWidth + 10; height: 16; radius: 4; color: "#BF0A0C0E"
                                    Text { id: dur; anchors.centerIn: parent; text: item.modelData.d; color: "white"; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall } }
                        // lift on hover
                        transform: Translate { y: item.hovered ? -2 : 0; Behavior on y { NumberAnimation { duration: Theme.durFast } } }
                    }
                    Text { width: item.width; elide: Text.ElideRight; text: item.modelData.n; color: Theme.tx
                           font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 }
                }
            }
        }
    }
}
