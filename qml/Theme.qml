pragma Singleton
import QtQuick

// FrameEase design tokens. One source of truth, mirrored from the HTML design canvas.
QtObject {
    // Surfaces: a warm-neutral graphite ramp. Content (video) is always the brightest thing on screen.
    readonly property color void_: "#0E0F11"
    readonly property color p1: "#14161A"      // panels
    readonly property color p2: "#1B1E23"      // raised
    readonly property color p3: "#262A30"      // hover / inputs
    readonly property color line: "#23272C"
    readonly property color line2: "#363B43"

    // Text. tx3 is the lowest allowed grey: 5.2:1 on p1.
    readonly property color tx: "#ECE8E0"
    readonly property color tx2: "#A9A69F"
    readonly property color tx3: "#878A92"

    // One accent, reserved for "now" (playhead) and the primary action.
    property color accent: "#FF5B3A"
    readonly property color accentInk: "#1A0C08"
    // Selection / focus is paper-cream so it never competes with the accent.
    readonly property color paper: "#F2E9D8"

    // Clip families differ in lightness as well as hue (colour-blind safe).
    readonly property var clipColors: ({
        title: "#D9C49C", broll: "#3C5A78", main: "#2E6670",
        dialogue: "#3F6D52", music: "#6C4C7F", sfx: "#8A6A2C"
    })

    readonly property color ok: "#7BD389"
    readonly property color warn: "#F2C14E"

    // Shape & rhythm
    readonly property int radiusS: 6
    readonly property int radiusM: 8
    readonly property int radiusL: 12
    readonly property int gap: 8
    readonly property int pad: 14

    // Type. Instrument Sans / Geist Mono are bundled in resources/fonts (see README);
    // Segoe UI Variable is the native Windows 11 fallback.
    readonly property string fontUI: "Instrument Sans, Segoe UI Variable, Segoe UI, sans-serif"
    readonly property string fontMono: "Geist Mono, Cascadia Mono, Consolas, monospace"
    readonly property string fontDisplay: "Instrument Serif, Georgia, serif"
    readonly property int sizeBody: 13
    readonly property int sizeSmall: 11

    // Motion: everything uses one expressive-out curve, short.
    readonly property int durFast: 120
    readonly property int durMed: 200
    readonly property var easeOut: Easing.OutCubic
}
