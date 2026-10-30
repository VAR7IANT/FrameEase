import QtQuick
import FrameEase

// A visibly disabled button that says why when hovered. Use for features that need a backend
// that does not exist yet, so nothing on screen is silently dead.
Item {
    id: root
    property alias text: btn.text
    property string reason
    property alias implicitButtonHeight: btn.implicitHeight
    readonly property bool available: btn.enabled     // always false: this component only renders unavailable features

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: btn.text + " (unavailable)"
    Accessible.description: reason

    FEButton { id: btn; anchors.fill: parent; enabled: false }
    FEDisabledTip { anchors.fill: parent; text: root.reason }
}
