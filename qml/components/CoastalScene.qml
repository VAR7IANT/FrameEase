import QtQuick
import FrameEase

// Procedural stand-in for a decoded video frame. Fills its own size; palette comes from MockProject.pal.
Item {
    id: root
    property string palName: "sun"
    readonly property var p: MockProject.pal[palName]
    clip: true

    Rectangle {
        width: root.width; height: root.height * 0.62
        gradient: Gradient {
            GradientStop { position: 0; color: root.p.top }
            GradientStop { position: 0.55; color: root.p.mid }
            GradientStop { position: 1; color: root.p.hor }
        }
    }
    Rectangle {
        y: root.height * 0.62; width: root.width; height: root.height * 0.38
        gradient: Gradient { GradientStop { position: 0; color: root.p.s1 } GradientStop { position: 1; color: root.p.s2 } }
    }
    // sun glow rings, then the sun
    Repeater {
        model: [0.34, 0.22, 0.12]
        Rectangle {
            required property real modelData
            width: root.width * modelData; height: width; radius: width / 2
            x: root.width * 0.65 - width / 2; y: root.height * 0.555 - height / 2
            color: root.p.sun; opacity: 0.07 + (0.34 - modelData) * 0.3
        }
    }
    Rectangle {
        width: root.width * 0.062; height: width; radius: width / 2; color: root.p.sun
        x: root.width * 0.65 - width / 2; y: root.height * 0.555 - height / 2
    }
    // reflection on the water
    Repeater {
        model: 5
        Rectangle {
            required property int index
            width: root.width * (0.06 + index * 0.045); height: Math.max(2, root.height * 0.006); radius: 2
            x: root.width * 0.65 - width / 2; y: root.height * (0.64 + index * 0.034)
            color: root.p.sun; opacity: 0.7 - index * 0.13
        }
    }
    // foreground cliff
    Rectangle {
        x: -root.width * 0.1; y: root.height * 0.8; width: root.width * 0.4; height: root.height * 0.5
        radius: width / 2; color: "#06090C"
    }
}
