import QtQuick
import QtQuick.Controls
import FrameEase

// One entry in the Recent grid.
//   click / Space  -> select      double-click / Enter / "Open" pill -> open
// Selection is paper-cream (same as focus elsewhere); it is also marked with a check badge so it
// never relies on colour alone. Keyboard focus adds a separated outer ring.
AbstractButton {
    id: root
    property var project
    property bool selected: false
    signal openRequested()

    objectName: "projectCard." + (project ? project.id : "")
    readonly property real thumbHeight: width * 0.625
    readonly property bool hot: hover.hovered || visualFocus

    implicitHeight: thumbHeight + 9 + info.implicitHeight
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.role: Accessible.ListItem
    Accessible.name: project ? (project.name + ", " + project.kind + ", " + project.dur + ", " + project.spec + ", edited " + project.edited) : ""
    Accessible.description: "Enter opens this project. Space selects it."
    Accessible.selectable: true
    Accessible.selected: selected

    onDoubleClicked: openRequested()
    Keys.onReturnPressed: openRequested()
    Keys.onEnterPressed: openRequested()
    HoverHandler { id: hover }
    TapHandler { acceptedButtons: Qt.LeftButton; onDoubleTapped: root.openRequested() }

    background: null
    contentItem: Item {
        // thumbnail, lifts on hover / focus
        Item {
            id: th
            width: root.width; height: root.thumbHeight
            y: root.hot ? -3 : 0
            Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } }

            // focus ring sits outside the selection ring
            Rectangle {
                anchors.fill: parent; anchors.margins: -6; radius: 15
                color: "transparent"; border.width: 2; border.color: Theme.paper
                visible: root.visualFocus
            }
            FERoundClip {
                anchors.fill: parent; radius: 10
                ProjectThumb { anchors.fill: parent; palName: root.project ? root.project.pal : "sun"; sunX: root.project ? root.project.sx / 100 : 0.5 }
            }
            // inset hairline (brightens on hover), or the selection ring
            Rectangle {
                anchors.fill: parent; radius: 10; color: "transparent"
                border.width: root.selected ? 2 : 1
                border.color: root.selected ? Theme.paper : Qt.rgba(1, 1, 1, root.hot ? 0.22 : 0.07)
                Behavior on border.color { ColorAnimation { duration: Theme.durMed } }
            }
            // duration
            Rectangle {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                width: durText.implicitWidth + 12; height: 20; radius: 5; color: Qt.rgba(10 / 255, 12 / 255, 14 / 255, 0.72)
                Text { id: durText; anchors.centerIn: parent; text: root.project ? root.project.dur : ""; color: "#FFFFFF"
                       font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
            }
            // selected check
            Rectangle {
                visible: root.selected
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8
                width: 22; height: 22; radius: 11; color: Theme.paper
                FEIcon { anchors.centerIn: parent; size: 13; path: "M5 12.5l4.5 4.5L19 7.5"; color: "#17140F"; strokeWidth: 2.2 }
            }
            // shared / unsaved tags
            FETag {
                visible: root.project && root.project.shared && !root.selected
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8
                text: "Shared"; tone: "glass"
            }
            FETag {
                visible: root.project && root.project.unsaved && !root.selected
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8
                text: "Not saved"; tone: "glass"
            }
            // open pill
            FEButton {
                id: openPill
                objectName: root.objectName + ".open"
                text: "Open"
                implicitHeight: 28
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                focusPolicy: Qt.NoFocus
                enabled: opacity > 0.9
                opacity: root.hot || root.selected ? 1 : 0
                visible: opacity > 0
                transform: Translate { y: root.hot || root.selected ? 0 : 4; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } } }
                Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
                onClicked: root.openRequested()
            }
        }
        // name + meta
        Column {
            id: info
            y: root.thumbHeight + 9
            width: root.width
            spacing: 4
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.project ? root.project.name : ""
                color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.project ? root.project.spec + " · " + root.project.edited : ""
                color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5
            }
        }
    }
}
