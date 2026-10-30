import QtQuick
import QtQuick.Shapes
import FrameEase

// Rounds the corners of its children. Item.clip only clips to the bounding box, and a mask effect would need a
// shader per thumbnail, so this paints the four outside corners in the surface colour instead.
// That is exact as long as the surface behind is a flat colour (`cornerColor`, the window background by default).
Item {
    id: root
    property real radius: 10
    property color cornerColor: Theme.void_
    default property alias content: holder.data

    Item { id: holder; anchors.fill: parent; clip: true }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            fillColor: root.cornerColor
            strokeColor: "transparent"
            PathSvg {
                readonly property real w: root.width
                readonly property real h: root.height
                readonly property real r: Math.min(root.radius, w / 2, h / 2)
                path: "M 0 0 L " + r + " 0 A " + r + " " + r + " 0 0 0 0 " + r + " Z "
                    + "M " + w + " 0 L " + (w - r) + " 0 A " + r + " " + r + " 0 0 1 " + w + " " + r + " Z "
                    + "M " + w + " " + h + " L " + w + " " + (h - r) + " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + h + " Z "
                    + "M 0 " + h + " L " + r + " " + h + " A " + r + " " + r + " 0 0 1 0 " + (h - r) + " Z"
            }
        }
    }
}
