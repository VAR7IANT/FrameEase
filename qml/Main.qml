import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FrameEase

ApplicationWindow {
    id: win
    width: 1600; height: 900
    minimumWidth: 1180; minimumHeight: 700
    visible: true
    title: "FrameEase · Coastal Light"
    color: Theme.void_

    readonly property var workspaces: [
        { name: "Media", tip: "Browse & organise",  summary: "Search by name or by describing the shot, skim thumbnails on hover, rate and tag, and see exactly where each clip is used. Smart collections do the sorting for you." },
        { name: "Edit",  tip: "Cut & arrange",      summary: "" },
        { name: "Color", tip: "Grade",              summary: "Start with Looks and eight sliders. Open Wheels, Curves or Secondary only when you need them. A before/after wipe and live scopes stay beside the image." },
        { name: "Audio", tip: "Mix",                summary: "A sound check lists what deserves your ears, with one-click fixes. Channel strips, loudness targets, Clean Voice and music ducking sit around the waveform." },
        { name: "Text",  tip: "Titles & subtitles", summary: "Edit cues like a document, with reading-speed warnings. The subtitle track is synced to the timeline, and a single style panel applies to every cue." }
    ]
    property int current: 1   // opens on Edit

    // Ctrl+1..5 jumps between workspaces
    Repeater {
        model: win.workspaces.length
        Item { required property int index
            Shortcut { sequence: "Ctrl+" + (index + 1); onActivated: win.current = index } }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ---- top bar ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48; color: Theme.void_
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 14

                // Brand: a frame with an ease curve ending in the accent dot
                Row {
                    spacing: 9
                    Item {
                        width: 26; height: 26
                        Rectangle { anchors.fill: parent; anchors.margins: 1.5; radius: 7; color: "transparent"; border.color: Theme.tx; border.width: 1.6 }
                        FEIcon { anchors.centerIn: parent; size: 26; path: "M5.5 19.5C11 19.5 11 6.5 20.5 6.5"; color: Theme.tx; strokeWidth: 1.8 }
                        Rectangle { x: 18; y: 4; width: 5.2; height: 5.2; radius: 2.6; color: Theme.accent }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Frame"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Text { text: "Ease"; color: Theme.tx; font.family: Theme.fontDisplay; font.italic: true; font.pixelSize: 17 }
                    }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Theme.line2 }
                Text { text: "Coastal Light"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text { text: "v3 · 4K · 24p"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5; visible: win.width > 1380 }

                Item { Layout.fillWidth: true }

                // Workspace pager with the ease-curve underline
                Row {
                    spacing: 2
                    Repeater {
                        model: win.workspaces
                        delegate: AbstractButton {
                            id: tab
                            required property int index
                            required property var modelData
                            readonly property bool on: win.current === index
                            height: 32; width: lbl.implicitWidth + 26
                            focusPolicy: Qt.StrongFocus
                            hoverEnabled: true
                            Accessible.role: Accessible.PageTab; Accessible.name: modelData.name
                            ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: modelData.tip + "  (Ctrl+" + (index + 1) + ")"
                            onClicked: win.current = index
                            background: Rectangle {
                                radius: Theme.radiusM
                                color: tab.on ? "#1D2025" : (tab.hovered ? "#181B1F" : "transparent")
                                border.width: tab.visualFocus ? 2 : 0; border.color: Theme.paper
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                // underline "bridge": slides in via scale for the active tab only
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 7; width: 16; height: 5
                                            color: "transparent"; radius: 8
                                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: Theme.accent }
                                            scale: tab.on ? 1 : 0; opacity: tab.on ? 1 : 0
                                            Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } }
                                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } } }
                            }
                            contentItem: Text {
                                id: lbl
                                text: modelData.name; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                color: tab.on || tab.hovered ? Theme.tx : Theme.tx2
                                font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.Medium
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                FEIconButton { iconPath: "M9 14L4 9l5-5M4 9h10a6 6 0 010 12h-3"; tip: "Undo (Ctrl+Z)" }
                FEIconButton { iconPath: "M15 14l5-5-5-5M20 9H10a6 6 0 000 12h3"; tip: "Redo (Ctrl+Shift+Z)" }
                FEButton { text: "Export  →"; primary: true; implicitHeight: 32; implicitWidth: 104
                           onClicked: win.current = 5 }
            }
        }

        // ---- workspace stack ----
        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: win.current

            WorkspacePlaceholder { title: win.workspaces[0].name; summary: win.workspaces[0].summary }
            EditWorkspace { }
            ColorWorkspace { }
            AudioWorkspace { }
            TextWorkspace { }
            WorkspacePlaceholder { title: "Export"; summary: "Choose a destination and FrameEase picks sensible settings. Fine-tune resolution, codec, quality and audio only when you want to." }
        }

        // ---- status bar ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 26; color: "#0B0C0E"
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.line }
            Row {
                anchors.verticalCenter: parent.verticalCenter; x: 14; spacing: 16
                Row { spacing: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.ok }
                    Text { text: "Mock engine · UI prototype"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 } }
            }
        }
    }
}
