import QtQuick
import FrameEase

// Icon-button twin of FEUnavailableButton: drawn dimmed and disabled, and says why when hovered
// (a disabled item gets no hover itself, so the explanation is a sibling overlay).
Item {
    id: root
    property alias iconPath: btn.iconPath
    property string tip          // what the button would do, e.g. "Undo"
    property string reason       // why it cannot be used yet
    readonly property bool available: btn.enabled     // always false: this component only renders unavailable features

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: tip + " (unavailable)"
    Accessible.description: reason

    FEIconButton { id: btn; anchors.fill: parent; enabled: false; tip: root.tip }
    FEDisabledTip { anchors.fill: parent; text: root.tip + " is unavailable: " + root.reason }
}
