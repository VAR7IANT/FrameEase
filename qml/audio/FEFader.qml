import QtQuick
import QtQuick.Controls
import FrameEase

// Vertical level fader, -60..+12 dB. Double-click resets to 0 dB.
Slider {
    id: s
    orientation: Qt.Vertical
    from: -60; to: 12; stepSize: 0.5
    implicitWidth: 24; implicitHeight: 290
    Accessible.name: "Level"

    background: Item {
        x: s.leftPadding + s.availableWidth / 2 - 3; y: s.topPadding
        width: 6; height: s.availableHeight
        Rectangle { anchors.fill: parent; radius: 3; color: "#0F1114"; border.color: Theme.line }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: (1 - s.visualPosition) * parent.height; radius: 3; color: Theme.accent; opacity: 0.85 }
        // 0 dB mark
        Rectangle { x: -6; width: parent.width + 12; height: 1; color: Theme.tx3
                    y: parent.height * (1 - (0 - s.from) / (s.to - s.from)) }
    }
    handle: Rectangle {
        x: s.leftPadding + s.availableWidth / 2 - width / 2
        y: s.topPadding + s.visualPosition * (s.availableHeight - height)
        width: 22; height: 12; radius: 3
        color: Theme.paper
        border.width: s.visualFocus ? 3 : 0; border.color: Theme.accent
        Rectangle { anchors.centerIn: parent; width: 12; height: 2; color: "#17140F" }
        scale: s.pressed ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }
    }
    TapHandler { onDoubleTapped: { s.value = 0; s.moved() } }
}
