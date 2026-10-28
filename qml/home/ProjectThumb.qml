import QtQuick
import FrameEase

// Procedural poster frame for a project (sky, sea, sun). Palette names come from MockProject.pal.
Item {
    id: root
    property string palName: "sun"
    property real sunX: 0.5          // 0..1 across the frame
    readonly property var p: MockProject.pal[palName]

    Rectangle {
        width: root.width; height: root.height * 0.57
        gradient: Gradient {
            GradientStop { position: 0;    color: root.p.top }
            GradientStop { position: 0.66; color: root.p.mid }
            GradientStop { position: 1;    color: root.p.hor }
        }
    }
    Rectangle {
        y: root.height * 0.57; width: root.width; height: root.height - y
        gradient: Gradient { GradientStop { position: 0; color: root.p.s1 } GradientStop { position: 1; color: root.p.s2 } }
    }
    Repeater {
        model: [{ d: 0.26, o: 0.10 }, { d: 0.16, o: 0.20 }, { d: 0.085, o: 1.0 }]
        Rectangle {
            required property var modelData
            width: root.width * modelData.d; height: width; radius: width / 2
            x: root.width * root.sunX - width / 2; y: root.height * 0.55 - height / 2
            color: root.p.sun; opacity: modelData.o
        }
    }
}
