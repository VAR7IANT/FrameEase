import QtQuick
import QtQuick.Controls
import FrameEase

// Labelled slider row: label | track | value. Keyboard: arrows, PageUp/PageDown; double-click resets.
Item {
    id: root
    property alias label: lbl.text
    property alias from: s.from
    property alias to: s.to
    property alias value: s.value
    property real resetValue: 0
    property string unit: ""
    property int decimals: 0
    property bool keyframed: false
    property bool showKeyframe: false
    signal moved(real v)

    implicitHeight: 32
    implicitWidth: 300

    Row {
        anchors.fill: parent
        spacing: 8

        Text {
            id: lbl
            width: 68
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: Theme.tx2
            font.family: Theme.fontUI
            font.pixelSize: Theme.sizeBody - 0.5
        }

        Slider {
            id: s
            width: parent.width - lbl.width - val.width - (root.showKeyframe ? 30 : 0) - 16
            height: parent.height
            Accessible.name: root.label
            onMoved: root.moved(value)

            background: Item {
                x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2
                width: s.availableWidth; height: 4
                Rectangle { anchors.fill: parent; radius: 2; color: "#0F1114"; border.color: Theme.line; border.width: 1 }
                Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
            }
            handle: Rectangle {
                x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
                y: s.topPadding + s.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: Theme.paper
                border.width: s.visualFocus ? 3 : 0
                border.color: Theme.accent
                scale: s.pressed ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.durFast } }
            }
            TapHandler { acceptedButtons: Qt.LeftButton; gesturePolicy: TapHandler.ReleaseWithinBounds
                onDoubleTapped: { s.value = root.resetValue; root.moved(s.value) } }
        }

        Text {
            id: val
            width: 46
            height: parent.height
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: s.value.toFixed(root.decimals) + root.unit
            color: Theme.tx
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeSmall + 1
        }

        FEIconButton {
            visible: root.showKeyframe
            width: 22; height: 22
            anchors.verticalCenter: parent.verticalCenter
            iconPath: "M12 4l7 8-7 8-7-8z"
            iconSize: 13
            tip: "Keyframe " + root.label
            checked: root.keyframed
            onClicked: root.keyframed = !root.keyframed
        }
    }
}
