import QtQuick
import QtQuick.Controls

// Pill used for filters, presets and quick choices. `checked` = paper fill.
AbstractButton {
    id: root
    implicitHeight: 24
    implicitWidth: label.implicitWidth + 22
    checkable: true
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: text

    background: Rectangle {
        radius: height / 2
        color: root.checked ? Theme.paper : "transparent"
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus || root.checked ? Theme.paper : (root.hovered ? "#555B66" : Theme.line2)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: Text {
        id: label
        text: root.text
        color: root.checked ? "#17140F" : (root.hovered ? Theme.tx : Theme.tx2)
        font.family: Theme.fontUI
        font.pixelSize: Theme.sizeSmall + 0.5
        font.weight: root.checked ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
