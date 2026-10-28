import QtQuick
import QtQuick.Controls
import FrameEase

// Explains why a control is unavailable. A disabled Item receives no hover, so place this as a
// *sibling* on top of the disabled control (it does not block clicks) rather than as its child.
Item {
    id: root
    property string text
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered && root.text.length > 0
    ToolTip.delay: 400
    ToolTip.text: root.text
}
