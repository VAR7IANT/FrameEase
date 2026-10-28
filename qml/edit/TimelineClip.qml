import QtQuick
import QtQuick.Shapes
import FrameEase

// One clip on the timeline. Pure presentation + pointer intent; the Timeline owns the editing rules
// (snapping, clamping, ripple) and answers these signals by writing to the model.
Item {
    id: clip

    // Model roles (injected by the Repeater delegate)
    required property int index
    required property string cid
    required property string track
    required property real start
    required property real dur
    required property real src
    required property string name
    required property string kind
    required property string pal

    // View state from the Timeline
    property real pps: 26
    property bool selected: false
    property string tool: "select"
    property real trackTop: 0
    property real trackH: 48

    signal pressedAt(real localSeconds)
    signal moveRequested(real newStart)
    signal trimLeftRequested(real newStart)
    signal trimRightRequested(real newEnd)
    signal released()

    readonly property bool isAudio: kind === "dialogue" || kind === "music" || kind === "sfx"
    readonly property var palette: pal.length ? MockProject.pal[pal] : null

    x: start * pps
    y: trackTop + 3
    width: Math.max(4, dur * pps)
    height: trackH - 6
    z: selected ? 6 : 1

    Accessible.role: Accessible.Button
    Accessible.name: name + ", " + track + " track, " + dur.toFixed(1) + " seconds"
    Accessible.selected: selected
    activeFocusOnTab: true
    Keys.onReturnPressed: pressedAt(0)
    Keys.onSpacePressed: pressedAt(0)

    // Body
    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.radiusS
        clip: true
        color: Theme.clipColors[clip.kind]
        gradient: Gradient {
            GradientStop { position: 0; color: clip.palette ? clip.palette.top : Qt.lighter(Theme.clipColors[clip.kind], 1.12) }
            GradientStop { position: 0.55; color: clip.palette ? clip.palette.mid : Theme.clipColors[clip.kind] }
            GradientStop { position: 1; color: clip.palette ? clip.palette.hor : Qt.darker(Theme.clipColors[clip.kind], 1.15) }
        }

        // Filmstrip frame separators + bottom shade for video
        Repeater {
            model: clip.palette ? Math.floor(clip.width / (clip.height * 1.6)) : 0
            Rectangle { x: (index + 1) * clip.height * 1.6 - 1; width: 1; height: parent.height; color: "#80000000" }
        }
        Rectangle {
            visible: clip.palette !== null
            anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.6
            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: "#A0060809" } }
        }

        // Waveform for audio kinds (path built once per size change)
        Shape {
            visible: clip.isAudio
            anchors.fill: parent
            ShapePath {
                strokeColor: "#B3FFFFFF"
                strokeWidth: Math.max(1.2, clip.pps / 8 * 0.55)
                fillColor: "transparent"
                PathSvg { path: clip.isAudio ? clip.wavePath() : "" }
            }
        }

        Text {
            x: 7; y: 4
            width: parent.width - 12
            elide: Text.ElideRight
            text: clip.name + (clip.width > 150 ? "   " + clip.dur.toFixed(1) + "s" : "")
            color: clip.kind === "title" ? "#1C1710" : "white"
            font.family: Theme.fontUI
            font.pixelSize: Theme.sizeSmall + 0.5
            font.weight: Font.DemiBold
            style: clip.kind === "title" ? Text.Normal : Text.Outline
            styleColor: "#66000000"
        }
    }

    // Selection ring + keyframe diamonds
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.radiusS + 2
        color: "transparent"
        border.width: clip.selected ? 2 : (hover.hovered ? 1 : 0)
        border.color: clip.selected ? Theme.paper : "#59FFFFFF"
        visible: border.width > 0
    }
    Repeater {
        model: clip.selected ? [0.12, 0.46, 0.84] : []
        Rectangle {
            required property real modelData
            x: modelData * clip.width - 4; y: clip.height - 14
            width: 9; height: 9; rotation: 45
            color: Theme.paper; border.width: 1.5; border.color: "#17140F"
        }
    }

    HoverHandler { id: hover; cursorShape: clip.tool === "blade" ? Qt.CrossCursor : Qt.OpenHandCursor }

    // Move / blade
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8
        property real grabX: 0
        property real grabStart: 0
        onPressed: (m) => {
            clip.forceActiveFocus()
            clip.pressedAt((m.x + 8) / clip.pps)
            grabX = mapToItem(clip.parent, m.x, 0).x
            grabStart = clip.start
        }
        onPositionChanged: (m) => {
            if (!pressed || clip.tool === "blade") return
            clip.moveRequested(grabStart + (mapToItem(clip.parent, m.x, 0).x - grabX) / clip.pps)
        }
        onReleased: clip.released()
    }

    // Trim handles (visible on hover / selection)
    Repeater {
        model: ["left", "right"]
        delegate: MouseArea {
            required property string modelData
            readonly property bool isLeft: modelData === "left"
            x: isLeft ? 0 : clip.width - 8; width: 8; height: clip.height
            cursorShape: Qt.SizeHorCursor
            hoverEnabled: true
            enabled: clip.tool === "select"
            property real grabX: 0
            property real origStart: 0
            property real origEnd: 0
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusS
                color: Theme.paper
                opacity: clip.selected || parent.containsMouse ? 0.95 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                Rectangle { anchors.centerIn: parent; width: 2; height: 14; color: "#17140F" }
            }
            onPressed: (m) => { grabX = mapToItem(clip.parent, m.x, 0).x; origStart = clip.start; origEnd = clip.start + clip.dur }
            onPositionChanged: (m) => {
                if (!pressed) return
                const dt = (mapToItem(clip.parent, m.x, 0).x - grabX) / clip.pps
                if (isLeft) clip.trimLeftRequested(origStart + dt); else clip.trimRightRequested(origEnd + dt)
            }
            onReleased: clip.released()
        }
    }

    // Deterministic pseudo-waveform keyed by absolute source time, so splits stay visually continuous.
    function wavePath() {
        const n = Math.max(2, Math.floor(dur * 8)), mid = height / 2
        let d = ""
        for (let k = 0; k < n; k++) {
            const t = src + k / 8
            let a
            if (kind === "music")
                a = 0.28 + 0.5 * Math.abs(Math.sin(t * 0.9)) * (0.65 + 0.35 * Math.sin(t * 0.11)) + 0.12 * Math.abs(Math.sin(t * 7.3))
            else if (kind === "dialogue") {
                const g = Math.max(0, Math.sin(t * 1.3) * Math.sin(t * 0.41 + 1.2) + 0.28)
                a = 0.08 + 0.85 * Math.min(1, g) * Math.abs(Math.sin(t * 5.1) * 0.6 + Math.sin(t * 11.7) * 0.4)
            } else
                a = 0.12 + 0.85 * Math.abs(Math.sin(t * 3.1)) * Math.exp(-((t * 3) % 7) * 0.25)
            const h = Math.max(1, a * (mid - 3)), x = (k / 8 * pps).toFixed(1)
            d += "M" + x + " " + (mid - h).toFixed(1) + "V" + (mid + h).toFixed(1)
        }
        return d
    }
}
