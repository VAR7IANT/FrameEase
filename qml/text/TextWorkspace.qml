import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

// Text & subtitles: edit cues like a document (left), see them on the picture and on a synced
// subtitle track (centre), style them all at once (right). Cues live in a ListModel so typing
// never rebuilds the list and steals focus.
Item {
    id: root

    readonly property real t0: 14
    readonly property real t1: 56

    property real t: 21.5
    property bool playing: false
    property int sel: 1

    // style
    property string font: "sans"
    property real size: 44
    property int weight: Font.DemiBold
    property color textColor: "#FFFFFF"
    property string bg: "shadow"          // none | shadow | box
    property string pos: "bot"            // top | mid | bot
    property bool highlight: true

    readonly property var fonts: [ { k: "sans", n: "Sans", f: Theme.fontUI }, { k: "serif", n: "Serif", f: Theme.fontDisplay }, { k: "mono", n: "Mono", f: Theme.fontMono } ]
    readonly property var swatches: [ { n: "White", c: "#FFFFFF" }, { n: "Paper", c: "#F2E9D8" }, { n: "Sun", c: "#FFD84D" }, { n: "Lagoon", c: "#7FE3D8" }, { n: "Coral", c: "#FF8A6B" } ]

    ListModel {
        id: cues
        ListElement { s: 16.5; e: 19.8; text: "I've fished this harbour since I was nine." }
        ListElement { s: 20.2; e: 23.9; text: "Back then the light came up over the cliffs," }
        ListElement { s: 24.4; e: 28.0; text: "and the whole town went quiet for a minute." }
        ListElement { s: 29.0; e: 32.6; text: "You learn to read the water before you read anything else." }
        ListElement { s: 33.1; e: 36.9; text: "My father called it the morning conversation." }
        ListElement { s: 38.4; e: 42.0; text: "Some days the sea answers. Some days it doesn't." }
        ListElement { s: 43.0; e: 46.9; text: "But you go out anyway — that's the whole job." }
        ListElement { s: 48.2; e: 52.0; text: "Now I take visitors out, just to show them the light." }
    }

    function cps(i) { const c = cues.get(i); return c.text.length / Math.max(0.1, c.e - c.s) }
    function activeIndex() {
        for (let i = 0; i < cues.count; i++) { const c = cues.get(i); if (t >= c.s && t < c.e) return i }
        return -1
    }
    readonly property int active: { const _ = t; const __ = cues.count; return activeIndex() }
    property int tooFast: 0
    function recount() { let n = 0; for (let i = 0; i < cues.count; i++) if (cps(i) > 17) n++; tooFast = n }
    Component.onCompleted: recount()

    function jump(i) { sel = i; t = cues.get(i).s + 0.05; playing = false }
    function tc(x) { const m = Math.floor(x / 60), s = Math.floor(x % 60); return m + ":" + (s < 10 ? "0" : "") + s + "." + Math.floor((x % 1) * 10) }
    function timecode(x) { return MockProject.timecode(x) }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    // the cue text as rich text, with the spoken word picked out when highlighting is on
    readonly property string overlayHtml: {
        if (active < 0) return ""
        const c = cues.get(active)
        if (!highlight) return esc(c.text)
        const words = c.text.split(" ")
        const wi = Math.min(words.length - 1, Math.floor((t - c.s) / (c.e - c.s) * words.length))
        return esc(words.slice(0, wi).join(" ")) + (wi > 0 ? " " : "") + "<font color='#FF8A6B'>" + esc(words[wi]) + "</font>" + (wi < words.length - 1 ? " " + esc(words.slice(wi + 1).join(" ")) : "")
    }

    Timer {
        interval: 50; repeat: true; running: root.playing
        onTriggered: {
            let n = root.t + 0.05
            if (n > root.t1) n = root.t0 + 2
            root.t = n
            const a = root.activeIndex()
            if (a >= 0) root.sel = a
        }
    }
    Shortcut { sequence: "Space"; enabled: root.visible; onActivated: root.playing = !root.playing }

    RowLayout {
        anchors.fill: parent; spacing: 0

        // ================= Cues =================
        Rectangle {
            Layout.preferredWidth: root.width < 1560 ? 440 : 520; Layout.fillHeight: true; color: Theme.p1
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

            ColumnLayout {
                anchors.fill: parent; spacing: 0
                ColumnLayout {
                    Layout.fillWidth: true; Layout.margins: 20; Layout.bottomMargin: 12; spacing: 12
                    RowLayout {
                        Text { text: "Subtitles"; color: Theme.tx; font.family: Theme.fontDisplay; font.pixelSize: 32; Layout.fillWidth: true }
                        Text { text: cues.count + " cues"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeBody - 0.5 }
                    }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        FEButton { text: "Auto-transcribe"; primary: true }
                        FEButton { text: "Import .srt" }
                        FEButton { text: "English  ▾" }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: warn.implicitHeight + 20; radius: Theme.radiusM + 1; color: Theme.p2; border.color: Theme.line
                        Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: root.tooFast ? Theme.warn : Theme.ok }
                        Text { id: warn; x: 30; y: 10; width: parent.width - 42; wrapMode: Text.WordWrap; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                               text: root.tooFast ? root.tooFast + " cue" + (root.tooFast > 1 ? "s" : "") + " read faster than 17 characters per second. Consider splitting." : "All cues are comfortable to read." }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.leftMargin: 10; Layout.rightMargin: 10
                    clip: true; spacing: 2; model: cues
                    currentIndex: root.sel
                    ScrollBar.vertical: ScrollBar { }
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property real s
                        required property real e
                        required property string text
                        readonly property bool on: root.sel === index
                        readonly property real rate: root.cps(index) + 0 * edit.text.length
                        width: list.width - 8; height: 84; radius: Theme.radiusL - 1
                        color: on ? Theme.p2 : (rowHover.hovered ? "#181B1F" : "transparent")
                        border.width: on ? 1 : 0; border.color: Theme.line2
                        HoverHandler { id: rowHover }
                        Rectangle { visible: row.on; width: 3; height: parent.height - 20; y: 10; radius: 1.5; color: Theme.accent }

                        AbstractButton {
                            x: 16; y: 12; width: 54; height: 52
                            focusPolicy: Qt.StrongFocus
                            Accessible.role: Accessible.Button; Accessible.name: "Jump to cue " + (row.index + 1)
                            onClicked: root.jump(row.index)
                            background: Rectangle { color: "transparent"; border.width: parent.visualFocus ? 2 : 0; border.color: Theme.paper; radius: 4 }
                            contentItem: Column { spacing: 3
                                Text { text: (row.index + 1 < 10 ? "0" : "") + (row.index + 1); color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
                                Text { text: root.tc(row.s); color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 }
                                Text { text: root.tc(row.e); color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 } }
                        }
                        Row {
                            x: 80; y: 10; spacing: 8
                            Rectangle { width: sp.implicitWidth + 16; height: 20; radius: 10; color: "transparent"; border.color: Theme.line2
                                Text { id: sp; anchors.centerIn: parent; text: "Mara"; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: row.rate.toFixed(1) + " chars/s"
                                   color: row.rate > 17 ? Theme.warn : Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
                        }
                        TextArea {
                            id: edit
                            x: 80; y: 32; width: parent.width - 96; height: 46
                            padding: 2; wrapMode: TextEdit.Wrap
                            color: Theme.tx; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                            font.family: Theme.fontUI; font.pixelSize: 14
                            background: Rectangle { color: "transparent"; border.width: edit.activeFocus ? 2 : 0; border.color: Theme.paper; radius: 3 }
                            Accessible.name: "Cue " + (row.index + 1) + " text"
                            Component.onCompleted: text = row.text           // seed once; typing owns the text afterwards
                            onTextChanged: { if (text !== row.text) { cues.setProperty(row.index, "text", text); root.recount() } }
                            onActiveFocusChanged: if (activeFocus) root.jump(row.index)
                        }
                    }
                }
            }
        }

        // ================= Stage + subtitle track =================
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Item {
                    id: frame
                    width: Math.min(parent.width - 56, (parent.height - 24) * 16 / 9); height: width * 9 / 16
                    anchors.centerIn: parent
                    Rectangle { anchors.fill: parent; anchors.margins: -1; color: "black"; radius: 3 }
                    Item {
                        anchors.fill: parent; clip: true
                        CoastalScene { anchors.fill: parent; palName: "fish" }
                        // the speaker: a simple head-and-shoulders silhouette
                        Rectangle { x: frame.width * 0.355; y: frame.height * 0.55; width: frame.width * 0.22; height: frame.height * 0.6; radius: width / 2; color: "#26343B" }
                        Rectangle { x: frame.width * 0.4; y: frame.height * 0.28; width: frame.width * 0.115; height: width; radius: width / 2; color: "#C89A78" }
                        Rectangle { x: frame.width * 0.395; y: frame.height * 0.255; width: frame.width * 0.125; height: frame.height * 0.07; radius: height / 2; color: "#2A2420" }
                        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#44000000" } } }
                    }
                    Rectangle { anchors.fill: parent; anchors.margins: frame.width * 0.05; color: "transparent"; border.color: "#47FFFFFF"; border.width: 1 }

                    // subtitle overlay
                    Item {
                        visible: root.active >= 0
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: frame.width * 0.08; anchors.rightMargin: frame.width * 0.08
                        height: bubble.height
                        y: root.pos === "top" ? frame.height * 0.07 : (root.pos === "mid" ? frame.height * 0.44 : frame.height * 0.92 - height)
                        Rectangle {
                            id: bubble
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, label.implicitWidth + (root.bg === "box" ? frame.width * 0.028 : 0))
                            height: label.implicitHeight + (root.bg === "box" ? frame.width * 0.01 : 0)
                            radius: frame.width * 0.007
                            color: root.bg === "box" ? "#C70A0C0E" : "transparent"
                            Text {
                                id: label
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, frame.width * 0.84)
                                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                                textFormat: Text.RichText
                                text: root.overlayHtml
                                color: root.textColor
                                font.family: root.fonts.find(f => f.k === root.font).f
                                font.pixelSize: frame.width * root.size / 1000
                                font.weight: root.weight
                                lineHeight: 1.2
                                style: root.bg === "shadow" ? Text.Outline : Text.Normal
                                styleColor: "#D9000000"
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.bottomMargin: 12; spacing: 12
                FEIconButton { checked: true; implicitWidth: 38; implicitHeight: 38; iconPath: root.playing ? "M7 5v14M17 5v14" : "M8 5l11 7-11 7z"
                               tip: root.playing ? "Pause (Space)" : "Play (Space)"; onClicked: root.playing = !root.playing }
                Text { text: root.timecode(root.t); color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: 20; font.weight: Font.Medium }
                Item { Layout.fillWidth: true }
                Text { text: "Click a block, or anywhere on the track, to jump there"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5 }
            }

            // subtitle track
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 178; color: Theme.p1
                Rectangle { width: parent.width; height: 1; color: Theme.line2 }
                Row {
                    x: 28; y: 0; height: 30; spacing: 12
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Subtitle track"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 1; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "S1 · English"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 1 }
                }
                Item {
                    id: lane
                    x: 28; y: 34; width: parent.width - 56; height: parent.height - 44

                    function timeAt(px) { return root.t0 + Math.max(0, Math.min(1, px / width)) * (root.t1 - root.t0) }
                    function px(tt) { return (tt - root.t0) / (root.t1 - root.t0) * width }

                    // faint waveform behind the blocks, brighter where a cue is spoken
                    Shape {
                        anchors.fill: parent; opacity: 0.55
                        layer.enabled: true
                        transform: Scale { xScale: lane.width / 1000; yScale: lane.height / 100 }
                        ShapePath {
                            strokeColor: "#4D7A5D"; strokeWidth: 1.2; fillColor: "transparent"
                            PathSvg { path: {
                                let d = ""
                                for (let x = 0; x < 1000; x += 5) {
                                    const tt = root.t0 + x / 1000 * (root.t1 - root.t0)
                                    let on = false
                                    for (let i = 0; i < cues.count; i++) { const c = cues.get(i); if (tt >= c.s && tt <= c.e) { on = true; break } }
                                    const a = on ? 0.25 + 0.7 * Math.abs(Math.sin(x * 0.21) * Math.sin(x * 0.047 + 1)) : 0.04
                                    d += "M" + x + " " + (50 - a * 42).toFixed(1) + "V" + (50 + a * 42).toFixed(1)
                                }
                                return d } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: (m) => root.t = lane.timeAt(m.x)
                        onPositionChanged: (m) => { if (pressed) root.t = lane.timeAt(m.x) }
                    }
                    Repeater {
                        model: cues
                        delegate: AbstractButton {
                            id: blk
                            required property int index
                            required property real s
                            required property real e
                            required property string text
                            readonly property bool on: root.sel === index
                            x: lane.px(s); y: 10; width: Math.max(8, lane.px(e) - lane.px(s)); height: lane.height - 20
                            z: on ? 2 : 1
                            focusPolicy: Qt.StrongFocus; hoverEnabled: true
                            Accessible.role: Accessible.Button; Accessible.name: "Cue " + (index + 1)
                            onClicked: root.jump(index)
                            background: Rectangle { radius: Theme.radiusS
                                color: blk.on ? "#4A6AA8" : (blk.hovered ? "#3A4868" : "#2F3A52")
                                border.width: blk.on || blk.visualFocus ? 2 : 1
                                border.color: blk.on || blk.visualFocus ? Theme.paper : (root.cps(blk.index) > 17 ? Theme.warn : "#4A5A80") }
                            contentItem: Text { leftPadding: 7; topPadding: 4; elide: Text.ElideRight; text: blk.text; color: "#E4EBFA"
                                                font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall }
                        }
                    }
                    // playhead
                    Rectangle { x: lane.px(root.t) - 1; width: 2; height: parent.height; color: Theme.accent; z: 5 }
                }
            }
        }

        // ================= Style =================
        Rectangle {
            Layout.preferredWidth: root.width < 1560 ? 330 : 380; Layout.fillHeight: true; color: Theme.p1
            Rectangle { width: 1; height: parent.height; color: Theme.line }
            Flickable {
                anchors.fill: parent; contentWidth: width; contentHeight: sty.implicitHeight + 44; clip: true
                ScrollBar.vertical: ScrollBar { }
                Column {
                    id: sty
                    x: 22; y: 22; width: parent.width - 44; spacing: 22

                    Column { width: parent.width; spacing: 10
                        Row { width: parent.width
                            Text { width: parent.width / 2; text: "Style"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: "Applies to all cues"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 } }
                        Row { spacing: 6
                            Repeater { model: root.fonts
                                FEChip { required property var modelData; width: (sty.width - 12) / 3; implicitHeight: 34; text: modelData.n; checked: root.font === modelData.k; autoExclusive: true
                                         onClicked: root.font = modelData.k } } }
                        FESlider { width: parent.width; label: "Size"; from: 25; to: 70; value: root.size; resetValue: 44; onMoved: (v) => root.size = Math.round(v) }
                        FESlider { width: parent.width; label: "Weight"; from: 400; to: 700; value: root.weight; resetValue: 600
                                   onMoved: (v) => root.weight = Math.round(v / 100) * 100 }
                    }

                    Column { width: parent.width; spacing: 10
                        Text { text: "COLOUR"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                        Row { spacing: 12
                            Repeater { model: root.swatches
                                delegate: AbstractButton {
                                    id: sw
                                    required property var modelData
                                    width: 30; height: 30
                                    focusPolicy: Qt.StrongFocus; hoverEnabled: true
                                    Accessible.role: Accessible.RadioButton; Accessible.name: modelData.n; Accessible.checked: root.textColor === modelData.c
                                    onClicked: root.textColor = modelData.c
                                    background: Item {
                                        Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15; color: sw.modelData.c; border.color: "#33FFFFFF"; scale: sw.hovered ? 1.08 : 1
                                                    Behavior on scale { NumberAnimation { duration: Theme.durFast } } }
                                        Rectangle { anchors.centerIn: parent; width: 38; height: 38; radius: 19; color: "transparent"; border.width: 2; border.color: Theme.paper
                                                    visible: root.textColor === sw.modelData.c || sw.visualFocus } } } } }
                    }

                    Column { width: parent.width; spacing: 10
                        Text { text: "BACKGROUND"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                        Row { spacing: 6
                            Repeater { model: [ { k: "none", n: "None" }, { k: "shadow", n: "Shadow" }, { k: "box", n: "Box" } ]
                                FEChip { required property var modelData; width: (sty.width - 12) / 3; implicitHeight: 32; text: modelData.n; checked: root.bg === modelData.k; autoExclusive: true
                                         onClicked: root.bg = modelData.k } } }
                    }

                    Column { width: parent.width; spacing: 10
                        Text { text: "POSITION"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                        Row { spacing: 8
                            Repeater { model: [ { k: "top", n: "Top", a: Qt.AlignTop }, { k: "mid", n: "Middle", a: Qt.AlignVCenter }, { k: "bot", n: "Bottom", a: Qt.AlignBottom } ]
                                delegate: AbstractButton {
                                    id: pb
                                    required property var modelData
                                    width: (sty.width - 16) / 3; height: 46
                                    focusPolicy: Qt.StrongFocus; hoverEnabled: true
                                    Accessible.role: Accessible.RadioButton; Accessible.name: modelData.n; Accessible.checked: root.pos === modelData.k
                                    onClicked: root.pos = modelData.k
                                    background: Rectangle { radius: Theme.radiusM; color: "#0F1114"
                                        border.width: root.pos === pb.modelData.k || pb.visualFocus ? 2 : 1
                                        border.color: root.pos === pb.modelData.k || pb.visualFocus ? Theme.paper : (pb.hovered ? "#5A606B" : Theme.line2) }
                                    contentItem: Item {
                                        Rectangle { width: parent.width * 0.56; height: 6; radius: 3; color: Theme.tx2; anchors.horizontalCenter: parent.horizontalCenter
                                                    y: pb.modelData.k === "top" ? 4 : (pb.modelData.k === "mid" ? (parent.height - 6) / 2 : parent.height - 10) } } } } }
                    }

                    Column { width: parent.width; spacing: 10
                        Text { text: "EMPHASIS"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                        Rectangle { width: parent.width; height: 68; radius: Theme.radiusM + 2; color: Theme.p2; border.color: Theme.line
                            Column { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; spacing: 2
                                Text { width: parent.width; text: "Highlight the word being spoken"; wrapMode: Text.WordWrap; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.Medium }
                                Text { width: parent.width; text: "Uses word timings from the transcript"; wrapMode: Text.WordWrap; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 } }
                            Switch { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                     checked: root.highlight; onToggled: root.highlight = checked; Accessible.name: "Highlight the spoken word" }
                        }
                    }

                    Row { width: parent.width; spacing: 8
                        FEButton { text: "Burn into video"; width: (sty.width - 8) / 2 }
                        FEButton { text: "Export .srt"; width: (sty.width - 8) / 2 }
                    }
                }
            }
        }
    }
}
