import QtQuick

// Honest stand-in for workspaces whose QML port is not done yet.
// The full design for each lives in the HTML design canvas (see README).
Rectangle {
    id: root
    property string title
    property string summary
    color: Theme.void_

    Column {
        anchors.centerIn: parent
        spacing: 12
        width: Math.min(560, root.width - 80)
        Text {
            text: root.title
            color: Theme.tx
            font.family: Theme.fontDisplay
            font.pixelSize: 44
            font.italic: true
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.summary
            color: Theme.tx2
            font.family: Theme.fontUI
            font.pixelSize: 15
            lineHeight: 1.35
        }
        Rectangle {
            width: tag.implicitWidth + 20; height: 24; radius: 12
            color: "transparent"; border.color: Theme.line2
            Text { id: tag; anchors.centerIn: parent; text: "Design done · QML port pending"; color: Theme.tx3
                   font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 1 }
        }
    }
}
