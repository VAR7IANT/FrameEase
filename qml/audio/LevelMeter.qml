import QtQuick

// Stereo bar meter. `left` / `right` are 0..1. Green to amber to red, clipped by height.
Row {
    id: root
    property real left: 0
    property real right: 0
    spacing: 3
    implicitWidth: 24
    implicitHeight: 290

    Repeater {
        model: [root.left, root.right]
        Rectangle {
            required property real modelData
            width: (root.width - root.spacing) / 2; height: root.height
            radius: 3; color: "#0B0C0E"; clip: true
            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width
                height: parent.height * Math.max(0, Math.min(1, modelData))
                gradient: Gradient {
                    // gradient spans the full meter, not just the lit part
                    GradientStop { position: 0.0; color: "#FF5B3A" }
                    GradientStop { position: 0.18; color: "#F2C14E" }
                    GradientStop { position: 0.38; color: "#7BD389" }
                    GradientStop { position: 1.0; color: "#7BD389" }
                }
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
}
