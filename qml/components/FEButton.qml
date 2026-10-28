import QtQuick
import QtQuick.Controls

// Text button. `primary: true` is the single accent-filled call to action on a screen.
AbstractButton {
    id: root
    property bool primary: false

    implicitHeight: 30
    implicitWidth: label.implicitWidth + 24
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: text

    background: Rectangle {
        radius: Theme.radiusM - 1
        color: root.primary ? Theme.accent : (root.hovered ? Theme.p3 : Theme.p2)
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? Theme.paper : (root.primary ? "transparent" : Theme.line2)
        opacity: root.down ? 0.85 : 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: Text {
        id: label
        text: root.text
        color: root.primary ? Theme.accentInk : Theme.tx
        font.family: Theme.fontUI
        font.pixelSize: Theme.sizeBody - 0.5
        font.weight: root.primary ? Font.DemiBold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
