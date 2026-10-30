import QtQuick
import QtQuick.Controls
import FrameEase

// A project-shape preset. Behaves as a radio button: the parent owns which one is `checked`.
AbstractButton {
    id: root
    property var format
    property string name: format ? format.name : ""
    property string meta: format ? format.meta : ""

    objectName: "formatCard." + (format ? format.k : "")
    checkable: false
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitHeight: 14 + 46 + 12 + info.implicitHeight + 14
    Accessible.role: Accessible.RadioButton
    Accessible.name: name + ", " + meta
    Accessible.checkable: true
    Accessible.checked: checked

    background: Rectangle {
        radius: Theme.radiusL
        color: root.checked ? Theme.p2 : (root.hovered ? Theme.p2 : Theme.p1)
        border.width: root.checked || root.visualFocus ? 2 : 1
        border.color: root.checked || root.visualFocus ? Theme.paper : (root.hovered ? "#5A606B" : Theme.line2)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: Column {
        topPadding: 14; leftPadding: 14; spacing: 12
        // aspect-ratio glyph
        Item {
            width: parent.width - 28; height: 46
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.format ? root.format.w : 40; height: root.format ? root.format.h : 22
                radius: 4; color: "transparent"; border.width: 1.6; border.color: Theme.tx
                Rectangle { anchors.fill: parent; anchors.margins: 1.6; radius: 2.5
                    gradient: Gradient { GradientStop { position: 0; color: "#26365e" } GradientStop { position: 1; color: "#d98c7a" } } }
            }
        }
        Column {
            id: info
            width: parent.width - 28; spacing: 3
            Text { width: parent.width; elide: Text.ElideRight; text: root.name; color: Theme.tx
                   font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: root.meta; color: Theme.tx3
                   font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 }
        }
    }
}
