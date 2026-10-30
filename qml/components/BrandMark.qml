import QtQuick
import FrameEase

// The FrameEase mark: a frame with an ease curve that ends in the accent dot, plus the wordmark.
Row {
    id: root
    spacing: 9
    Item {
        width: 26; height: 26
        Rectangle { anchors.fill: parent; anchors.margins: 1.5; radius: 7; color: "transparent"; border.color: Theme.tx; border.width: 1.6 }
        FEIcon { anchors.centerIn: parent; size: 26; path: "M5.5 19.5C11 19.5 11 6.5 20.5 6.5"; color: Theme.tx; strokeWidth: 1.8 }
        Rectangle { x: 18; y: 4; width: 5.2; height: 5.2; radius: 2.6; color: Theme.accent }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: "Frame"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold }
        Text { text: "Ease"; color: Theme.tx; font.family: Theme.fontDisplay; font.italic: true; font.pixelSize: 17 }
    }
}
