import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FrameEase

// Contextual inspector. Simple mode shows the handful of controls most edits need;
// Pro reveals numeric entry and ease curves. Sections collapse independently.
Rectangle {
    id: root
    color: Theme.p1

    property string clipName: ""
    property string clipMeta: ""
    property bool pro: false
    property string easeName: "Soft"

    Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: Theme.line }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // header
        RowLayout {
            Layout.fillWidth: true; Layout.margins: Theme.pad; spacing: 10
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: root.clipName.length ? root.clipName : "Inspector"
                       color: root.clipName.length ? Theme.tx : Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.DemiBold }
                Text { visible: root.clipName.length > 0; text: root.clipMeta; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
            }
            FESegmented { options: ["Simple", "Pro"]; currentIndex: root.pro ? 1 : 0; onActivated: (i) => root.pro = i === 1 }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }

        // empty state
        Item {
            visible: root.clipName.length === 0
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                anchors.centerIn: parent; spacing: 6; width: parent.width - 60
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Nothing selected"; color: Theme.tx
                       font.family: Theme.fontDisplay; font.italic: true; font.pixelSize: 22 }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                       text: "Click a clip on the timeline to shape it here. Drag its edges to trim."
                       color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5 }
            }
        }

        Flickable {
            visible: root.clipName.length > 0
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: width; contentHeight: col.implicitHeight + 24
            clip: true
            ScrollBar.vertical: ScrollBar { }

            Column {
                id: col
                x: Theme.pad; y: 4; width: parent.width - Theme.pad * 2; spacing: 4

                FESection {
                    width: parent.width; title: "Transform"
                    Row {
                        visible: root.pro; width: parent.width; spacing: 8; height: root.pro ? 38 : 0
                        Repeater { model: ["X  0.0", "Y  −42.0"]
                            Rectangle { required property string modelData; width: (parent.width - 8) / 2; height: 30; radius: Theme.radiusS + 1; color: "#0F1114"; border.color: Theme.line
                                Text { anchors.centerIn: parent; text: modelData; color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 1 } } }
                    }
                    FESlider { width: parent.width; label: "Scale"; from: 25; to: 200; value: 100; resetValue: 100; unit: "%"; showKeyframe: true }
                    FESlider { width: parent.width; label: "Rotation"; from: -45; to: 45; value: 0; unit: "°"; showKeyframe: true }
                    FESlider { width: parent.width; label: "Opacity"; from: 0; to: 100; value: 100; resetValue: 100; unit: "%"; showKeyframe: true; keyframed: true }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.line }

                FESection {
                    width: parent.width; title: "Speed & ease"
                    Row {
                        spacing: 6
                        Repeater { model: ["0.5×", "1×", "2×", "4×"]
                            FEChip { required property string modelData; required property int index; text: modelData; checked: index === 1
                                     autoExclusive: true } }
                    }
                    Item { width: 1; height: 8 }
                    Flow {
                        width: parent.width; spacing: 5
                        Repeater { model: ["Linear", "Ease in", "Ease out", "Soft", "Snap"]
                            FEChip { required property string modelData; text: modelData; checked: root.easeName === modelData; autoExclusive: true
                                     onClicked: root.easeName = modelData } }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.line }

                FESection {
                    width: parent.width; title: "Quick colour"
                    FESlider { width: parent.width; label: "Warmth"; from: -50; to: 50; value: 12 }
                    FESlider { width: parent.width; label: "Exposure"; from: -50; to: 50; value: -4 }
                    FESlider { width: parent.width; label: "Saturation"; from: -50; to: 50; value: 8 }
                }
            }
        }
    }
}
