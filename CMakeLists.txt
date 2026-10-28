cmake_minimum_required(VERSION 3.21)
project(FrameEase VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt 6.5+ is required (MultiEffect lives in QtQuick.Effects, part of the Quick module).
find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Shapes)
qt_standard_project_setup(REQUIRES 6.5)

# Theme is a QML singleton: it must be flagged *before* the module is created.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/edit/MockProject.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(FrameEase WIN32 src/main.cpp)

qt_add_qml_module(FrameEase
    URI FrameEase
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/components/FEIcon.qml
        qml/components/FEIconButton.qml
        qml/components/FEButton.qml
        qml/components/FEChip.qml
        qml/components/FESlider.qml
        qml/components/FESegmented.qml
        qml/components/FESection.qml
        qml/components/WorkspacePlaceholder.qml
        qml/components/CoastalScene.qml
        qml/color/ColorWorkspace.qml
        qml/color/ColorWheel.qml
        qml/color/ParadeScope.qml
        qml/audio/AudioWorkspace.qml
        qml/audio/ChannelStrip.qml
        qml/audio/FEFader.qml
        qml/audio/LevelMeter.qml
        qml/text/TextWorkspace.qml
        qml/edit/EditWorkspace.qml
        qml/edit/MockProject.qml
        qml/edit/Library.qml
        qml/edit/Monitor.qml
        qml/edit/Inspector.qml
        qml/edit/Timeline.qml
        qml/edit/TimelineClip.qml
)

target_link_libraries(FrameEase PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Shapes)

# Future integration points (not linked yet; the UI talks to MockProject only):
#   - FrameEaseCore  : C++20 editing engine (timeline model, commands, undo stack)
#   - FFmpeg         : decode / proxy / export
#   - MLT            : optional compositing & effects graph
