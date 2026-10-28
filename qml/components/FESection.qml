import QtQuick
import QtQuick.Controls

// Collapsible inspector section: the progressive-disclosure primitive.
// Usage: FESection { title: "Transform"; FESlider { ... } }
Item {
    id: root
    property string title
    property bool expanded: true
    default property alias content: body.data

    implicitWidth: 300
    implicitHeight: header.height + (expanded ? body.implicitHeight + 8 : 0)
    clip: true

    Behavior on implicitHeight { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } }

    AbstractButton {
        id: header
        width: parent.width
        height: 34
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.Button
        Accessible.name: root.title
        onClicked: root.expanded = !root.expanded
        background: Rectangle { color: "transparent"; border.width: header.visualFocus ? 2 : 0; border.color: Theme.paper; radius: 4 }
        contentItem: Row {
            spacing: 8
            FEIcon {
                anchors.verticalCenter: parent.verticalCenter
                path: "M6 9l6 6 6-6"
                color: Theme.tx3
                rotation: root.expanded ? 0 : -90
                Behavior on rotation { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: Theme.tx
                font.family: Theme.fontUI
                font.pixelSize: Theme.sizeBody
                font.weight: Font.DemiBold
            }
        }
    }

    Column {
        id: body
        y: header.height
        width: parent.width
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
}
