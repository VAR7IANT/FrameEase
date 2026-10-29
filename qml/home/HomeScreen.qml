import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import FrameEase

// Project launch dashboard. Not a workspace: it owns the whole window until a project is opened.
// All data comes from MockLibrary (in-memory sample projects). Nothing is read from or written to disk.
Rectangle {
    id: root
    objectName: "homeScreen"
    color: Theme.void_

    // `workspace` is an index into Main.qml's workspace list (0 Media, 1 Edit).
    signal openProject(string projectId, int workspace)
    signal createProject(string formatKey, int workspace)

    property string fmt: "wide"
    property string filter: "All"
    property string selectedId: ""
    readonly property string query: searchField.text.trim().toLowerCase()

    readonly property bool wide: width > 1500       // side panel + 4 columns; the design hides the panel at max-width 1500
    readonly property int cols: wide ? 4 : 3
    readonly property int padX: 72

    readonly property var filtered: MockLibrary.projects.filter(p =>
        (filter === "All" || (filter === "Films" && p.kind === "Film") || (filter === "Shorts" && p.kind === "Short") || (filter === "Shared" && p.shared))
        && (query === "" || p.name.toLowerCase().indexOf(query) >= 0 || p.spec.toLowerCase().indexOf(query) >= 0 || p.kind.toLowerCase().indexOf(query) >= 0))
    readonly property var selection: {
        for (let i = 0; i < filtered.length; ++i)
            if (filtered[i].id === selectedId) return filtered[i]
        return null
    }
    // A selection that has been filtered away is dropped, so the actions never refer to a hidden card.
    onFilteredChanged: if (selectedId !== "" && !filtered.some(p => p.id === selectedId)) selectedId = ""

    readonly property string greeting: {
        const d = new Date(), h = d.getHours()
        return Qt.formatDate(d, "dddd") + " " + (h < 5 ? "night" : h < 12 ? "morning" : h < 17 ? "afternoon" : h < 22 ? "evening" : "night")
    }

    function focusSearch() { searchField.forceActiveFocus(); searchField.selectAll() }
    function resetFilters() { searchField.text = ""; filter = "All" }

    Shortcut { sequence: "Ctrl+K"; enabled: root.visible; onActivated: root.focusSearch() }
    Shortcut { sequence: "Ctrl+F"; enabled: root.visible; onActivated: root.focusSearch() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- header ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48; color: Theme.void_
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 14
                BrandMark { }
                Item { Layout.fillWidth: true }
                FESearchField {
                    id: searchField
                    objectName: "searchField"
                    placeholderText: "Search projects"
                    hint: "Ctrl K"
                    Layout.preferredWidth: 230
                }
                FEUnavailableIconButton {
                    objectName: "settingsButton"
                    tip: "Settings"
                    reason: "settings are not built yet."
                    iconPath: "M15 12a3 3 0 1 1 -6 0a3 3 0 1 1 6 0 M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1"
                }
            }
        }

        // Plain anchors rather than a RowLayout: the side panel appears and disappears with the window width, and anchors
        // re-evaluate the same way in every Qt version, where a layout can hold on to the hidden panel's width after a resize.
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // ---- main column ----
            Flickable {
                id: scroller
                objectName: "homeScroll"
                anchors.left: parent.left; anchors.right: side.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                clip: true
                contentWidth: width
                contentHeight: page.height + 52 + 56
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }

                ColumnLayout {
                    id: page
                    x: root.padX; y: 52
                    width: scroller.width - 2 * root.padX
                    spacing: 0

                    Text {
                        text: root.greeting
                        color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: 12
                        font.letterSpacing: 1; font.capitalization: Font.AllUppercase
                    }
                    Text {
                        objectName: "homeHeadline"
                        Layout.topMargin: 10
                        Layout.preferredWidth: Math.min(900, page.width)
                        text: "Pick up where the <i>light</i> left off."
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap
                        // CSS line-height 1 = a 68px box with the glyphs centred in it. (Rich text ignores a fixed lineHeight, and the font's
                        // natural line is ~89px tall, which would push everything below down by 21px.) Grows if it ever wraps.
                        verticalAlignment: Text.AlignVCenter
                        Layout.preferredHeight: lineCount > 1 ? contentHeight : 68
                        color: Theme.tx; font.family: Theme.fontDisplay; font.pixelSize: 68; font.letterSpacing: -1
                        Accessible.role: Accessible.Heading
                    }

                    // ---- continue ----
                    ContinueHero {
                        Layout.topMargin: 40
                        Layout.fillWidth: true; Layout.preferredHeight: 300
                        project: MockLibrary.projects[0]
                        onClicked: root.openProject(project.id, 1)
                    }

                    // ---- new project ----
                    RowLayout {
                        Layout.topMargin: 44; Layout.fillWidth: true; spacing: 14
                        Text { text: "Start something new"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 18; font.weight: Font.DemiBold
                               Layout.alignment: Qt.AlignBaseline; Accessible.role: Accessible.Heading }
                        Text { text: "Choose a shape. Everything else can change later."; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody
                               Layout.alignment: Qt.AlignBaseline; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    RowLayout {
                        id: formatRow
                        Layout.topMargin: 16; Layout.fillWidth: true; Layout.preferredHeight: 124
                        spacing: 14
                        readonly property real unit: (width - 4 * spacing) / 5.5
                        Repeater {
                            model: MockLibrary.formats
                            FormatCard {
                                required property var modelData
                                format: modelData
                                checked: root.fmt === modelData.k
                                onClicked: root.fmt = modelData.k
                                Layout.preferredWidth: formatRow.unit; Layout.fillWidth: true; Layout.fillHeight: true
                            }
                        }
                        // Drop zone. Accepts a drop so the interaction is discoverable, but reads nothing.
                        Item {
                            id: dropZone
                            property string note: ""
                            Layout.preferredWidth: formatRow.unit * 1.5; Layout.fillWidth: true; Layout.fillHeight: true
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Drop footage here. " + (note.length ? note : "Importing is not implemented yet.")

                            DropArea {
                                id: dropArea
                                anchors.fill: parent
                                onDropped: (drop) => {
                                    const n = drop.hasUrls ? drop.urls.length : 0
                                    dropZone.note = (n === 1 ? "1 file was dropped." : n + " files were dropped.") + " Importing isn’t built yet, so nothing was read."
                                    noteTimer.restart()
                                    drop.accept()
                                }
                            }
                            Timer { id: noteTimer; interval: 7000; onTriggered: dropZone.note = "" }

                            Shape {
                                anchors.fill: parent
                                ShapePath {
                                    strokeColor: dropArea.containsDrag ? Theme.accent : "#444A53"
                                    strokeWidth: 1.5; strokeStyle: ShapePath.DashLine; dashPattern: [4, 3]
                                    fillColor: dropArea.containsDrag ? Qt.rgba(1, 1, 1, 0.03) : "transparent"
                                    PathSvg {
                                        readonly property real w: dropZone.width - 2
                                        readonly property real h: dropZone.height - 2
                                        readonly property real r: 12
                                        path: "M " + (1 + r) + " 1 H " + (1 + w - r) + " A " + r + " " + r + " 0 0 1 " + (1 + w) + " " + (1 + r)
                                            + " V " + (1 + h - r) + " A " + r + " " + r + " 0 0 1 " + (1 + w - r) + " " + (1 + h)
                                            + " H " + (1 + r) + " A " + r + " " + r + " 0 0 1 1 " + (1 + h - r)
                                            + " V " + (1 + r) + " A " + r + " " + r + " 0 0 1 " + (1 + r) + " 1 Z"
                                    }
                                }
                            }
                            ColumnLayout {
                                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; spacing: 10
                                Item { Layout.fillHeight: true }
                                RowLayout {
                                    spacing: 10
                                    FEIcon { size: 20; color: Theme.tx; path: "M12 16V4M7 9l5-5 5 5M4 16v4h16v-4" }
                                    Text { text: "Drop footage here"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.DemiBold }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap; lineHeightMode: Text.FixedHeight; lineHeight: 19     // 13px x 1.45
                                    text: dropZone.note.length ? dropZone.note
                                        : "We’ll read the frame rate and size, and build a " + MockLibrary.format(root.fmt).short + " project around it."
                                    color: dropZone.note.length ? Theme.warn : Theme.tx2
                                    font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody
                                }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    RowLayout {
                        Layout.topMargin: 16; Layout.fillWidth: true; spacing: 12
                        FEButton {
                            objectName: "createProject"
                            primary: true; hPadding: 18; implicitHeight: 38
                            text: "Create " + MockLibrary.format(root.fmt).short + " project"
                            onClicked: root.createProject(root.fmt, 1)
                        }
                        FEButton {
                            objectName: "importFirst"
                            hPadding: 18; implicitHeight: 38
                            text: "Import media first"
                            Accessible.description: "Starts a new project in the Media workspace, which is not built yet. No files are imported."
                            onClicked: root.createProject(root.fmt, 0)
                        }
                        FEUnavailableButton {
                            objectName: "openFromDisk"
                            implicitButtonHeight: 38
                            text: "Open from disk…"
                            reason: "Project files don’t exist yet. This prototype keeps nothing on disk."
                        }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: "Mock projects · nothing is saved to disk"
                            color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody
                        }
                    }

                    // ---- recent ----
                    RowLayout {
                        Layout.topMargin: 52; Layout.fillWidth: true; Layout.preferredHeight: 30; spacing: 14
                        Text { text: "Recent"; color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 18; font.weight: Font.DemiBold
                               Accessible.role: Accessible.Heading }
                        Text {
                            objectName: "recentCount"
                            text: root.filtered.length === MockLibrary.projects.length ? "" + MockLibrary.projects.length
                                  : root.filtered.length + " of " + MockLibrary.projects.length
                            color: Theme.tx3; font.family: Theme.fontMono; font.pixelSize: Theme.sizeBody
                        }
                        Row {
                            spacing: 6
                            Repeater {
                                model: ["All", "Films", "Shorts", "Shared"]
                                FEChip {
                                    required property string modelData
                                    objectName: "filterChip." + modelData
                                    text: modelData
                                    checkable: false
                                    checked: root.filter === modelData
                                    implicitHeight: 26
                                    onClicked: root.filter = modelData
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: !root.selection
                            text: "Sorted by last opened"
                            color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody
                        }
                        RowLayout {
                            objectName: "selectionBar"
                            visible: !!root.selection
                            spacing: 8
                            Text {
                                Layout.maximumWidth: 200; elide: Text.ElideRight
                                text: root.selection ? root.selection.name + " selected" : ""
                                color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody
                            }
                            FEButton {
                                objectName: "selectionOpen"
                                text: "Open"
                                onClicked: root.openProject(root.selection.id, 1)
                            }
                            FEUnavailableButton {
                                text: "Show in folder"
                                reason: "Needs project files on disk, which this prototype doesn’t have yet."
                            }
                            FEUnavailableButton {
                                text: "Duplicate"
                                reason: "Needs project files on disk, which this prototype doesn’t have yet."
                            }
                        }
                    }

                    Grid {
                        id: grid
                        visible: root.filtered.length > 0
                        Layout.topMargin: 18; Layout.fillWidth: true
                        columns: root.cols; columnSpacing: 20; rowSpacing: 26
                        readonly property real cell: (page.width - (columns - 1) * columnSpacing) / columns
                        Repeater {
                            model: root.filtered
                            ProjectCard {
                                required property var modelData
                                project: modelData
                                width: grid.cell
                                selected: root.selectedId === modelData.id
                                onClicked: root.selectedId = modelData.id
                                onOpenRequested: root.openProject(modelData.id, 1)
                            }
                        }
                    }
                    Rectangle {
                        objectName: "recentEmpty"
                        visible: root.filtered.length === 0
                        Layout.topMargin: 18; Layout.fillWidth: true; Layout.preferredHeight: 150
                        radius: Theme.radiusL; color: Theme.p1; border.color: Theme.line2
                        Accessible.role: Accessible.StaticText
                        Accessible.name: "No projects match"
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.query.length ? "No projects match “" + searchField.text.trim() + "”" : "No projects in this filter"
                                color: Theme.tx; font.family: Theme.fontUI; font.pixelSize: 15; font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Try another word, or show everything again."
                                color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody
                            }
                            FEButton {
                                objectName: "clearFilters"
                                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8
                                text: "Clear search and filters"
                                onClicked: root.resetFilters()
                            }
                        }
                    }
                }
            }

            // ---- side panel (wide windows only) ----
            Rectangle {
                id: side
                objectName: "homeSide"
                visible: root.wide
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: root.wide ? 392 : 0
                color: Theme.p1
                Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: Theme.line }
                Flickable {
                    anchors.fill: parent; anchors.leftMargin: 1
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width; contentHeight: sideCol.height + 72
                    ScrollBar.vertical: ScrollBar { }
                    ColumnLayout {
                        id: sideCol
                        x: 28; y: 36; width: parent.width - 56; spacing: 0

                        Text { text: "Quick starts"; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: 12; font.weight: Font.DemiBold
                               font.letterSpacing: 1; font.capitalization: Font.AllUppercase; Accessible.role: Accessible.Heading }
                        Text { Layout.topMargin: 6; Layout.fillWidth: true; wrapMode: Text.WordWrap
                               text: "Previews of guided starts. They need the editing engine, so they can’t be launched yet."
                               color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; lineHeightMode: Text.FixedHeight; lineHeight: 17 }
                        ColumnLayout {
                            Layout.topMargin: 14; Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: MockLibrary.quickStarts
                                Item {
                                    id: qs
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 96
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: modelData.name + ". " + modelData.meta + " Needs the editing engine."
                                    HoverHandler { id: qsHover }
                                    ToolTip.visible: qsHover.hovered; ToolTip.delay: 400
                                    ToolTip.text: "Needs the editing engine, which isn’t built yet"
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 10; spacing: 14
                                        Rectangle {
                                            Layout.preferredWidth: 52; Layout.preferredHeight: 52; radius: 9; opacity: 0.7
                                            gradient: Gradient { GradientStop { position: 0; color: qs.modelData.c1 } GradientStop { position: 1; color: qs.modelData.c2 } }
                                            FEIcon { anchors.centerIn: parent; size: 20; color: "#FFFFFF"; path: qs.modelData.d }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 3
                                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: qs.modelData.name
                                                   color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; font.weight: Font.DemiBold }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                                   text: qs.modelData.meta; color: Theme.tx3; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody; lineHeightMode: Text.FixedHeight; lineHeight: 17.5 }   // 13px x 1.35
                                            FETag { Layout.topMargin: 3; implicitHeight: 18; text: "Needs engine" }
                                        }
                                    }
                                }
                            }
                        }

                        Text { Layout.topMargin: 40; text: "Five keys that go far"; color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: 12; font.weight: Font.DemiBold
                               font.letterSpacing: 1; font.capitalization: Font.AllUppercase; Accessible.role: Accessible.Heading }
                        ColumnLayout {
                            Layout.topMargin: 14; Layout.fillWidth: true; spacing: 0
                            Repeater {
                                model: MockLibrary.keys
                                Item {
                                    id: kr
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 40
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                                    RowLayout {
                                        anchors.fill: parent; spacing: 12
                                        FEKeyCap { text: kr.modelData.key; bright: true; minWidth: 52; Layout.preferredWidth: Math.max(52, implicitWidth + 4) }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: kr.modelData.what
                                               color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.topMargin: 36; Layout.fillWidth: true
                            implicitHeight: tipCol.implicitHeight + 36
                            radius: Theme.radiusL; color: Theme.p2; border.color: Theme.line2
                            ColumnLayout {
                                id: tipCol
                                anchors.fill: parent; anchors.margins: 18; spacing: 8
                                // "Press [Ctrl K] and say what you want." in the display italic, with the key as a real key cap
                                Flow {
                                    Layout.fillWidth: true; spacing: 0     // Flow's spacing is also the row gap, so word gaps are padding
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: "Press Ctrl K and say what you want."
                                    Repeater {
                                        model: ["Press"]
                                        Text { required property string modelData; text: modelData; color: Theme.tx; rightPadding: 6
                                               font.family: Theme.fontDisplay; font.italic: true; font.pixelSize: 22; lineHeightMode: Text.FixedHeight; lineHeight: 25 }
                                    }
                                    Item {
                                        width: capTip.implicitWidth + 6; height: 25
                                        FEKeyCap { id: capTip; anchors.verticalCenter: parent.verticalCenter; text: "Ctrl K"; bright: true; fontSize: 12 }
                                    }
                                    Repeater {
                                        model: ["and", "say", "what", "you", "want."]
                                        Text { required property string modelData; text: modelData; color: Theme.tx; rightPadding: 6
                                               font.family: Theme.fontDisplay; font.italic: true; font.pixelSize: 22; lineHeightMode: Text.FixedHeight; lineHeight: 25 }
                                    }
                                }
                                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; lineHeightMode: Text.FixedHeight; lineHeight: 19.5     // 13px x 1.5
                                       text: "Today it searches your projects. Sentence commands — “Add a cross dissolve”, “Export for Instagram” — come with the editing engine."
                                       color: Theme.tx2; font.family: Theme.fontUI; font.pixelSize: Theme.sizeBody }
                            }
                        }
                    }
                }
            }
        }
    }
}
