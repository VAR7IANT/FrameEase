# FrameEase

Professional power should not require professional complexity.

This repository holds the **UI layer** of FrameEase: a visual identity, a QML component system, and the
Home launch screen and the Edit, Color, Audio and Text workspaces, all on mock data. The editing engine (C++20 core, FFmpeg, later MLT) is not part of this stage.

## Status, honestly

| Area | State |
| --- | --- |
| Design for all 7 screens (Home, Media, Edit, Color, Audio, Text, Export) | Interactive HTML prototypes in [`design/`](design) (also published as a Design canvas) |
| QML shell, design system (`Theme`, `FE*`), Home, Edit / Color / Audio / Text workspaces | **Builds on Windows CI (Qt 6.8, MSVC 2022) and loads without QML warnings** in the smoke test below. Mock data only |
| QML Media / Export | **Not ported.** Placeholders only; deliberately outside the smoke test |
| Home interactions (presets, search, filters, selection, open, create, return Home) | Driven through real input events by the smoke test, see [Home](#home) |
| Other interaction behaviour (drag, trim, snapping, sliders, wheels, playback) | **Not covered by any automated test.** Only startup, workspace switching and a non-blank render are checked |
| Project files, editing engine, decoding, export | Not started. Nothing here reads or writes media or project files |

## Build

### CI (Windows)

`.github/workflows/windows.yml` runs on every push to `main` and every pull request:
Qt 6.8 (`win64_msvc2022_64`) + MSVC 2022 + CMake + Ninja, Release build, `windeployqt`, the startup smoke test,
and uploads three artifacts:

- `FrameEase-windows-x64`: `FrameEase.exe` plus the Qt runtime (about 120 MB, unzip and run)
- `smoke-test-evidence`: `smoke-report.txt`, `qt-messages.log` and the screenshots the test takes (Home flows, each workspace, and Home / Edit at 1180x749, 1366x768 and 1600x900)
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
Exit code 0 means every check passed. All Qt messages are written to `smoke-out/qt-messages.log`; the PNGs are in the same folder.

The test drives the real UI. It finds controls by `objectName`, then delivers mouse and key events to the window, so hit-testing,
focus and signal wiring are exercised the way a user would. In order, it checks:

1. **Startup**: the root object loads, the window is visible, the app launches into Home, the featured card and all eight recent cards exist, and the featured card and thumbnails contain real imagery (not a flat fill).
2. **Format presets**: selecting one updates the create button.
3. **Filters and search**: Films / Shorts / Shared / All counts; typing narrows the grid; search plus filter combine; the empty state and its "Clear" button; the × button; Escape.
4. **Selection**: a click selects (and does not open); selecting moves; filtering the selected card away clears it.
5. **Navigation**: featured card -> Edit; the brand mark and "← Projects" -> Home; select + Open; double-click; hover then the Open pill; the window title follows the project; Recent re-sorts by last opened.
6. **Create / import (mock)**: Create adds an in-memory "Not saved" project and opens it; "Import media first" opens the Media placeholder; "Open from disk…" is disabled.
7. **Workspaces through the tab bar**: Edit, Color, Audio, Text each reached by clicking its tab, rendered, with Home not showing through.
8. **Responsive captures**: Home (top and scrolled to the bottom) and Edit at 1180x749, 1366x768 and 1600x900, plus a geometry audit of the named Home controls (none crosses the window edge, none overlaps its neighbour) and the side-panel breakpoint (1500 px).

After every step it requires that no QML warning or error was logged, and again for the whole run.
If the platform refuses a requested window size, the report says so (`INFO`) and the captures use the size actually obtained.

Locally on macOS or Linux you can run the same test against a desktop session: `FrameEase --smoke-test --out smoke-out`.
`QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software` also works, but that software renderer ignores scroll clipping for some vector items, so use CI or a real GPU for visual review.

**What a pass does not prove**

- Anything about drag, trim, snapping, sliders, wheels or playback in the workspaces. Only Home is interaction-tested.
- Anything about other machines. CI renders with Direct3D 11 on the *Microsoft Basic Render Driver* (software WARP): no real GPU, no 4K, no high-DPI scaling. Window sizes larger than the runner's display may be clamped.
- Pixel correctness or typography. Screenshots are reviewed by eye; no image comparison runs in CI. The geometry audit only catches overflow and overlap of the named controls.
- Real file drops, tooltips, hover animation timing or screen-reader output. Those are implemented but not asserted.
- Media and Export, which are placeholders.

## Known issues

- `qmllint` reports about 145 "unqualified access" style notices (delegates reading ids and model roles from enclosing scopes). They work at runtime and are not fixed. Adding `pragma ComponentBehavior: Bound` to the affected files would clear them.
- In the CI screenshots the top-bar "Color" tab keeps its highlight after switching to Audio or Text, while the new tab's label turns bright. The smoke test sets `current` from C++ and then calls `grabWindow`, so this may be a harness artifact (animations paused around the grab), but it has not been reproduced or ruled out on a real desktop.
- Fonts (Instrument Sans / Serif, Geist Mono) are not bundled yet; the CI screenshots show the fallback stack. The Home headline is set in a serif fallback, so its line breaks may differ from the design.
- Home recent cards are not arrow-key navigable (Tab moves between them). Reduced-motion is not read by the QML hover and lift animations.
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
qml/Main.qml                      window shell: Home / editor pages, top bar, workspace pager, Ctrl+0 (Home), Ctrl+1..5
qml/components/                   FEIcon, FEIconButton, FEButton, FEChip, FESlider, FESegmented, FESection, FETag, FESearchField, FERoundClip,
                                  FEDisabledTip, FEUnavailableButton, BrandMark, CoastalScene, WorkspacePlaceholder
qml/home/                         HomeScreen, ContinueHero, ProjectCard, FormatCard, ProjectThumb, MockLibrary (singleton)
qml/color/                        ColorWorkspace, ColorWheel, ParadeScope
qml/audio/                        AudioWorkspace, ChannelStrip, FEFader, LevelMeter
qml/text/                         TextWorkspace
qml/edit/                         EditWorkspace, Library, Monitor, Inspector, Timeline, TimelineClip, MockProject (singleton)
design/*.dc.html                  interactive prototypes of all seven screens
```

## Home

Home is the launch dashboard, not a workspace: while it is showing it owns the whole window, and the editor top bar is hidden.
The app starts on Home. All data comes from `qml/home/MockLibrary.qml`, eight hard-coded sample projects held in memory.

| Control | What it does today |
| --- | --- |
| Featured "Continue editing" | Opens the most recently opened project in Edit |
| Recent grid | Click or Space selects (paper ring and check badge); double-click, Enter, the hover "Open" pill, or "Open" in the selection bar opens it in Edit. Opening moves the project to the front ("Sorted by last opened") |
| Search (`Ctrl+K` / `Ctrl+F`) | Filters Recent by name, kind or format. × and Escape clear it. An empty result shows a message and a "Clear search and filters" button |
| Films / Shorts / Shared | Filters Recent. They combine with search |
| Format presets | Pick the shape of the next mock project |
| "Create ... project" | Adds an in-memory **"Not saved"** project for this session and opens it in Edit |
| "Import media first" | Starts a mock project in the **Media placeholder**. No file is imported |
| Drop zone | Accepts a drop so it is discoverable, then says that importing is not built and that nothing was read |
| Back to Home (from any workspace) | The FrameEase mark, the "← Projects" button, or `Ctrl+0` |

**Explicitly not real**

- Nothing is saved or loaded. Created projects disappear when the app closes.
- Every project, including a new one, opens the same demo timeline (Coastal Light). Only the name, format and "Not saved" tag in the top bar change.
- "Open from disk…", "Show in folder", "Duplicate" and Settings are visibly disabled and explain why on hover. The Quick starts panel (windows 1500 px and wider) is labelled "Needs engine" and is not interactive.
- `Ctrl+K` only searches projects. There is no command palette yet.

**Responsive:** below 1500 px the side panel is hidden and Recent shows three columns; at 1500 px and wider it shows the panel and four columns.

**Integration seam:** replace `MockLibrary` with a C++ model that exposes the same fields (`id, name, kind, shared, dur, pal, sx, spec, edited, version, resume, segments, unsaved`) and the same `touch()` / `create()` calls; `HomeScreen` does not change.

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
