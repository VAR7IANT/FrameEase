import QtQuick
import FrameEase

// Keyboard key cap ("Ctrl K"), the design's `.kbd`: mono, hairline border, 4px radius.
// `bright` is the stronger variant used where the key is the content (shortcut lists, inline prose).
Rectangle {
    id: root
    property string text
    property bool bright: false
    property real minWidth: 0
    property real fontSize: Theme.sizeSmall

    implicitWidth: Math.max(minWidth, label.implicitWidth + 12)
    implicitHeight: Math.round(fontSize * 1.3) + 4
    radius: 4
    color: "transparent"
    border.width: 1
    border.color: bright ? "#4A505A" : Theme.line2
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.bright ? Theme.tx : Theme.tx3
        font.family: Theme.fontMono
        font.pixelSize: root.fontSize
        font.italic: false
    }
}
