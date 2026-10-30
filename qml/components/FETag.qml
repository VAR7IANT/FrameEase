import QtQuick
import FrameEase

// Small non-interactive label pill ("Continue", "Shared", "Needs engine"). For clickable pills use FEChip.
Rectangle {
    id: root
    property string text
    // "glass": translucent, for use over imagery. "outline": hairline, for use on panels.
    property string tone: "outline"

    implicitHeight: 22
    implicitWidth: label.implicitWidth + 18
    radius: height / 2
    color: tone === "glass" ? Qt.rgba(10 / 255, 12 / 255, 14 / 255, 0.62) : "transparent"
    border.width: 1
    border.color: tone === "glass" ? Qt.rgba(1, 1, 1, 0.22) : Theme.line2
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.tone === "glass" ? "#FFFFFF" : Theme.tx2
        font.family: Theme.fontUI
        font.pixelSize: Theme.sizeSmall + 0.5
        font.weight: Font.Medium
    }
}
