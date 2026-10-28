import QtQuick
import QtQuick.Controls
import FrameEase

// Featured "Continue editing" card: the most recently opened project, full width.
// The whole card is one button; the pill inside is a label, not a second control.
AbstractButton {
    id: root
    property var project
    readonly property var pal: MockProject.pal[project ? project.pal : "sun"]

    objectName: "heroContinue"
    implicitHeight: 300
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: project ? "Continue editing " + project.name : "Continue editing"
    Accessible.description: project ? project.resume : ""

    background: null
    contentItem: Item {
        FERoundClip {
            id: clipHost
            anchors.fill: parent
            radius: 16

            // The scene is authored on a 1600x300 canvas and scaled to cover the card (like SVG "slice").
            Item {
                id: scene
                readonly property real s: Math.max(root.width / 1600, root.height / 300)
                width: 1600; height: 300
                scale: s
                transformOrigin: Item.TopLeft
                x: (root.width - 1600 * s) / 2
                y: (root.height - 300 * s) / 2

                Rectangle { width: 1600; height: 190
                    gradient: Gradient {
                        GradientStop { position: 0;   color: root.pal.top }
                        GradientStop { position: 0.6; color: root.pal.mid }
                        GradientStop { position: 1;   color: root.pal.hor }
                    } }
                Repeater {
                    model: [{ r: 200, o: 0.10 }, { r: 130, o: 0.16 }, { r: 80, o: 0.24 }]
                    Rectangle {
                        required property var modelData
                        width: modelData.r * 2; height: width; radius: modelData.r
                        x: 1180 - modelData.r; y: 172 - modelData.r
                        color: root.pal.sun; opacity: modelData.o
                    }
                }
                Rectangle { x: 1180 - 34; y: 172 - 34; width: 68; height: 68; radius: 34; color: root.pal.sun }
                Rectangle { y: 190; width: 1600; height: 110
                    gradient: Gradient { GradientStop { position: 0; color: root.pal.s1 } GradientStop { position: 1; color: root.pal.s2 } } }
                Repeater {
                    model: [{ x: 1140, y: 200, w: 80, h: 4, o: 0.7 }, { x: 1110, y: 216, w: 140, h: 4, o: 0.45 },
                            { x: 1070, y: 234, w: 220, h: 5, o: 0.3 }, { x: 1020, y: 256, w: 320, h: 6, o: 0.18 }]
                    Rectangle {
                        required property var modelData
                        x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
                        color: root.pal.sun; opacity: modelData.o
                    }
                }
                // foreground headland (a plain rounded rectangle: a Shape here would ignore the page's scroll clip in some renderers)
                Rectangle { x: -150; y: 222; width: 640; height: 260; radius: 130; color: "#06090C" }
            }
            // legibility scrim: dark on the text side
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0;    color: Qt.rgba(8 / 255, 10 / 255, 12 / 255, 0.82) }
                    GradientStop { position: 0.62; color: Qt.rgba(8 / 255, 10 / 255, 12 / 255, 0.2) }
                    GradientStop { position: 1;    color: Qt.rgba(8 / 255, 10 / 255, 12 / 255, 0) }
                }
            }
            // clip strip: relative lengths of the project's clips
            Row {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.leftMargin: 36; anchors.rightMargin: 36; anchors.bottomMargin: 16
                height: 8; spacing: 2; opacity: 0.9
                Repeater {
                    model: root.project ? root.project.segments : []
                    Rectangle {
                        required property real modelData
                        readonly property real total: root.project.segments.reduce((a, b) => a + b, 0)
                        width: (parent.width - (root.project.segments.length - 1) * 2) * modelData / total
                        height: 8; radius: 2; color: Theme.clipColors.main
                    }
                }
            }
        }
        // hover / focus edge
        Rectangle {
            anchors.fill: parent; radius: 16; color: "transparent"
            border.width: root.visualFocus ? 2 : 1
            border.color: root.visualFocus ? Theme.paper : Qt.rgba(1, 1, 1, root.hovered ? 0.22 : 0.08)
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }
        }
        Column {
            x: 36; y: 32
            width: Math.min(520, parent.width - 72)
            spacing: 0
            FETag { text: "Continue"; tone: "glass" }
            Text {
                topPadding: 14; width: parent.width; elide: Text.ElideRight
                text: root.project ? root.project.name : ""
                color: "#FFFFFF"; font.family: Theme.fontDisplay; font.pixelSize: 46
            }
            Text {
                topPadding: 8; width: parent.width; elide: Text.ElideRight
                text: root.project ? root.project.version + " · " + root.project.dur + " · " + root.project.spec.replace(" · ", " ") + " · edited " + root.project.edited : ""
                color: "#D8D4CC"; font.family: Theme.fontMono; font.pixelSize: 12
            }
        }
        Row {
            x: 36; anchors.bottom: parent.bottom; anchors.bottomMargin: 44
            spacing: 14
            Rectangle {
                height: 38; width: ctaText.implicitWidth + 38; radius: Theme.radiusM
                color: Theme.accent
                opacity: root.down ? 0.85 : 1
                Text { id: ctaText; anchors.centerIn: parent; text: "Continue editing  →"; color: Theme.accentInk
                       font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.DemiBold }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.project ? root.project.resume : ""
                color: "#D8D4CC"; font.family: Theme.fontMono; font.pixelSize: 12
            }
        }
    }
}
