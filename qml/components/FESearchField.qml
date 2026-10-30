import QtQuick
import QtQuick.Controls
import FrameEase

// Single-line search box: icon, placeholder, optional keyboard hint, and a clear button.
// Escape clears first, then leaves the field.
TextField {
    id: root
    property string hint: ""       // e.g. "Ctrl K", shown while idle and empty
    signal cleared()

    implicitHeight: 32
    implicitWidth: 230
    leftPadding: 32
    rightPadding: 44
    selectByMouse: true
    hoverEnabled: true
    color: Theme.tx
    selectionColor: Theme.paper
    selectedTextColor: "#17140F"
    placeholderTextColor: Theme.tx3
    font.family: Theme.fontUI
    font.pixelSize: Theme.sizeBody
    verticalAlignment: TextInput.AlignVCenter
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholderText

    function clearText() { if (text.length) { text = ""; cleared() } }
    Keys.onEscapePressed: (event) => {
        if (text.length) clearText(); else focus = false
        event.accepted = true
    }

    background: Rectangle {
        radius: Theme.radiusM
        color: "#111316"
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.paper : (root.hovered ? "#4A505A" : Theme.line2)
    }

    FEIcon {
        x: 10; anchors.verticalCenter: parent.verticalCenter
        size: 15
        color: root.activeFocus ? Theme.tx : Theme.tx3
        path: "M17 11a6 6 0 1 1 -12 0a6 6 0 1 1 12 0 M20 20l-4.5 -4.5"
    }
    // keyboard hint
    Rectangle {
        visible: root.text.length === 0 && !root.activeFocus && root.hint.length > 0
        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        width: hintText.implicitWidth + 12; height: 20; radius: 4
        color: "transparent"; border.color: Theme.line2
        Text { id: hintText; anchors.centerIn: parent; text: root.hint; color: Theme.tx3
               font.family: Theme.fontMono; font.pixelSize: Theme.sizeSmall }
    }
    // clear button
    AbstractButton {
        id: clearBtn
        objectName: root.objectName + ".clear"
        visible: root.text.length > 0
        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24
        focusPolicy: Qt.NoFocus; hoverEnabled: true
        Accessible.role: Accessible.Button; Accessible.name: "Clear search"
        onClicked: { root.clearText(); root.forceActiveFocus() }
        background: Rectangle { radius: 6; color: clearBtn.hovered ? Theme.p3 : "transparent" }
        contentItem: Item {
            FEIcon { anchors.centerIn: parent; size: 13; path: "M6 6l12 12M18 6L6 18"; color: clearBtn.hovered ? Theme.tx : Theme.tx2 }
        }
    }
}
