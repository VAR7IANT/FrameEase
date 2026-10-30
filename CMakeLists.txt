cmake_minimum_required(VERSION 3.21)
project(FrameEase VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt 6.5+. QtQuick.Shapes / QtQuick.Effects are QML-only plugins in the Quick module (no CMake component).
find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.5)

# Theme is a QML singleton: it must be flagged *before* the module is created.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/edit/MockProject.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/home/MockLibrary.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(FrameEase WIN32 src/main.cpp)
if(APPLE)
    # Only so contributors can build on macOS: the executable would otherwise clash with the FrameEase/ QML module folder.
    set_target_properties(FrameEase PROPERTIES MACOSX_BUNDLE TRUE)
endif()

qt_add_qml_module(FrameEase
    URI FrameEase
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/components/FEIcon.qml
        qml/components/FEPlainSlider.qml
        qml/components/FEIconButton.qml
        qml/components/FEButton.qml
        qml/components/FEChip.qml
        qml/components/FESlider.qml
        qml/components/FESegmented.qml
        qml/components/FESection.qml
        qml/components/WorkspacePlaceholder.qml
        qml/components/CoastalScene.qml
        qml/components/BrandMark.qml
        qml/components/FETag.qml
        qml/components/FERoundClip.qml
        qml/components/FEDisabledTip.qml
        qml/components/FEUnavailableButton.qml
        qml/components/FEUnavailableIconButton.qml
        qml/components/FESearchField.qml
        qml/components/FEKeyCap.qml
        qml/home/HomeScreen.qml
        qml/home/MockLibrary.qml
        qml/home/ContinueHero.qml
        qml/home/ProjectCard.qml
        qml/home/ProjectThumb.qml
        qml/home/FormatCard.qml
        qml/home/SunGlow.qml
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

# Design fonts (SIL OFL, see resources/fonts/README.md), embedded so every machine renders the same typography.
# Registered at startup in src/main.cpp from :/FrameEase/fonts.
qt_add_resources(FrameEase fonts
    PREFIX "/FrameEase/fonts"
    BASE resources/fonts
    FILES
        resources/fonts/InstrumentSans-Regular.ttf
        resources/fonts/InstrumentSans-Medium.ttf
        resources/fonts/InstrumentSans-SemiBold.ttf
        resources/fonts/GeistMono-Regular.ttf
        resources/fonts/GeistMono-Medium.ttf
        resources/fonts/InstrumentSerif-Regular.ttf
        resources/fonts/InstrumentSerif-Italic.ttf
)

target_link_libraries(FrameEase PRIVATE Qt6::Quick Qt6::QuickControls2)

# Startup smoke test: loads FrameEase/Main, drives Home -> Edit -> Home and visits Edit/Color/Audio/Text, fails on any QML warning or blank frame.
# Needs a display session (a real Windows desktop or the CI runner), so it is a plain exe flag rather than a unit test.
enable_testing()
add_test(NAME startup_smoke COMMAND FrameEase --smoke-test --out ${CMAKE_BINARY_DIR}/smoke-out)

# Future integration points (not linked yet; the UI talks to MockProject only):
#   - FrameEaseCore  : C++20 editing engine (timeline model, commands, undo stack)
#   - FFmpeg         : decode / proxy / export
#   - MLT            : optional compositing & effects graph
