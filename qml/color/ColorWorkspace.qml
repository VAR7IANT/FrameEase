import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import FrameEase

// Color workspace. Progressive disclosure: Basic (looks + sliders) -> Wheels -> Curves -> Secondary.
// The grade is one plain object (`grade`) so a future C++ ColorNode can replace it 1:1.
Item {
    id: root

    // ---- grade state (mock) ----
    property var grade: ({ ex: -3, co: 12, hi: -8, sh: 10, wm: 10, ti: -6, sa: 8, vi: 12 })
    property string look: "teal"
    property var wheels: ({ lift: Qt.point(0, 0), gamma: Qt.point(0, 0), gain: Qt.point(0.12, -0.08) })
    property string curve: "contrast"
    property int shot: 0
    property int node: 0
    property bool wipe: true
    property real wipePos: 0.5            // 0..1 of frame width
    property int tab: 0

    readonly property var shots: [
        { n: "Sunrise Drone 04", p: "sun" }, { n: "Harbour Walk", p: "harb" }, { n: "Fishermen Cu", p: "fish" },
        { n: "Cliffs Wide", p: "cliff" }, { n: "Dusk Timelapse", p: "dusk" }, { n: "Night Harbour", p: "coda" }
    ]
    readonly property var looks: [
        { k: "none",   n: "None",         c0: "#8a8a8a", c1: "#3a3a3a", v: { ex: 0,  co: 0,  hi: 0,   sh: 0,   wm: 0,  ti: 0,  sa: 0,   vi: 0 } },
        { k: "teal",   n: "Teal Harbour", c0: "#1c4f5c", c1: "#e3a46b", v: { ex: -3, co: 12, hi: -8,  sh: 10,  wm: 10, ti: -6, sa: 8,   vi: 12 } },
        { k: "film",   n: "Warm film",    c0: "#5b3a22", c1: "#f0c58a", v: { ex: 2,  co: 8,  hi: -12, sh: 14,  wm: 24, ti: 4,  sa: -4,  vi: 6 } },
        { k: "bleach", n: "Bleach",       c0: "#4a5560", c1: "#cfd3d6", v: { ex: 0,  co: 22, hi: 6,   sh: -8,  wm: -6, ti: 0,  sa: -28, vi: 0 } },
        { k: "noir",   n: "Noir",         c0: "#0c0c0c", c1: "#bdbdbd", v: { ex: -6, co: 30, hi: -4,  sh: -10, wm: 0,  ti: 0,  sa: -50, vi: 0 } }
    ]
    readonly property var lightSliders: [ { k: "ex", n: "Exposure" }, { k: "co", n: "Contrast" }, { k: "hi", n: "Highlights" }, { k: "sh", n: "Shadows" } ]
    readonly property var colorSliders: [ { k: "wm", n: "Temperature" }, { k: "ti", n: "Tint" }, { k: "sa", n: "Saturation" }, { k: "vi", n: "Vibrance" } ]
    readonly property var curves: [
        { k: "linear",   n: "Linear",       d: "M0 240L240 0",                                          px: 120, py: 120 },
        { k: "contrast", n: "Contrast",     d: "M0 240C70 240 90 175 120 120S170 0 240 0",              px: 120, py: 120 },
        { k: "fade",     n: "Fade",         d: "M0 205C70 190 90 150 120 120S190 30 240 15",            px: 120, py: 120 },
        { k: "lift",     n: "Lift shadows", d: "M0 240C40 190 80 150 120 120S190 40 240 0",             px: 60,  py: 170 }
    ]

    function setGrade(k, v) { const g = Object.assign({}, grade); g[k] = v; grade = g; look = "custom" }
    function applyLook(l) { grade = Object.assign({}, l.v); look = l.k }
    function resetAll() {
        grade = { ex: 0, co: 0, hi: 0, sh: 0, wm: 0, ti: 0, sa: 0, vi: 0 }; look = "none"
        wheels = { lift: Qt.point(0, 0), gamma: Qt.point(0, 0), gain: Qt.point(0, 0) }
    }
    function setWheel(k, p) { const w = Object.assign({}, wheels); w[k] = p; wheels = w }
    function signed(n) { return (n > 0 ? "+" : n < 0 ? "−" : "") + Math.abs(n) }

    // strongest wheel pushes the preview tint
    readonly property var wheelKeys: ["lift", "gamma", "gain"]
    readonly property var wheelPush: {
        let best = { s: 0, h: 0 }, sum = 0
        for (const k of wheelKeys) {
            const p = wheels[k], s = Math.min(1, Math.hypot(p.x, p.y) * 2)
            sum += s
            if (s > best.s) best = { s: s, h: ((Math.atan2(p.y, p.x) + Math.PI) / (2 * Math.PI) + 0.5) % 1 }
        }
        return { s: best.s, h: best.h, avg: sum / 3 }
    }

    RowLayout {
        anchors.fill: parent; spacing: 0

        // ================= LEFT: monitor, scopes, shots =================
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 44; Layout.leftMargin: 18; Layout.rightMargin: 18; spacing: 10
                Text { text: "GRADE"; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 1; font.weight: Font.DemiBold; font.letterSpacing: 0.6 }
                Text { text: root.shots[root.shot].n + " · V1"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 }
                Item { Layout.fillWidth: true }
                Text { text: "Before / after"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 }
                FEChip { text: "Wipe"; checked: root.wipe; onClicked: root.wipe = !root.wipe }
                FEButton { text: "Reset grade"; implicitHeight: 26; onClicked: root.resetAll() }
            }

            // stage
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Item {
                    id: frame
                    width: Math.min(parent.width - 48, (parent.height - 12) * 16 / 9); height: width * 9 / 16
                    anchors.centerIn: parent

                    Rectangle { anchors.fill: parent; anchors.margins: -1; color: "black"; radius: 3 }

                    // ORIGINAL (underneath)
                    CoastalScene { anchors.fill: parent; palName: root.shots[root.shot].p }

                    // GRADED (right of the wipe line). Source is hidden; the effect draws it.
                    Item {
                        id: gradeSrc
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        CoastalScene { anchors.fill: parent; palName: root.shots[root.shot].p }
                        // warmth (orange / blue) and tint (magenta / green) as soft colour overlays
                        Rectangle { anchors.fill: parent; color: root.grade.wm >= 0 ? "#FF9A3C" : "#4A9DFF"; opacity: Math.abs(root.grade.wm) / 50 * 0.2 }
                        Rectangle { anchors.fill: parent; color: root.grade.ti >= 0 ? "#E040C8" : "#40E070"; opacity: Math.abs(root.grade.ti) / 50 * 0.12 }
                        // wheel push
                        Rectangle { anchors.fill: parent; color: Qt.hsla(root.wheelPush.h, 0.8, 0.5, 1)
                                    opacity: Math.min(0.5, root.wheelPush.avg * 0.9 + root.wheelPush.s * 0.25) }
                    }
                    Item {
                        x: root.wipe ? frame.width * root.wipePos : 0
                        width: frame.width - x; height: frame.height; clip: true
                        MultiEffect {
                            x: -parent.x; width: frame.width; height: frame.height
                            source: gradeSrc
                            brightness: root.grade.ex / 100
                            contrast: root.grade.co / 100
                            saturation: (root.grade.sa + root.grade.vi * 0.4) / 100
                        }
                    }
                    Rectangle { anchors.fill: parent; radius: 3; color: "transparent"; border.color: "#14FFFFFF" }

                    // labels + divider
                    Rectangle { visible: root.wipe; x: 12; y: 12; width: lo.implicitWidth + 14; height: 20; radius: 5; color: "#B30A0C0E"
                                Text { id: lo; anchors.centerIn: parent; text: "Original"; color: "white"; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall } }
                    Rectangle { x: frame.width - width - 12; y: 12; width: lg.implicitWidth + 14; height: 20; radius: 5; color: "#B30A0C0E"
                                Text { id: lg; anchors.centerIn: parent; text: "Graded"; color: "white"; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall } }
                    Rectangle { visible: root.wipe; x: frame.width * root.wipePos - 1; width: 2; height: frame.height; color: Theme.paper }

                    // drag the divider directly on the image
                    MouseArea {
                        visible: root.wipe
                        x: frame.width * root.wipePos - 14; width: 28; height: frame.height
                        cursorShape: Qt.SplitHCursor
                        onPositionChanged: (m) => { if (pressed) root.wipePos = Math.max(0, Math.min(1, root.wipePos + m.x / frame.width - 14 / frame.width)) }
                    }
                }
            }

            // wipe slider (keyboard-accessible twin of the divider)
            RowLayout {
                visible: root.wipe
                Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.preferredHeight: 28; spacing: 12
                Text { text: "Original"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5; Layout.preferredWidth: 56 }
                Slider { Layout.fillWidth: true; from: 0; to: 1; value: root.wipePos; onMoved: root.wipePos = value; Accessible.name: "Before and after wipe position" }
                Text { text: "Graded"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 56 }
            }

            // scopes + shots
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 232; color: Theme.p1
                Rectangle { width: parent.width; height: 1; color: Theme.line }
                RowLayout {
                    anchors.fill: parent; spacing: 0
                    ColumnLayout {
                        visible: root.width > 1500
                        Layout.preferredWidth: 520; Layout.fillHeight: true; Layout.margins: 12; Layout.leftMargin: 16; spacing: 8
                        RowLayout { spacing: 8
                            Text { text: "Scopes"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold }
                            FEChip { text: "RGB parade"; checked: true; autoExclusive: true }
                            FEChip { text: "Waveform"; autoExclusive: true }
                            FEChip { text: "Vectorscope"; autoExclusive: true } }
                        ParadeScope { Layout.fillWidth: true; Layout.fillHeight: true; grade: root.grade }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 12; Layout.leftMargin: 18; spacing: 8
                        RowLayout { spacing: 8
                            Text { text: "Shots"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold }
                            Text { text: "Grade one, then copy to similar shots"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 }
                            Item { Layout.fillWidth: true }
                            FEButton { text: "Match to this shot"; implicitHeight: 26 } }
                        Row {
                            spacing: 12
                            Repeater {
                                model: root.shots
                                delegate: AbstractButton {
                                    id: sh
                                    required property int index
                                    required property var modelData
                                    width: 132; height: 74
                                    focusPolicy: Qt.StrongFocus; hoverEnabled: true
                                    Accessible.role: Accessible.Button; Accessible.name: modelData.n
                                    onClicked: root.shot = index
                                    background: null
                                    contentItem: Item {
                                        transform: Translate { y: sh.hovered ? -2 : 0; Behavior on y { NumberAnimation { duration: Theme.durFast } } }
                                        CoastalScene { anchors.fill: parent; palName: sh.modelData.p; layer.enabled: true }
                                        Text { x: 6; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; text: sh.modelData.n; color: "white"
                                               style: Text.Outline; styleColor: "#B3000000"; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.weight: Font.Medium }
                                        Rectangle { visible: sh.index < 4; x: parent.width - 14; y: 6; width: 8; height: 8; radius: 4; color: Theme.ok }
                                        Rectangle { anchors.fill: parent; radius: 2; color: "transparent"
                                                    border.width: root.shot === sh.index ? 2 : (sh.visualFocus ? 2 : 0)
                                                    border.color: root.shot === sh.index ? Theme.accent : Theme.paper }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ================= RIGHT: grading panel =================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.width < 1560 ? 380 : 452
            color: Theme.p1
            Rectangle { width: 1; height: parent.height; color: Theme.line }

            ColumnLayout {
                anchors.fill: parent; spacing: 0

                // tabs
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 48; color: "transparent"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 20; anchors.bottom: parent.bottom; spacing: 18
                        Repeater {
                            model: ["Basic", "Wheels", "Curves", "Secondary"]
                            delegate: AbstractButton {
                                id: t
                                required property int index
                                required property string modelData
                                width: tl.implicitWidth + 8; height: 34
                                focusPolicy: Qt.StrongFocus; hoverEnabled: true
                                Accessible.role: Accessible.PageTab; Accessible.name: modelData
                                onClicked: root.tab = index
                                background: Rectangle { color: "transparent"; border.width: t.visualFocus ? 2 : 0; border.color: Theme.paper; radius: 4
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: Theme.accent; opacity: root.tab === t.index ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: Theme.durFast } } } }
                                contentItem: Text { id: tl; text: t.modelData; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    color: root.tab === t.index || t.hovered ? Theme.tx : Theme.tx2
                                    font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.Medium }
                            }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    currentIndex: root.tab

                    // ---------- BASIC ----------
                    Flickable {
                        contentWidth: width; contentHeight: basic.implicitHeight + 40; clip: true
                        ScrollBar.vertical: ScrollBar { }
                        Column {
                            id: basic
                            x: 20; y: 18; width: parent.width - 40; spacing: 6
                            Text { text: "LOOKS"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                            Row {
                                spacing: 10
                                Repeater {
                                    model: root.looks
                                    delegate: AbstractButton {
                                        id: lk
                                        required property var modelData
                                        width: (basic.width - 40) / 5; height: width * 0.75 + 22
                                        focusPolicy: Qt.StrongFocus; hoverEnabled: true
                                        Accessible.role: Accessible.RadioButton; Accessible.name: modelData.n; Accessible.checked: root.look === modelData.k
                                        onClicked: root.applyLook(modelData)
                                        background: null
                                        contentItem: Column {
                                            spacing: 6
                                            Rectangle { width: lk.width; height: lk.width * 0.75; radius: Theme.radiusS
                                                gradient: Gradient { orientation: Gradient.Horizontal
                                                    GradientStop { position: 0; color: lk.modelData.c0 } GradientStop { position: 1; color: lk.modelData.c1 } }
                                                border.width: root.look === lk.modelData.k || lk.visualFocus ? 2 : 0
                                                border.color: Theme.paper
                                                transform: Translate { y: lk.hovered ? -2 : 0; Behavior on y { NumberAnimation { duration: Theme.durFast } } } }
                                            Text { width: lk.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: lk.modelData.n
                                                   color: root.look === lk.modelData.k ? Theme.tx : Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 }
                                        }
                                    }
                                }
                            }
                            Item { width: 1; height: 14 }
                            Text { text: "LIGHT"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                            Repeater {
                                model: root.lightSliders
                                FESlider { required property var modelData; width: basic.width; label: modelData.n; from: -50; to: 50
                                           value: root.grade[modelData.k]; onMoved: (v) => root.setGrade(modelData.k, Math.round(v)) }
                            }
                            Item { width: 1; height: 10 }
                            Text { text: "COLOUR"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                            Rectangle { width: basic.width; height: 8; radius: 4
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "#4aa3ff" } GradientStop { position: 0.5; color: "#e8e4dc" } GradientStop { position: 1; color: "#ffb04a" } } }
                            Repeater {
                                model: root.colorSliders
                                FESlider { required property var modelData; width: basic.width; label: modelData.n; from: -50; to: 50
                                           value: root.grade[modelData.k]; onMoved: (v) => root.setGrade(modelData.k, Math.round(v)) }
                            }
                            Item { width: 1; height: 10 }
                            Rectangle {
                                width: basic.width; height: hint.implicitHeight + 28; radius: Theme.radiusM + 2; color: Theme.p2; border.color: Theme.line
                                Text { id: hint; x: 14; y: 14; width: parent.width - 28; wrapMode: Text.WordWrap; lineHeight: 1.4
                                       color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                                       text: "Need more control? Open Wheels. The Basic sliders stay applied underneath." }
                                TapHandler { onTapped: root.tab = 1 }
                            }
                        }
                    }

                    // ---------- WHEELS ----------
                    Flickable {
                        contentWidth: width; contentHeight: wcol.implicitHeight + 40; clip: true
                        Column {
                            id: wcol
                            x: 20; y: 18; width: parent.width - 40; spacing: 10
                            Row {
                                spacing: 14
                                Repeater {
                                    model: [ { k: "lift", n: "Lift" }, { k: "gamma", n: "Gamma" }, { k: "gain", n: "Gain" } ]
                                    ColorWheel {
                                        required property var modelData
                                        width: (wcol.width - 28) / 3; height: width + 44
                                        label: modelData.n
                                        offset: root.wheels[modelData.k]
                                        onMoved: (p) => root.setWheel(modelData.k, p)
                                    }
                                }
                            }
                            Item { width: 1; height: 8 }
                            Text { text: "MASTER"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                            Repeater {
                                model: [ { k: "ex", n: "Exposure" }, { k: "co", n: "Contrast" } ]
                                FESlider { required property var modelData; width: wcol.width; label: modelData.n; from: -50; to: 50
                                           value: root.grade[modelData.k]; onMoved: (v) => root.setGrade(modelData.k, Math.round(v)) }
                            }
                            Text { width: wcol.width; wrapMode: Text.WordWrap; lineHeight: 1.4; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                                   text: "Click or drag a wheel to push shadows, midtones or highlights toward a colour. Double-click to reset." }
                        }
                    }

                    // ---------- CURVES ----------
                    Flickable {
                        contentWidth: width; contentHeight: ccol.implicitHeight + 40; clip: true
                        Column {
                            id: ccol
                            x: 20; y: 18; width: parent.width - 40; spacing: 12
                            Rectangle {
                                id: cbox
                                width: ccol.width; height: width; radius: Theme.radiusL - 2; color: "#0B0C0E"; border.color: Theme.line
                                readonly property var cur: root.curves.find(c => c.k === root.curve)
                                Shape {
                                    anchors.fill: parent; anchors.margins: 1
                                    layer.enabled: true; layer.samples: 4
                                    // 240-unit design space scaled to the box
                                    transform: Scale { xScale: (cbox.width - 2) / 240; yScale: (cbox.height - 2) / 240 }
                                    ShapePath { strokeColor: Theme.line; strokeWidth: 1; fillColor: "transparent"
                                        PathSvg { path: "M60 0V240M120 0V240M180 0V240M0 60H240M0 120H240M0 180H240" } }
                                    ShapePath { strokeColor: "#3A3F47"; strokeWidth: 1; strokeStyle: ShapePath.DashLine; dashPattern: [3, 4]; fillColor: "transparent"
                                        PathSvg { path: "M0 240L240 0" } }
                                    ShapePath { strokeColor: Theme.tx; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                                        PathSvg { path: cbox.cur.d } }
                                }
                                Rectangle { width: 12; height: 12; radius: 6; color: Theme.paper; border.width: 2; border.color: "#17140F"
                                            x: cbox.cur.px / 240 * parent.width - 6; y: cbox.cur.py / 240 * parent.height - 6 }
                            }
                            Flow {
                                width: ccol.width; spacing: 6
                                Repeater {
                                    model: root.curves
                                    FEChip { required property var modelData; text: modelData.n; checked: root.curve === modelData.k; autoExclusive: true
                                             onClicked: root.curve = modelData.k }
                                }
                            }
                            Text { width: ccol.width; wrapMode: Text.WordWrap; lineHeight: 1.4; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                                   text: "Curves give exact control of tone. Start from a preset, then drag the point (point editing arrives with the engine)." }
                        }
                    }

                    // ---------- SECONDARY ----------
                    Flickable {
                        contentWidth: width; contentHeight: scol.implicitHeight + 40; clip: true
                        Column {
                            id: scol
                            x: 20; y: 18; width: parent.width - 40; spacing: 12
                            Text { text: "PICK A COLOUR RANGE"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall; font.letterSpacing: 0.8 }
                            Item { width: scol.width; height: 34
                                Rectangle { y: 3; width: parent.width; height: 28; radius: 7
                                    gradient: Gradient { orientation: Gradient.Horizontal
                                        GradientStop { position: 0.00; color: "#ff3333" } GradientStop { position: 0.17; color: "#ffdd33" } GradientStop { position: 0.33; color: "#33dd44" }
                                        GradientStop { position: 0.50; color: "#33dddd" } GradientStop { position: 0.67; color: "#3355ff" } GradientStop { position: 0.83; color: "#dd33ff" } GradientStop { position: 1.00; color: "#ff3333" } } }
                                Rectangle { x: parent.width * 0.06; width: parent.width * 0.14; height: 34; radius: 7; color: "#24FFFFFF"; border.width: 2; border.color: Theme.paper } }
                            Row { spacing: 10
                                Repeater { model: [ { k: "Hue", v: "24° ± 18" }, { k: "Softness", v: "35%" } ]
                                    Rectangle { required property var modelData; width: (scol.width - 10) / 2; height: 62; radius: Theme.radiusM + 2; color: Theme.p2; border.color: Theme.line
                                        Column { anchors.fill: parent; anchors.margins: 12; spacing: 2
                                            Text { text: modelData.k; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 }
                                            Text { text: modelData.v; color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: 18 } } } } }
                            Rectangle { width: scol.width; height: 58; radius: Theme.radiusM + 2; color: Theme.p2; border.color: Theme.line
                                Column { x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                    Text { text: "Protect skin tones"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.Medium }
                                    Text { text: "Keeps faces natural while you grade the scene"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5 } }
                                Switch { id: skin; checked: true; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; Accessible.name: "Protect skin tones" } }
                            Row { spacing: 8
                                FEButton { text: "Circle window"; width: (scol.width - 8) / 2 }
                                FEButton { text: "Gradient window"; width: (scol.width - 8) / 2 } }
                        }
                    }
                }

                // correction stack
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 104; color: "#111316"
                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                    Column {
                        anchors.fill: parent; anchors.margins: 14; anchors.leftMargin: 20; anchors.rightMargin: 20; spacing: 10
                        Row { width: parent.width
                            Text { text: "Corrections"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold; width: parent.width / 2 }
                            Text { text: "Applied top to bottom"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 0.5; width: parent.width / 2; horizontalAlignment: Text.AlignRight } }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [ { n: "01", t: "Primary", s: "Exposure · Colour" }, { n: "02", t: "Skin tones", s: "Qualifier · soft" }, { n: "03", t: "Look", s: "Teal Harbour · 24%" } ]
                                delegate: AbstractButton {
                                    id: nd
                                    required property int index
                                    required property var modelData
                                    width: (parent.width - 8 * 3 - 36) / 3; height: 54
                                    focusPolicy: Qt.StrongFocus; hoverEnabled: true
                                    Accessible.role: Accessible.Button; Accessible.name: modelData.t
                                    onClicked: root.node = index
                                    background: Rectangle { radius: Theme.radiusM + 2; color: Theme.p2
                                        border.width: root.node === nd.index || nd.visualFocus ? 2 : 1
                                        border.color: root.node === nd.index || nd.visualFocus ? Theme.paper : (nd.hovered ? "#5A606B" : Theme.line2) }
                                    contentItem: Row { spacing: 10; leftPadding: 8
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 6; color: Theme.p3
                                            Text { anchors.centerIn: parent; text: nd.modelData.n; color: Theme.tx2; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall } }
                                        Column { anchors.verticalCenter: parent.verticalCenter; width: nd.width - 60
                                            Text { width: parent.width; elide: Text.ElideRight; text: nd.modelData.t; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.Medium }
                                            Text { width: parent.width; elide: Text.ElideRight; text: nd.modelData.s; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall } }
                                    }
                                }
                            }
                            FEIconButton { width: 36; height: 36; iconPath: "M12 5v14M5 12h14"; tip: "Add correction" }
                        }
                    }
                }
            }
        }
    }
}
