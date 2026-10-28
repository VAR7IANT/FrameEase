import QtQuick
import QtQuick.Controls
import FrameEase

// Compact accent slider (4px track, 14px handle). Basic-style defaults are too heavy for toolbars.
Slider {
    id: s
    implicitHeight: 20
    background: Item {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2
        width: s.availableWidth; height: 4
        Rectangle { anchors.fill: parent; radius: 2; color: "#0F1114"; border.color: Theme.line }
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 14; height: 14; radius: 7; color: Theme.paper
        border.width: s.visualFocus ? 3 : 0; border.color: Theme.accent
    }
}
