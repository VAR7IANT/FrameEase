import QtQuick
import QtQuick.Layouts

// Main editing workspace. Owns the transient editing state (playhead, tool, zoom, selection)
// and connects the four panes. All edits go through MockProject until the C++ core lands.
Item {
    id: root

    property real playhead: 5.5
    property bool playing: false
    property string tool: "select"
    property real pps: 26

    // Derived from the playhead so the monitor follows the cut.
    readonly property var v1: MockProject.clipAt("V1", playhead)
    readonly property var v3: MockProject.clipAt("V3", playhead)

    Timer {
        interval: 40; repeat: true; running: root.playing
        onTriggered: {
            const t = root.playhead + 0.04
            root.playhead = t >= MockProject.total ? 0 : t
        }
    }

    // Shortcuts are workspace-scoped, so they never fire while another workspace is showing.
    Shortcut { sequence: "Space"; enabled: root.visible; onActivated: root.playing = !root.playing }
    Shortcut { sequence: "S"; enabled: root.visible; onActivated: timeline.splitSelection() }
    Shortcut { sequence: "B"; enabled: root.visible; onActivated: root.tool = "blade" }
    Shortcut { sequence: "V"; enabled: root.visible; onActivated: root.tool = "select" }
    Shortcut { sequence: "N"; enabled: root.visible; onActivated: timeline.snapping = !timeline.snapping }
    Shortcut { sequence: "="; enabled: root.visible; onActivated: timeline.zoom(1.25) }
    Shortcut { sequence: "-"; enabled: root.visible; onActivated: timeline.zoom(1 / 1.25) }
    Shortcut { sequence: "Delete"; enabled: root.visible; onActivated: timeline.deleteSelection() }
    Shortcut { sequence: "Left"; enabled: root.visible; onActivated: root.playhead = Math.max(0, root.playhead - 1 / MockProject.fps) }
    Shortcut { sequence: "Right"; enabled: root.visible; onActivated: root.playhead = Math.min(MockProject.total, root.playhead + 1 / MockProject.fps) }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

            // Side panes shrink in steps so the monitor always keeps room at 1366 px.
            Library {
                Layout.fillHeight: true
                Layout.preferredWidth: root.width < 1380 ? 272 : (root.width < 1560 ? 324 : 392)
            }
            Monitor {
                Layout.fillWidth: true; Layout.fillHeight: true
                playhead: root.playhead
                playing: root.playing
                palName: root.v1 ? root.v1.pal : "coda"
                titleText: root.v3 ? root.v3.name : ""
                onTogglePlay: root.playing = !root.playing
                onSeek: (t) => root.playhead = t
            }
            Inspector {
                Layout.fillHeight: true
                Layout.preferredWidth: root.width < 1380 ? 288 : (root.width < 1560 ? 308 : 348)
                clipName: timeline.selectedName()
                clipMeta: timeline.selectedId.length ? timeline.selectedId.toUpperCase() : ""
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line2 }

        Timeline {
            id: timeline
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(300, Math.min(440, root.height * 0.38))
            pps: root.pps
            playhead: root.playhead
            tool: root.tool
            selectedId: "t1"
            onPpsChanged: root.pps = pps
            onSeekRequested: (t) => root.playhead = t
            onToolRequested: (t) => root.tool = t
        }
    }
}
