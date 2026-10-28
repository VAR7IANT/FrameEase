import QtQuick
import QtQuick.Shapes
import FrameEase

// Lift / Gamma / Gain wheel. `offset` is the puck position in -0.5..0.5 (x right, y down),
// clamped to the circle. Drag or click to set; double-click to reset; arrow keys nudge.
Item {
    id: root
    property string label
    property point offset: Qt.point(0, 0)
    signal moved(point offset)

    // strength 0..1 and hue 0..1 derived from the puck, for tinting the preview
    readonly property real strength: Math.min(1, Math.hypot(offset.x, offset.y) * 2)
    readonly property real hue: ((Math.atan2(offset.y, offset.x) + Math.PI) / (2 * Math.PI) + 0.5) % 1

    implicitWidth: 120
    implicitHeight: 120 + 44
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: label + " colour wheel"

    function set(x, y) {
        const d = Math.hypot(x, y)
        if (d > 0.5) { x = x / d * 0.5; y = y / d * 0.5 }
        offset = Qt.point(x, y)
        moved(offset)
    }
    Keys.onLeftPressed: set(offset.x - 0.02, offset.y)
    Keys.onRightPressed: set(offset.x + 0.02, offset.y)
    Keys.onUpPressed: set(offset.x, offset.y - 0.02)
    Keys.onDownPressed: set(offset.x, offset.y + 0.02)

    Item {
        id: disc
        width: Math.min(root.width, root.height - 44); height: width
        anchors.horizontalCenter: parent.horizontalCenter

        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4
            ShapePath {
                strokeColor: root.activeFocus ? Theme.paper : "#1FFFFFFF"
                strokeWidth: root.activeFocus ? 2 : 1
                fillGradient: ConicalGradient {
                    centerX: disc.width / 2; centerY: disc.height / 2; angle: 90
                    GradientStop { position: 0.00; color: "#ff4d4d" }
                    GradientStop { position: 0.17; color: "#ffc24d" }
                    GradientStop { position: 0.33; color: "#a6ff4d" }
                    GradientStop { position: 0.50; color: "#4dffd2" }
                    GradientStop { position: 0.67; color: "#4d79ff" }
                    GradientStop { position: 0.83; color: "#c24dff" }
                    GradientStop { position: 1.00; color: "#ff4d4d" }
                }
                PathAngleArc { centerX: disc.width / 2; centerY: disc.height / 2
                               radiusX: disc.width / 2 - 1; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            // desaturate toward the centre so the middle reads as "no change"
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: disc.width / 2; centerY: disc.height / 2; centerRadius: disc.width / 2
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: "#2A2D33" }
                    GradientStop { position: 0.12; color: "#2A2D33" }
                    GradientStop { position: 0.7; color: "#332A2D33" }
                    GradientStop { position: 1.0; color: "#002A2D33" }
                }
                PathAngleArc { centerX: disc.width / 2; centerY: disc.height / 2
                               radiusX: disc.width / 2 - 1; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
        }

        Rectangle {
            x: disc.width / 2 + root.offset.x * disc.width - width / 2
            y: disc.height / 2 + root.offset.y * disc.height - height / 2
            width: 14; height: 14; radius: 7
            color: "white"; border.color: "#17140F"; border.width: 2
        }

        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { root.forceActiveFocus(); root.set(m.x / width - 0.5, m.y / height - 0.5) }
            onPositionChanged: (m) => { if (pressed) root.set(m.x / width - 0.5, m.y / height - 0.5) }
            onDoubleClicked: root.set(0, 0)
        }
    }

    Column {
        anchors.top: disc.bottom; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.label; color: Theme.tx
               font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; color: Theme.tx3
               font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall
               text: "R " + Math.round(root.offset.x * 100) + "  B " + Math.round(-root.offset.y * 100) }
    }
}
