# FrameEase

Professional power should not require professional complexity.

This repository holds the **UI layer** of FrameEase: a visual identity, a QML component system, and the
main Edit workspace on mock data. The editing engine (C++20 core, FFmpeg, later MLT) is not part of this stage.

## Status, honestly

| Area | State |
| --- | --- |
| Design for all 7 screens (Home, Media, Edit, Color, Audio, Text, Export) | Interactive HTML prototypes in [`design/`](design) (also published as a Design canvas) |
| QML shell, design system (`Theme`, `FE*`), Edit / Color / Audio / Text workspaces | **Builds on Windows CI (Qt 6.8, MSVC 2022) and loads without QML warnings** in the smoke test below. Mock data only |
| QML Home / Media / Export | **Not ported.** Placeholders only; deliberately outside the smoke test |
| Interaction behaviour (drag, trim, snapping, sliders, wheels, playback) | **Not covered by any automated test.** Only startup, workspace switching and a non-blank render are checked |
| Editing engine, decoding, export | Not started. Nothing here touches media files |

## Build

### CI (Windows)

`.github/workflows/windows.yml` runs on every push to `main` and every pull request:
Qt 6.8 (`win64_msvc2022_64`) + MSVC 2022 + CMake + Ninja, Release build, `windeployqt`, the startup smoke test,
and uploads three artifacts:

- `FrameEase-windows-x64`: `FrameEase.exe` plus the Qt runtime (about 120 MB, unzip and run)
- `smoke-test-evidence`: `smoke-report.txt`, `qt-messages.log` and one PNG per workspace
- `qmllint-log`: informational lint output (not a gate)

### Local (Windows, Qt 6.8)

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="C:/Qt/6.8.3/msvc2022_64"
cmake --build build
windeployqt --release --no-translations --qmldir qml --dir dist build/FrameEase.exe   # copy FrameEase.exe into dist first
dist/FrameEase.exe
```

Run from a "x64 Native Tools" prompt so Ninja finds MSVC.

## Verification

```powershell
dist/FrameEase.exe --smoke-test --out smoke-out
```

The exe is a GUI-subsystem program, so run it with `Start-Process -Wait` (as CI does) and read `smoke-out/smoke-report.txt`.
The test loads `FrameEase/Main`, then for Edit, Color, Audio and Text: switches to it, waits about 0.9 s,
grabs the window (fails if the frame is blank) and fails on any QML warning or error. Exit code 0 means every check passed.
All Qt messages are written to `smoke-out/qt-messages.log`; the per-workspace PNGs are in the same folder.

**What a pass does not prove**

- Anything about interaction. No clicks, drags, keys or sliders are exercised.
- Anything about other machines. CI renders with Direct3D 11 on the *Microsoft Basic Render Driver* (software WARP) at 1180 x 749 and nothing else: no real GPU, no 4K, no high-DPI scaling, no 1366 x 768.
- Pixel correctness. The screenshots were reviewed by eye once; no image comparison runs in CI.
- Home, Media and Export, which are placeholders.

## Known issues

- `qmllint` reports about 145 "unqualified access" style notices (delegates reading ids and model roles from enclosing scopes). They work at runtime and are not fixed. Adding `pragma ComponentBehavior: Bound` to the affected files would clear them.
- In the CI screenshots the top-bar "Color" tab keeps its highlight after switching to Audio or Text, while the new tab's label turns bright. The smoke test sets `current` from C++ and then calls `grabWindow`, so this may be a harness artifact (animations paused around the grab), but it has not been reproduced or ruled out on a real desktop.
- Fonts (Instrument Sans / Serif, Geist Mono) are not bundled yet; the CI screenshots show the fallback stack.
- Windows CI uses a floating `6.8.*` Qt version; pin it if reproducibility matters.

## Fonts

Bundle Instrument Sans, Instrument Serif and Geist Mono (all OFL) and register them with
`QFontDatabase::addApplicationFont` before the engine loads. Until then `Theme` falls back to Segoe UI Variable.

## Design rationale

**Idea: the ease curve.** The product is called FrameEase, so easing is the visual motif: the logo is a frame
holding a curve that ends in a dot; the workspace tabs sit on a small curved underline; keyframes and speed
changes share one curve editor; every animation uses the same short ease-out.

**Calm, content-first colour.** The UI is a warm graphite ramp so video is always the brightest thing on
screen. There is exactly one accent, vermilion, reserved for "now": the playhead, the live position in the
story map, and the single primary action per screen. Selection and focus use paper-cream, so they never
compete with the accent. Clip families differ in lightness as well as hue.

**Type.** Instrument Sans for UI, Geist Mono for every number that has to line up (timecode, dB, bitrates),
Instrument Serif italic for moments of voice: titles, empty states, big headings.

**Ideas that change the work, not just the look**

- *Story map*: a strip above the timeline shows the whole film as chapters; click or drag to jump through long projects.
- *Contextual strip*: the timeline toolbar centre morphs into actions for the selected clip, so permanent toolbars stay small.
- *Simple / Pro inspector*: the same panel at two depths. Sections collapse independently.
- *Snapping you can see*: a paper-coloured guide appears at the exact point a clip snaps to.
- *Color by disclosure*: Looks and 8 sliders first; Wheels, Curves and Secondary one tab away; a before/after wipe and live scopes stay on screen.
- *Audio assistant*: "Sound check" lists problems with one-click, non-destructive fixes instead of asking users to find plug-ins.
- *Destinations before settings* in Export: pick YouTube / Reel / Master, then open Fine-tune only if needed. Live size and time estimates.

**Responsive.** Side panes step down at 1560 and 1380 px so the monitor keeps room at 1366×768; the monitor
frame is always the largest 16:9 that fits; the timeline height follows the window.

**Accessibility.** Every interactive control is focusable with a visible paper ring, has an accessible name,
and tooltips list shortcuts. Text meets 4.5:1 (lowest grey is 5.2:1 on panels). Motion is short and honours reduced-motion in the prototypes.

## Layout

```
CMakeLists.txt
src/main.cpp                      engine bootstrap (Basic style, loads module FrameEase/Main)
qml/Theme.qml                     design tokens (singleton)
qml/Main.qml                      window shell: top bar, workspace pager, Ctrl+1..5
qml/components/                   FEIcon, FEIconButton, FEButton, FEChip, FESlider, FESegmented, FESection, CoastalScene, WorkspacePlaceholder
qml/color/                        ColorWorkspace, ColorWheel, ParadeScope
qml/audio/                        AudioWorkspace, ChannelStrip, FEFader, LevelMeter
qml/text/                         TextWorkspace
qml/edit/                         EditWorkspace, Library, Monitor, Inspector, Timeline, TimelineClip, MockProject (singleton)
design/*.dc.html                  interactive prototypes of all seven screens
```

## Working UI behaviour (on mock data)

Timeline: select, drag to move, trim by edge, blade tool, split at playhead (S), delete with optional ripple,
snapping to clip edges / playhead, zoom and fit, scrub on ruler and story map, playback with live monitor.
Monitor: follows the cut, shows the V3 title, safe zones. Inspector: Simple/Pro, collapsible sections, sliders with keyframe toggles.

## Integration seam

`MockProject` exposes `clips` (a `ListModel` with roles `cid, track, start, dur, src, name, kind, pal`), `tracks`,
`media`, `clipAt()` and `timecode()`. Replace it with a C++ `QAbstractListModel` singleton exposing the same roles
and the QML does not change. Edits should become commands (`MoveClip`, `TrimClip`, `SplitClip`, `DeleteClip`) on the
engine's undo stack instead of `setProperty` calls inside `Timeline.qml`.

## Known limitations

- No undo/redo, no cross-track clip moves, no multi-select or marquee, no transitions editing; clip overlap is prevented by clamping.
- Keyframes, ease curve, colour sliders in the Inspector are visual state only.
- Waveforms and thumbnails are procedural. No media is decoded.
- Custom frameless window chrome is not implemented; the native Windows frame is used.
- 4K / high-DPI: layout is in device-independent pixels; icons are vector. Not yet tested on a real display.
