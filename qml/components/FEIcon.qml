import QtQuick
import QtQuick.Shapes
import FrameEase

// Stroke icon drawn from a 24x24 SVG path string (same paths as the design canvas).
Item {
    id: root
    property string path
    property color color: Theme.tx2
    property real size: 16
    property real strokeWidth: 1.7

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24; height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
