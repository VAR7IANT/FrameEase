import QtQuick
import FrameEase

// RGB parade. Traces are synthesised from the grade so the scope reacts to every slider;
// the real implementation will read from the engine's GPU histogram buffer.
Rectangle {
    id: root
    property var grade: ({ ex: 0, wm: 0, ti: 0 })
    color: "#0B0C0E"
    radius: Theme.radiusS
    border.color: Theme.line

    onGradeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 1
        onPaint: {
            const ctx = getContext("2d"), w = width, h = height, col = w / 3
            ctx.reset()
            ctx.strokeStyle = "#23272C"; ctx.lineWidth = 1
            for (let i = 1; i < 5; i++) { ctx.beginPath(); ctx.moveTo(0, h * i / 5); ctx.lineTo(w, h * i / 5); ctx.stroke() }
            ctx.strokeStyle = "#2B3036"
            for (let c = 1; c < 3; c++) { ctx.beginPath(); ctx.moveTo(col * c, 0); ctx.lineTo(col * c, h); ctx.stroke() }

            const chans = [{ k: "R", base: 0.62, ph: 0, col: "#ff6a5c" }, { k: "G", base: 0.5, ph: 0.5, col: "#6fdc88" }, { k: "B", base: 0.4, ph: 1, col: "#6aa8ff" }]
            chans.forEach((ch, ci) => {
                const shift = (ch.k === "R" ? root.grade.wm : ch.k === "B" ? -root.grade.wm : root.grade.ti * -0.4) / 120
                ctx.strokeStyle = ch.col; ctx.globalAlpha = 0.9; ctx.lineWidth = 1.3
                ctx.beginPath()
                for (let x = 0; x <= col; x += 2) {
                    const f = x / col
                    let lvl = ch.base + 0.3 * Math.sin(f * 6.28 + ch.ph) * (1 - f * 0.3) + shift + root.grade.ex / 160 + (f < 0.2 ? 0.12 : 0)
                    lvl = Math.max(0.02, Math.min(0.98, lvl))
                    const y = h - lvl * (h - 8) - 4 + Math.sin(x * 3.7 + ci) * 2
                    if (x === 0) ctx.moveTo(ci * col + x, y); else ctx.lineTo(ci * col + x, y)
                }
                ctx.stroke()
            })
        }
    }
}
