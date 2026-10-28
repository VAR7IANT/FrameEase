import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import FrameEase

// The multitrack timeline: toolbar, story map, ruler, track headers and lanes.
// Editing rules (snap, clamp, split, ripple) live here; clips only report pointer intent.
Rectangle {
    id: root
    color: Theme.p1

    // ---- public state (owned by EditWorkspace) ----
    property real pps: 26
    property real playhead: 0
    property bool snapping: true
    property bool ripple: false
    property string tool: "select"
    property string selectedId: ""

    signal seekRequested(real t)
    signal toolRequested(string tool)

    readonly property real total: MockProject.total
    readonly property int rulerH: 34
    property real snapAt: -1
    property int _n: 0

    // y offsets for each track (A1 gets a 6px group gap)
    readonly property var layout: {
        let y = rulerH, tops = {}
        for (const t of MockProject.tracks) { if (t.id === "A1") y += 6; tops[t.id] = y; y += t.h }
        return { tops: tops, height: y + 4 }
    }

    // ---------- editing rules ----------
    function snapPoints(excludeId) {
        const pts = [0, playhead]
        for (let i = 0; i < MockProject.clips.count; i++) {
            const o = MockProject.clips.get(i)
            if (o.cid !== excludeId) pts.push(o.start, o.start + o.dur)
        }
        return pts
    }

    // free space around clip i on its track: [lo, hi]
    function bounds(i) {
        const c = MockProject.clips.get(i)
        let lo = 0, hi = Infinity
        for (let k = 0; k < MockProject.clips.count; k++) {
            if (k === i) continue
            const o = MockProject.clips.get(k)
            if (o.track !== c.track) continue
            if (o.start + o.dur <= c.start + 0.001) lo = Math.max(lo, o.start + o.dur)
            else if (o.start >= c.start + c.dur - 0.001) hi = Math.min(hi, o.start)
        }
        return { lo: lo, hi: hi }
    }

    // snap `value` (a time) to the nearest point inside a 9px tolerance; returns the snapped time or the input.
    function snapTime(value, excludeId) {
        snapAt = -1
        if (!snapping) return value
        const tol = 9 / pps
        let best = tol, out = value
        for (const p of snapPoints(excludeId)) {
            const d = Math.abs(p - value)
            if (d < best) { best = d; out = p; snapAt = p }
        }
        return out
    }

    function moveClip(i, desired) {
        const c = MockProject.clips.get(i), b = bounds(i)
        // snap whichever edge is closer to a snap point
        const a = snapTime(desired, c.cid), aAt = snapAt
        const e = snapTime(desired + c.dur, c.cid) - c.dur, eAt = snapAt
        let s = desired
        if (aAt >= 0 && (eAt < 0 || Math.abs(a - desired) <= Math.abs(e - desired))) { s = a; snapAt = aAt }
        else if (eAt >= 0) { s = e; snapAt = eAt }
        else snapAt = -1
        s = Math.max(b.lo, Math.min(b.hi - c.dur, s))
        MockProject.clips.setProperty(i, "start", s)
    }

    function trimLeft(i, desired) {
        const c = MockProject.clips.get(i), b = bounds(i), end = c.start + c.dur
        let s = snapTime(desired, c.cid)
        s = Math.max(b.lo, c.start - c.src, Math.min(end - 0.5, s))
        MockProject.clips.setProperty(i, "src", c.src + (s - c.start))
        MockProject.clips.setProperty(i, "start", s)
        MockProject.clips.setProperty(i, "dur", end - s)
    }

    function trimRight(i, desired) {
        const c = MockProject.clips.get(i), b = bounds(i)
        let e = snapTime(desired, c.cid)
        e = Math.min(b.hi, Math.max(c.start + 0.5, e))
        MockProject.clips.setProperty(i, "dur", e - c.start)
    }

    function splitAt(i, at) {
        const c = MockProject.clips.get(i)
        if (at <= c.start + 0.2 || at >= c.start + c.dur - 0.2) return
        const right = { cid: c.cid.replace(/_\d+$/, "") + "_" + (++_n), track: c.track, start: at, dur: c.start + c.dur - at,
                        src: c.src + (at - c.start), name: c.name, kind: c.kind, pal: c.pal }
        MockProject.clips.setProperty(i, "dur", at - c.start)
        MockProject.clips.insert(i + 1, right)
        selectedId = right.cid
    }

    // Split the selection, or every clip under the playhead when nothing is selected.
    function splitSelection() {
        const hits = []
        for (let i = 0; i < MockProject.clips.count; i++) {
            const c = MockProject.clips.get(i)
            if (selectedId.length ? c.cid === selectedId : (playhead > c.start && playhead < c.start + c.dur)) hits.push(i)
        }
        for (let k = hits.length - 1; k >= 0; k--) splitAt(hits[k], playhead)
    }

    function deleteSelection() {
        for (let i = 0; i < MockProject.clips.count; i++) {
            const c = MockProject.clips.get(i)
            if (c.cid !== selectedId) continue
            const track = c.track, end = c.start + c.dur, len = c.dur
            MockProject.clips.remove(i)
            if (ripple)
                for (let k = 0; k < MockProject.clips.count; k++) {
                    const o = MockProject.clips.get(k)
                    if (o.track === track && o.start >= end - 0.001) MockProject.clips.setProperty(k, "start", o.start - len)
                }
            selectedId = ""
            return
        }
    }

    function fit() { pps = Math.max(6, Math.floor((scroller.width - 40) / total)) }
    function zoom(f) { pps = Math.max(6, Math.min(120, Math.round(pps * f))) }

    // ---------- layout ----------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // toolbar
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 42
            color: "transparent"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 4
                FEIconButton { iconPath: "M6 4l12 7-5.2 1.6L11 18z"; tip: "Select (V)"; checked: root.tool === "select"; onClicked: root.toolRequested("select") }
                FEIconButton { iconPath: "M6 7m-2.5 0a 2.5 2.5 0 1 0 5 0 2.5 2.5 0 1 0 -5 0M6 17m-2.5 0a 2.5 2.5 0 1 0 5 0 2.5 2.5 0 1 0 -5 0M8 8.5L20 18M8 15.5L20 6"; tip: "Blade (B): click a clip to cut"; checked: root.tool === "blade"; onClicked: root.toolRequested("blade") }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 18; Layout.leftMargin: 6; Layout.rightMargin: 6; color: Theme.line2 }
                FEIconButton { iconPath: "M6 4v8a 6 6 0 0 0 12 0V4h-4v8a 2 2 0 0 1 -4 0V4zM6 8h4M14 8h4"; tip: "Snapping (N)"; checked: root.snapping; onClicked: root.snapping = !root.snapping }
                FEIconButton { iconPath: "M4 7h9M4 17h9M16 5l4 2-4 2M16 15l4 2-4 2"; tip: "Ripple edit: close gaps on delete"; checked: root.ripple; onClicked: root.ripple = !root.ripple }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 30
                    // Contextual strip: appears only when something is selected
                    Rectangle {
                        id: ctx
                        anchors.centerIn: parent
                        visible: root.selectedId.length > 0
                        height: 30; radius: 15
                        width: ctxRow.implicitWidth + 20
                        color: "#0F1114"; border.color: Theme.line2
                        Row {
                            id: ctxRow; anchors.centerIn: parent; spacing: 6
                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.selectedName(); color: Theme.tx
                                   font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.Medium; elide: Text.ElideRight; width: Math.min(implicitWidth, 190) }
                            FEChip { text: "Split  S"; checkable: false; onClicked: root.splitSelection() }
                            FEChip { text: "Delete"; checkable: false; onClicked: root.deleteSelection() }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: !ctx.visible; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 1
                           text: "Select a clip, or press S to cut everything under the playhead" }
                }

                FEIconButton { iconPath: "M5 12h14"; tip: "Zoom out"; onClicked: root.zoom(1 / 1.25) }
                FEPlainSlider { id: zoomSlider; Layout.preferredWidth: 110; from: 6; to: 120; value: root.pps; onMoved: root.pps = value; Accessible.name: "Timeline zoom" }
                FEIconButton { iconPath: "M12 5v14M5 12h14"; tip: "Zoom in"; onClicked: root.zoom(1.25) }
                FEButton { text: "Fit"; implicitHeight: 26; onClicked: root.fit() }
            }
        }

        // story map: the whole film at a glance, click to jump
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 28
            color: "transparent"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Story map"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 }
            Item {
                x: 208; y: 4; width: parent.width - 218; height: 20
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: [ { n: "Arrival", w: 31, p: "sun" }, { n: "Harbour", w: 30, p: "harb" }, { n: "The Cliffs", w: 27, p: "cliff" },
                                 { n: "Dusk", w: 32, p: "dusk" }, { n: "Coda", w: 24, p: "coda" } ]
                        Rectangle {
                            required property var modelData
                            width: parent.width * modelData.w / 144; height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: MockProject.pal[modelData.p].top }
                                GradientStop { position: 1; color: MockProject.pal[modelData.p].mid }
                            }
                            Text { x: 7; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; text: parent.modelData.n; color: "white"; style: Text.Outline; styleColor: "#99000000"
                                   font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.weight: Font.Medium }
                            Rectangle { anchors.right: parent.right; width: 2; height: parent.height; color: Theme.void_ }
                        }
                    }
                }
                Rectangle { x: root.playhead / root.total * parent.width - 1; width: 2; height: parent.height; color: Theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onPressed: (m) => root.seekRequested(Math.max(0, Math.min(root.total, m.x / width * root.total)))
                    onPositionChanged: (m) => { if (pressed) root.seekRequested(Math.max(0, Math.min(root.total, m.x / width * root.total))) } }
            }
        }

        // headers + scrolling lanes
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

            Rectangle {
                Layout.preferredWidth: 208; Layout.fillHeight: true; color: "#111316"
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }
                Text { x: 10; y: 12; text: "TRACKS"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                Repeater {
                    model: MockProject.tracks
                    Rectangle {
                        required property var modelData
                        y: root.layout.tops[modelData.id]; width: parent.width - 1; height: modelData.h
                        color: "#121417"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 6
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 24; height: 18; radius: 4; color: modelData.color
                                Text { anchors.centerIn: parent; text: modelData.id; color: Theme.void_; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall; font.weight: Font.DemiBold } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: Theme.tx; width: 80; elide: Text.ElideRight
                                   font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5 }
                            FEIconButton { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; iconSize: 13; tip: "Lock " + modelData.name
                                           iconPath: "M7 11h10v9H7zM9 11V8a 3 3 0 0 1 6 0v3" }
                            FEIconButton { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; iconSize: 13; tip: (modelData.video ? "Hide " : "Mute ") + modelData.name
                                           iconPath: modelData.video ? "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 9a 3 3 0 1 0 0 6 3 3 0 0 0 0 -6z" : "M5 9v6h3l5 4V5L8 9zM16.5 9a 4 4 0 0 1 0 6" }
                        }
                    }
                }
            }

            Flickable {
                id: scroller
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: root.total * root.pps + 160
                contentHeight: root.layout.height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOn; height: 10 }

                Item {
                    id: content
                    width: scroller.contentWidth; height: scroller.contentHeight

                    // lanes
                    Repeater {
                        model: MockProject.tracks
                        Rectangle {
                            required property var modelData
                            required property int index
                            y: root.layout.tops[modelData.id]; width: content.width; height: modelData.h
                            color: index % 2 ? "#13151A" : "#16181D"
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                        }
                    }

                    // ruler (click or drag to scrub). Beats show nothing but time, so labels stay quiet.
                    Rectangle {
                        id: ruler
                        width: content.width; height: root.rulerH; color: "#111316"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                        readonly property real step: [1, 2, 5, 10, 15, 30, 60].find(v => v * root.pps >= 72) || 60
                        Repeater {
                            model: Math.floor(root.total / (ruler.step / 5)) + 1
                            Item {
                                required property int index
                                readonly property bool major: index % 5 === 0
                                x: index * (ruler.step / 5) * root.pps
                                anchors.bottom: parent.bottom
                                height: major ? 18 : 6
                                Rectangle { width: 1; height: parent.height; color: "#3D424A" }
                                Text {
                                    visible: parent.major
                                    x: 4; y: 0
                                    readonly property int s: Math.round(index * (ruler.step / 5))
                                    text: Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
                                    color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall
                                }
                            }
                        }
                    }
                    MouseArea {   // scrub surface: ruler + empty lane area
                        width: content.width; height: content.height
                        z: 0
                        onPressed: (m) => { root.selectedId = ""; root.seekRequested(Math.max(0, Math.min(root.total, m.x / root.pps))) }
                        onPositionChanged: (m) => { if (pressed) root.seekRequested(Math.max(0, Math.min(root.total, m.x / root.pps))) }
                    }

                    // clips
                    Repeater {
                        id: clipRepeater
                        model: MockProject.clips
                        delegate: TimelineClip {
                            pps: root.pps
                            tool: root.tool
                            selected: cid === root.selectedId
                            trackTop: root.layout.tops[track]
                            trackH: MockProject.trackById(track).h
                            onPressedAt: (local) => {
                                root.selectedId = cid
                                if (root.tool === "blade") root.splitAt(index, start + local)
                            }
                            onMoveRequested: (s) => root.moveClip(index, s)
                            onTrimLeftRequested: (s) => root.trimLeft(index, s)
                            onTrimRightRequested: (e) => root.trimRight(index, e)
                            onReleased: root.snapAt = -1
                        }
                    }

                    // snap guide
                    Rectangle { visible: root.snapAt >= 0; x: root.snapAt * root.pps; y: root.rulerH; width: 1; height: content.height - root.rulerH
                                color: Theme.paper; z: 20 }

                    // playhead: the only accent-coloured line on screen
                    Item {
                        x: root.playhead * root.pps; z: 30; height: content.height
                        Rectangle { x: -1; y: 8; width: 2; height: parent.height - 8; color: Theme.accent }
                        Shape {
                            x: -7; width: 14; height: 18
                            ShapePath { fillColor: Theme.accent; strokeColor: "transparent"
                                PathSvg { path: "M1 0h12a 1 1 0 0 1 1 1v7l-7 9-7-9V1a 1 1 0 0 1 1 -1z" } }
                        }
                    }
                }
            }
        }
    }

    function selectedName() {
        for (let i = 0; i < MockProject.clips.count; i++) { const c = MockProject.clips.get(i); if (c.cid === selectedId) return c.name }
        return ""
    }
}
