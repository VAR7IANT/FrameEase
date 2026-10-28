import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import FrameEase

// Audio workspace: Sound check (assistant) | waveform + mixer | voice tools.
// Meters and loudness are synthesised from the faders; the engine will replace `level()`.
Item {
    id: root

    property var db: ({ dia: -4, mus: -14, sfx: -12 })
    property var pan: ({ dia: 0, mus: 0, sfx: -20 })
    property var mute: ({})
    property var solo: ({})
    property real master: 0
    property bool playing: false
    property int tick: 0
    property bool clean: true
    property real strength: 62
    property string eq: "voice"
    property string target: "yt"
    property bool silenceCut: false
    property var fixed: ({ duck: true, peak: false, wind: false })

    readonly property var channels: [
        { k: "dia", id: "A1", name: "Dialogue", color: "#7FC08F", fx: ["Clean voice", "Compressor"] },
        { k: "mus", id: "A2", name: "Music",    color: "#B795D0", fx: ["Auto-duck", "Low shelf −2 dB"] },
        { k: "sfx", id: "A3", name: "Sound FX", color: "#D6AE5E", fx: ["Limiter"] }
    ]
    readonly property var eqs: [
        { k: "flat",   n: "Flat",   d: "M0 65H320" },
        { k: "voice",  n: "Voice",  d: "M0 108C30 108 50 84 80 70S130 46 170 52S240 56 270 46S310 40 320 42" },
        { k: "warm",   n: "Warm",   d: "M0 40C40 40 70 52 110 62S200 70 250 82S300 100 320 104" },
        { k: "bright", n: "Bright", d: "M0 86C60 86 120 74 170 62S260 34 320 26" }
    ]
    readonly property var targets: [ { k: "yt", n: "Online", v: -14 }, { k: "pod", n: "Podcast", v: -16 }, { k: "br", n: "Broadcast", v: -23 } ]
    readonly property var pauses: [[190, 260], [470, 560], [790, 850]]   // in 1200-unit waveform space

    readonly property bool anySolo: Object.values(solo).some(v => v)
    readonly property real targetLufs: targets.find(t => t.k === target).v
    readonly property real lufs: Math.round((-17 + db.dia * 0.45 + db.mus * 0.15 + master + (clean ? 0.6 : 0)) * 10) / 10

    function level(k, i) {
        if (!playing || mute[k] || (anySolo && !solo[k])) return 0
        const base = k === "dia" ? 0.78 : k === "mus" ? 0.55 : 0.4
        const wob = Math.abs(Math.sin(tick * 0.9 + i * 1.7)) * 0.5 + Math.abs(Math.sin(tick * 0.33 + i)) * 0.3
        return Math.min(1, base * (0.4 + wob) * Math.pow(10, (db[k] + 4) / 40))
    }
    readonly property real mixLevel: Math.min(1, (level("dia", 0) + level("mus", 0) * 0.6 + level("sfx", 0) * 0.4) * Math.pow(10, master / 40))
    function setIn(prop, k, v) { const o = Object.assign({}, root[prop]); o[k] = v; root[prop] = o }
    function lufsPos(l) { return Math.max(0, Math.min(1, (l + 36) / 36)) }

    // pseudo waveform of the selected dialogue clip, in a 1200x150 box
    readonly property string wavePath: {
        let d = ""
        for (let x = 0; x < 1200; x += 4) {
            const inP = pauses.some(p => x >= p[0] && x <= p[1])
            const g = inP ? 0.04 : Math.max(0.08, Math.abs(Math.sin(x * 0.043) * Math.sin(x * 0.0071 + 1) + 0.35))
            const a = Math.min(1, g * (0.55 + 0.45 * Math.abs(Math.sin(x * 0.31 + 1)))) * 60
            d += "M" + x + " " + (75 - a).toFixed(1) + "V" + (75 + a).toFixed(1)
        }
        return d
    }
    readonly property string silencePath: silenceCut ? "" : pauses.map(p => "M" + p[0] + " 0H" + p[1] + "V150H" + p[0] + "Z").join("")

    Timer { interval: 90; repeat: true; running: root.playing; onTriggered: root.tick++ }

    RowLayout {
        anchors.fill: parent; spacing: 0

        // ================= Sound check =================
        Rectangle {
            visible: root.width >= 1560
            Layout.preferredWidth: 360; Layout.fillHeight: true; color: Theme.p1
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }
            Flickable {
                anchors.fill: parent; contentWidth: width; contentHeight: sc.implicitHeight + 44; clip: true
                ScrollBar.vertical: ScrollBar { }
                Column {
                    id: sc
                    x: 20; y: 22; width: parent.width - 40; spacing: 14
                    Text { text: "Sound check"; color: Theme.tx; font.family: Theme.fontDisplay; font.pixelSize: 30 }
                    Text { width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.4; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                           text: "We listened to the whole timeline. Here is what deserves your ears." }
                    Repeater {
                        model: [
                            { k: "duck", t: "Music masks the interview", b: "At 0:22 the score sits 4 dB above Mara. Auto-duck keeps her clear.", on: "Applied · −9 dB", off: "Apply auto-duck" },
                            { k: "peak", t: "Wake_whoosh peaks at −0.3 dBFS", b: "Close to clipping. A limiter protects it without changing the character.", on: "Limiter added", off: "Add limiter" },
                            { k: "wind", t: "Wind noise in Harbour_Walk", b: "Low rumble below 120 Hz for 14 seconds.", on: "High-pass on", off: "Reduce wind" }
                        ]
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool done: root.fixed[modelData.k]
                            width: sc.width; height: cardCol.implicitHeight + 24; radius: Theme.radiusL - 2; color: Theme.p2; border.color: Theme.line
                            Rectangle { x: 12; y: 12; width: 28; height: 28; radius: 14; color: card.done ? Theme.ok : Theme.warn
                                FEIcon { anchors.centerIn: parent; size: 15; color: "#10130F"; strokeWidth: 2
                                         path: card.done ? "M5 12l5 5 9-10" : "M12 8v5M12 17h.01" } }
                            Column {
                                id: cardCol
                                x: 52; y: 12; width: parent.width - 64; spacing: 3
                                Text { width: parent.width; wrapMode: Text.WordWrap; text: card.modelData.t; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5; font.weight: Font.DemiBold }
                                Text { width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.35; text: card.modelData.b; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 1 }
                                Item { width: 1; height: 6 }
                                FEChip { text: card.done ? card.modelData.on : card.modelData.off; checked: card.done
                                         onClicked: root.setIn("fixed", card.modelData.k, !card.done) }
                            }
                        }
                    }
                    Rectangle { width: sc.width; height: note.implicitHeight + 28; radius: Theme.radiusL - 2; color: "transparent"; border.color: Theme.line2
                        Text { id: note; x: 14; y: 14; width: parent.width - 28; wrapMode: Text.WordWrap; lineHeight: 1.4; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                               text: "Fixes are non-destructive. Each one is a node on the clip that you can bypass or tweak." }
                    }
                }
            }
        }

        // ================= Waveform + mixer =================
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 300
            ColumnLayout {
                anchors.fill: parent; spacing: 0

            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 16; spacing: 12
                Text { text: "MARA_INTERVIEW_A"; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall + 1; font.weight: Font.DemiBold; font.letterSpacing: 0.6 }
                Text { text: "Dialogue · A1 · 0:45 · stereo 48 kHz"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5 }
                Item { Layout.fillWidth: true }
                FEButton { text: root.silenceCut ? "Undo trim" : "Trim silences"; onClicked: root.silenceCut = !root.silenceCut }
                FEIconButton { iconPath: root.playing ? "M7 5v14M17 5v14" : "M8 5l11 7-11 7z"; tip: root.playing ? "Pause" : "Audition (Space)"; checked: true; iconFilled: !root.playing
                               implicitWidth: 34; implicitHeight: 34; onClicked: root.playing = !root.playing }
            }

            Rectangle {
                id: wavebox
                Layout.fillWidth: true; Layout.preferredHeight: 150; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 10
                radius: Theme.radiusL; color: "#0F1114"; border.color: Theme.line; clip: true
                Shape {
                    anchors.fill: parent
                    layer.enabled: true; layer.samples: 4
                    transform: Scale { xScale: wavebox.width / 1200; yScale: wavebox.height / 150 }
                    ShapePath { fillColor: "#29F2C14E"; strokeColor: "transparent"; PathSvg { path: root.silencePath } }
                    ShapePath { strokeColor: "#23272C"; strokeWidth: 1; fillColor: "transparent"; PathSvg { path: "M0 75H1200" } }
                    ShapePath { strokeColor: Theme.ok; strokeWidth: 2; fillColor: "transparent"; PathSvg { path: root.wavePath } }
                }
                Rectangle { x: (0.1 + (root.tick * 1.7 % 80) / 100) * parent.width; width: 2; height: parent.height; color: Theme.accent; visible: root.playing || root.tick > 0 }
                Text { x: 12; y: 8; text: "−6 dB"; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
                Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                       color: root.silenceCut ? Theme.ok : Theme.warn; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall + 0.5
                       text: root.silenceCut ? "3 pauses trimmed · 4.1 s saved" : "3 pauses longer than 1 s" }
            }

            Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: Math.max(width, mix.implicitWidth + 48); contentHeight: mix.implicitHeight + 44; clip: true
                ScrollBar.vertical: ScrollBar { }
                Row {
                    id: mix
                    x: Math.max(24, (parent.width - implicitWidth) / 2); y: 20; spacing: 14

                    Repeater {
                        model: root.channels
                        delegate: ChannelStrip {
                            required property var modelData
                            height: 600
                            name: modelData.name; chanId: modelData.id; swatch: modelData.color; inserts: modelData.fx
                            db: root.db[modelData.k]; pan: root.pan[modelData.k]
                            muted: !!root.mute[modelData.k]; soloed: !!root.solo[modelData.k]
                            meterL: root.level(modelData.k, 0); meterR: root.level(modelData.k, 1.3)
                            onDbMoved: (v) => root.setIn("db", modelData.k, v)
                            onPanMoved: (v) => root.setIn("pan", modelData.k, v)
                            onMuteToggled: root.setIn("mute", modelData.k, !root.mute[modelData.k])
                            onSoloToggled: root.setIn("solo", modelData.k, !root.solo[modelData.k])
                        }
                    }

                    // master: loudness readout, meter, fader, targets
                    ChannelStrip {
                        master: true; name: "Master"; chanId: ""; swatch: Theme.paper; height: 600
                        db: root.master; meterL: root.mixLevel; meterR: root.mixLevel * 0.94
                        onDbMoved: (v) => root.master = v
                        // loudness card sits above the fader area
                        Rectangle {
                            x: 12; y: 40; width: parent.width - 24; height: 96; radius: Theme.radiusM + 2; color: "#0B0C0E"; border.color: Theme.line
                            Column { x: 12; y: 10; spacing: 3
                                Text { text: "Integrated loudness"; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall }
                                Text { text: root.lufs.toFixed(1); color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: 28; font.weight: Font.Medium }
                                Text { text: "LUFS · target " + root.targetLufs; color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall } }
                            Rectangle { x: 12; y: parent.height - 14; width: parent.width - 24; height: 6; radius: 3; color: "#1C1F24"
                                Rectangle { width: parent.width * root.lufsPos(root.lufs); height: parent.height; radius: 3
                                            color: Math.abs(root.lufs - root.targetLufs) <= 1.5 ? Theme.ok : Theme.warn }
                                Rectangle { x: parent.width * root.lufsPos(root.targetLufs) - 1; y: -2; width: 2; height: parent.height + 4; color: Theme.paper } }
                        }
                    }
                }
            }
        }
        }

        // ================= Voice tools =================
        Rectangle {
            Layout.preferredWidth: root.width < 1560 ? 330 : 372; Layout.fillHeight: true; color: Theme.p1
            Rectangle { width: 1; height: parent.height; color: Theme.line }
            Flickable {
                anchors.fill: parent; contentWidth: width; contentHeight: vt.implicitHeight + 44; clip: true
                ScrollBar.vertical: ScrollBar { }
                Column {
                    id: vt
                    x: 20; y: 22; width: parent.width - 40; spacing: 18

                    // Clean voice
                    Column { width: parent.width; spacing: 8
                        Row { width: parent.width
                            Text { width: parent.width - cleanSw.width; text: "Clean voice"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            Switch { id: cleanSw; checked: root.clean; onToggled: root.clean = checked; Accessible.name: "Clean voice" } }
                        Text { width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.4; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                               text: "One control instead of five plug-ins: noise, room echo and breath, balanced for speech." }
                        FESlider { width: parent.width; label: "Strength"; from: 0; to: 100; value: root.strength; unit: "%"; opacity: root.clean ? 1 : 0.4; enabled: root.clean
                                   onMoved: (v) => root.strength = Math.round(v) }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }

                    // Tone
                    Column { width: parent.width; spacing: 10
                        Text { text: "Tone"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Rectangle { id: eqbox; width: parent.width; height: width * 130 / 320; radius: Theme.radiusL - 2; color: "#0B0C0E"; border.color: Theme.line; clip: true
                            Shape { anchors.fill: parent; layer.enabled: true; layer.samples: 4
                                transform: Scale { xScale: eqbox.width / 320; yScale: eqbox.height / 130 }
                                ShapePath { strokeColor: "#1F2328"; strokeWidth: 1; fillColor: "transparent"; PathSvg { path: "M0 65H320M80 0V130M160 0V130M240 0V130" } }
                                ShapePath { strokeColor: Theme.tx; strokeWidth: 2.2; fillColor: "#12ECE8E0"; capStyle: ShapePath.RoundCap
                                    PathSvg { path: root.eqs.find(e => e.k === root.eq).d + " L320 130 L0 130Z" } } }
                            Repeater { model: [ { t: "100", x: 6 }, { t: "1k", x: 86 }, { t: "5k", x: 166 }, { t: "16k", x: 286 } ]
                                Text { required property var modelData; x: modelData.x / 320 * eqbox.width; y: eqbox.height - 14; text: modelData.t
                                       color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall } } }
                        Flow { width: parent.width; spacing: 6
                            Repeater { model: root.eqs
                                FEChip { required property var modelData; text: modelData.n; checked: root.eq === modelData.k; autoExclusive: true; onClicked: root.eq = modelData.k } } }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }

                    // Loudness target
                    Column { width: parent.width; spacing: 8
                        Text { text: "Loudness target"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Flow { width: parent.width; spacing: 6
                            Repeater { model: root.targets
                                FEChip { required property var modelData; text: modelData.n + "  " + modelData.v; checked: root.target === modelData.k; autoExclusive: true; onClicked: root.target = modelData.k } } }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }

                    // Ducking
                    Column { width: parent.width; spacing: 8
                        Row { width: parent.width
                            Text { width: parent.width - 60; text: "Music ducking"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text { text: "−9 dB"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.sizeBody } }
                        Text { width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.4; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody - 0.5
                               text: "Music dips under dialogue and swells back in the gaps. It shows as a dashed line on the music clip." }
                        Row { spacing: 10
                            Repeater { model: [ { k: "Attack", v: "0.8 s" }, { k: "Release", v: "1.2 s" } ]
                                Rectangle { required property var modelData; width: (vt.width - 10) / 2; height: 52; radius: Theme.radiusM + 1; color: Theme.p2; border.color: Theme.line
                                    Column { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                        Text { text: modelData.k; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeSmall }
                                        Text { text: modelData.v; color: Theme.tx; font.family: Theme.fontMono; font.pixelSize: Theme.sizeBody } } } } }
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Space"; enabled: root.visible; onActivated: root.playing = !root.playing }
}
