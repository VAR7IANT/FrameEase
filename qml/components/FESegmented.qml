import QtQuick
import QtQuick.Controls

// Two-or-more option segmented control (e.g. Simple | Pro).
Rectangle {
    id: root
    property var options: []          // ["Simple", "Pro"]
    property int currentIndex: 0
    signal activated(int index)

    implicitHeight: 28
    implicitWidth: row.implicitWidth + 4
    radius: Theme.radiusM
    color: "#0F1114"
    border.color: Theme.line
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0
        Repeater {
            model: root.options
            delegate: AbstractButton {
                required property int index
                required property string modelData
                width: lbl.implicitWidth + 20
                height: 22
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData
                Accessible.checked: root.currentIndex === index
                onClicked: { root.currentIndex = index; root.activated(index) }
                background: Rectangle {
                    radius: Theme.radiusS
                    color: root.currentIndex === index ? Theme.p3 : "transparent"
                    border.width: parent.visualFocus ? 2 : 0
                    border.color: Theme.paper
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
                contentItem: Text {
                    id: lbl
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.currentIndex === index ? Theme.tx : Theme.tx2
                    font.family: Theme.fontUI
                    font.pixelSize: Theme.sizeSmall + 0.5
                    font.weight: Font.Medium
                }
            }
        }
    }
}
