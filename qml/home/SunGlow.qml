pragma ComponentBehavior: Bound
import QtQuick
import FrameEase

// Soft sun glow, drawn at the item's origin: opaque out to `coreRadius`, then fading linearly to nothing at
// `glowRadius`, like the design's CSS/SVG radial gradients. QtQuick has no radial gradient fill without a shader
// effect (the software renderer used for the offscreen CI pass has none), so the fade is built from `steps`
// stacked translucent discs whose alphas are chosen so the *cumulative* alpha at every ring equals the linear target.
// With 16+ steps the bands are below what the eye resolves.
Item {
    id: root
    property color color: "#FFFFFF"
    property real coreRadius: 0
    property real glowRadius: 100
    property real peak: 1            // alpha where the glow meets the core
    property int steps: 16

    // Target cumulative alpha of ring k (0 = outermost): rises linearly toward the core.
    function target(k) { return root.peak * (k + 0.5) / root.steps }
    // Alpha of the ring's own disc so that stacking it on rings 0..k-1 reaches target(k).
    function ringAlpha(k) { return k === 0 ? target(0) : 1 - (1 - target(k)) / (1 - target(k - 1)) }

    Repeater {
        model: root.glowRadius > root.coreRadius ? root.steps : 0
        Rectangle {
            required property int index
            readonly property real r: root.coreRadius + (root.glowRadius - root.coreRadius) * (1 - index / root.steps)
            x: -r; y: -r; width: 2 * r; height: 2 * r; radius: r
            color: root.color
            opacity: root.ringAlpha(index)
        }
    }
    Rectangle {
        visible: root.coreRadius > 0
        x: -root.coreRadius; y: -root.coreRadius
        width: 2 * root.coreRadius; height: width; radius: root.coreRadius
        color: root.color
    }
}
