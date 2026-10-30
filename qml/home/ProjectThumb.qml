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
    // The design paints `radial-gradient(circle at <sx>% 55%, sun 0 5%, transparent 13%)`. For a circle gradient the
    // 100% radius is the distance to the farthest corner, so the glow scales with where the sun sits.
    SunGlow {
        readonly property real reach: Math.hypot(Math.max(root.sunX, 1 - root.sunX) * root.width, 0.55 * root.height)
        x: root.width * root.sunX; y: root.height * 0.55
        color: root.p.sun
        coreRadius: reach * 0.05
        glowRadius: reach * 0.13
        steps: 12
    }
}
