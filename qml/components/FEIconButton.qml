import QtQuick
import QtQuick.Controls
import FrameEase

// 28px icon button. `checked` renders the paper "on" state used for tools & toggles.
AbstractButton {
    id: root
    property string iconPath
    property string tip
    property real iconSize: 16
    property bool iconFilled: false

    implicitWidth: 28
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4
    checkable: false
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: tip.length ? tip : text

    background: Rectangle {
        radius: Theme.radiusM - 1
        color: root.checked ? Theme.paper : (root.down ? Theme.p3 : (root.hovered ? Theme.p3 : "transparent"))
        border.width: root.visualFocus ? 2 : 0
        border.color: Theme.paper
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: Item {
        FEIcon {
            anchors.centerIn: parent
            path: root.iconPath
            size: root.iconSize
            filled: root.iconFilled
            color: root.checked ? "#17140F" : (root.hovered ? Theme.tx : Theme.tx2)
        }
    }

    ToolTip.visible: hovered && tip.length > 0
    ToolTip.delay: 500
    ToolTip.text: tip
}
