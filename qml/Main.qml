pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FrameEase

ApplicationWindow {
    id: win
    width: 1600; height: 900
    minimumWidth: 1180; minimumHeight: 700
    visible: true
    title: atHome || !project ? "FrameEase" : "FrameEase · " + project.name
    color: Theme.void_

    // Home is the launch screen, not a workspace: while `atHome` it owns the whole window.
    property bool atHome: true
    property string projectId: ""
    readonly property var project: MockLibrary.byId(projectId)

    // Opens a (mock) project in the given workspace index. Every project shows the same demo timeline for now.
    function enterProject(id, workspace) {
        MockLibrary.touch(id)
        projectId = id
        current = workspace
        atHome = false
    }
    readonly property bool anyPlaying: editWorkspace.playing || audioWorkspace.playing || textWorkspace.playing

    // Leaving a project stops playback: the editor shell stays alive behind Home, and each workspace's playback
    // timer is bound only to its own `playing` flag, so without this it would keep advancing, unseen, under Home.
    function goHome() {
        editWorkspace.playing = false
        audioWorkspace.playing = false
        textWorkspace.playing = false
        atHome = true
    }

    readonly property var workspaces: [
        { name: "Media", tip: "Browse & organise",  summary: "Search by name or by describing the shot, skim thumbnails on hover, rate and tag, and see exactly where each clip is used. Smart collections do the sorting for you." },
        { name: "Edit",  tip: "Cut & arrange",      summary: "" },
        { name: "Color", tip: "Grade",              summary: "Start with Looks and eight sliders. Open Wheels, Curves or Secondary only when you need them. A before/after wipe and live scopes stay beside the image." },
        { name: "Audio", tip: "Mix",                summary: "A sound check lists what deserves your ears, with one-click fixes. Channel strips, loudness targets, Clean Voice and music ducking sit around the waveform." },
        { name: "Text",  tip: "Titles & subtitles", summary: "Edit cues like a document, with reading-speed warnings. The subtitle track is synced to the timeline, and a single style panel applies to every cue." }
    ]
    property int current: 1   // opens on Edit

    // Ctrl+1..5 jumps between workspaces; Ctrl+0 goes back to Home. Only active inside a project.
    Repeater {
        model: win.workspaces.length
        Item { required property int index
            Shortcut { sequence: "Ctrl+" + (index + 1); enabled: !win.atHome; onActivated: win.current = index } }
    }
    Shortcut { sequence: "Ctrl+0"; enabled: !win.atHome; onActivated: win.goHome() }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: win.atHome ? 0 : 1

            HomeScreen {
                id: home
                onOpenProject: (id, workspace) => win.enterProject(id, workspace)
                onCreateProject: (formatKey, workspace) => win.enterProject(MockLibrary.create(formatKey), workspace)
            }

            // ---- editor shell: top bar + workspaces ----
            ColumnLayout {
                spacing: 0

        // ---- top bar ----
        Rectangle {
            objectName: "editorTopBar"
            Layout.fillWidth: true; Layout.preferredHeight: 48; color: Theme.void_
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 14

                // Brand doubles as the "back to Home" button
                AbstractButton {
                    id: homeBrand
                    objectName: "brandHome"
                    leftPadding: 8; rightPadding: 8; topPadding: 4; bottomPadding: 4
                    focusPolicy: Qt.StrongFocus; hoverEnabled: true
                    Accessible.role: Accessible.Button; Accessible.name: "FrameEase, back to Home"
                    ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: "Back to Home  (Ctrl+0)"
                    onClicked: win.goHome()
                    background: Rectangle {
                        radius: Theme.radiusM
                        color: homeBrand.hovered ? "#181B1F" : "transparent"
                        border.width: homeBrand.visualFocus ? 2 : 0; border.color: Theme.paper
                    }
                    contentItem: BrandMark { }
                }
                FEButton {
                    objectName: "homeButton"
                    text: "←  Projects"; implicitHeight: 28
                    Accessible.name: "Back to Home"
                    onClicked: win.goHome()
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Theme.line2 }
                Text { text: win.project ? win.project.name : ""; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 13; font.weight: Font.DemiBold
                       Layout.maximumWidth: 220; elide: Text.ElideRight }
                FETag { visible: !!win.project && win.project.unsaved; text: "Not saved" }
                Text { text: win.project ? win.project.version + " · " + win.project.spec : ""; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5; visible: win.width > 1380 }

                Item { Layout.fillWidth: true }

                // Workspace pager with the ease-curve underline
                Row {
                    spacing: 2
                    Repeater {
                        model: win.workspaces
                        delegate: AbstractButton {
                            id: tab
                            objectName: "tab." + modelData.name
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

                // Edits are not tracked yet (no command stack), so these are shown as unavailable instead of doing nothing.
                FEUnavailableIconButton { objectName: "undoButton"; iconPath: "M9 14L4 9l5-5M4 9h10a 6 6 0 0 1 0 12h-3"; tip: "Undo"
                                          reason: "edits aren’t tracked until the editing engine lands." }
                FEUnavailableIconButton { objectName: "redoButton"; iconPath: "M15 14l5-5-5-5M20 9H10a 6 6 0 0 0 0 12h3"; tip: "Redo"
                                          reason: "edits aren’t tracked until the editing engine lands." }
                FEButton { objectName: "exportButton"; text: "Export  →"; primary: true; implicitHeight: 32; implicitWidth: 104
                           onClicked: win.current = 5 }
            }
        }

        // ---- workspace stack ----
        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: win.current

            WorkspacePlaceholder { title: win.workspaces[0].name; summary: win.workspaces[0].summary }
            EditWorkspace { id: editWorkspace; objectName: "workspace.edit" }
            ColorWorkspace { }
            AudioWorkspace { id: audioWorkspace; objectName: "workspace.audio" }
            TextWorkspace { id: textWorkspace; objectName: "workspace.text" }
            WorkspacePlaceholder { title: "Export"; summary: "Choose a destination and FrameEase picks sensible settings. Fine-tune resolution, codec, quality and audio only when you want to." }
        }

            }   // editor shell
        }       // home / editor pages

        // ---- status bar ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 26; color: "#0B0C0E"
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.line }
            Row {
                anchors.verticalCenter: parent.verticalCenter; x: 14; spacing: 16
                Row { spacing: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.ok }
                    Text { text: "Mock engine · UI prototype · sample projects, nothing is saved, every project opens the same demo timeline"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 } }
            }
        }
    }
}
