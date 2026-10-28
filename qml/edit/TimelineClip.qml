import QtQuick
import QtQuick.Shapes
import FrameEase

// One clip on the timeline. Pure presentation + pointer intent; the Timeline owns the editing rules
// (snapping, clamping, ripple) and answers these signals by writing to the model.
Item {
    id: cl

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
        color: Theme.clipColors[cl.kind]
        gradient: Gradient {
            GradientStop { position: 0; color: cl.palette ? cl.palette.top : Qt.lighter(Theme.clipColors[cl.kind], 1.12) }
            GradientStop { position: 0.55; color: cl.palette ? cl.palette.mid : Theme.clipColors[cl.kind] }
            GradientStop { position: 1; color: cl.palette ? cl.palette.hor : Qt.darker(Theme.clipColors[cl.kind], 1.15) }
        }

        // Filmstrip frame separators + bottom shade for video
        Repeater {
            model: cl.palette ? Math.floor(cl.width / (cl.height * 1.6)) : 0
            Rectangle { x: (index + 1) * cl.height * 1.6 - 1; width: 1; height: parent.height; color: "#80000000" }
        }
        Rectangle {
            visible: cl.palette !== null
            anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.6
            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: "#A0060809" } }
        }

        // Waveform for audio kinds (path built once per size change)
        Shape {
            visible: cl.isAudio
            anchors.fill: parent
            ShapePath {
                strokeColor: "#B3FFFFFF"
                strokeWidth: Math.max(1.2, cl.pps / 8 * 0.55)
                fillColor: "transparent"
                PathSvg { path: cl.isAudio ? cl.wavePath() : "" }
            }
        }

        Text {
            x: 7; y: 4
            width: parent.width - 12
            elide: Text.ElideRight
            text: cl.name + (cl.width > 150 ? "   " + cl.dur.toFixed(1) + "s" : "")
            color: cl.kind === "title" ? "#1C1710" : "white"
            font.family: Theme.fontUI
            font.pixelSize: Theme.sizeSmall + 0.5
            font.weight: Font.DemiBold
            style: cl.kind === "title" ? Text.Normal : Text.Outline
            styleColor: "#66000000"
        }
    }

    // Selection ring + keyframe diamonds
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.radiusS + 2
        color: "transparent"
        border.width: cl.selected ? 2 : (hover.hovered ? 1 : 0)
        border.color: cl.selected ? Theme.paper : "#59FFFFFF"
        visible: border.width > 0
    }
    Repeater {
        model: cl.selected ? [0.12, 0.46, 0.84] : []
        Rectangle {
            required property real modelData
            x: modelData * cl.width - 4; y: cl.height - 14
            width: 9; height: 9; rotation: 45
            color: Theme.paper; border.width: 1.5; border.color: "#17140F"
        }
    }

    HoverHandler { id: hover; cursorShape: cl.tool === "blade" ? Qt.CrossCursor : Qt.OpenHandCursor }

    // Move / blade
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8
        property real grabX: 0
        property real grabStart: 0
        onPressed: (m) => {
            cl.forceActiveFocus()
            cl.pressedAt((m.x + 8) / cl.pps)
            grabX = mapToItem(cl.parent, m.x, 0).x
            grabStart = cl.start
        }
        onPositionChanged: (m) => {
            if (!pressed || cl.tool === "blade") return
            cl.moveRequested(grabStart + (mapToItem(cl.parent, m.x, 0).x - grabX) / cl.pps)
        }
        onReleased: cl.released()
    }

    // Trim handles (visible on hover / selection)
    Repeater {
        model: ["left", "right"]
        delegate: MouseArea {
            required property string modelData
            readonly property bool isLeft: modelData === "left"
            x: isLeft ? 0 : cl.width - 8; width: 8; height: cl.height
            cursorShape: Qt.SizeHorCursor
            hoverEnabled: true
            enabled: cl.tool === "select"
            property real grabX: 0
            property real origStart: 0
            property real origEnd: 0
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusS
                color: Theme.paper
                opacity: cl.selected || parent.containsMouse ? 0.95 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                Rectangle { anchors.centerIn: parent; width: 2; height: 14; color: "#17140F" }
            }
            onPressed: (m) => { grabX = mapToItem(cl.parent, m.x, 0).x; origStart = cl.start; origEnd = cl.start + cl.dur }
            onPositionChanged: (m) => {
                if (!pressed) return
                const dt = (mapToItem(cl.parent, m.x, 0).x - grabX) / cl.pps
                if (isLeft) cl.trimLeftRequested(origStart + dt); else cl.trimRightRequested(origEnd + dt)
            }
            onReleased: cl.released()
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
