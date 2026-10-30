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
Qt 6.8 (`win64_msvc2022_64`) + MSVC 2022 + CMake + Ninja, Release build, `windeployqt`, then:

1. **Set the desktop to 1920x1080** (`tools/ci/Set-DisplayResolution.ps1`). The hosted runner starts on 1024x768 and Windows will not make a window larger than the desktop, which is why earlier runs asked for 1366x768 / 1600x900 and got about 1180x749. The step fails if the desktop does not reach the requested size.
2. **Smoke test on the real `windows` platform** (Direct3D 11) with `--exact-sizes`. Gating.
3. **Smoke test on Qt's `offscreen` platform** (software renderer). Non-gating, a layout cross-check in a second renderer; its files and captions say so.
4. A run summary, and a step that prints the key real-platform frames into the job log as base64 JPEG (artifact downloads need a login; the log does not).

and uploads four artifacts:

- `FrameEase-windows-x64`: `FrameEase.exe` plus the Qt runtime (about 120 MB, unzip and run)
- `smoke-test-evidence`: the **real Windows** report (`smoke-report.txt`), `qt-messages.log` and PNGs named `windows--<view>--<WxH>.png`
- `smoke-test-evidence-offscreen`: the same from the offscreen pass, PNGs named `offscreen--<view>--<WxH>.png`
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
dist/FrameEase.exe --smoke-test --exact-sizes --out smoke-out
```

`--exact-sizes` turns a window size the platform does not grant into a failure. Without it the run continues, reports the size it really got, and files the capture under that size with `--CLAMPED-from-<requested>` in the name.

The exe is a GUI-subsystem program, so run it with `Start-Process -Wait` (as CI does) and read `smoke-out/smoke-report.txt`.
Exit code 0 means every check passed. All Qt messages are written to `smoke-out/qt-messages.log`; the PNGs are in the same folder.

The test drives the real UI. It finds controls by `objectName`, then delivers mouse and key events to the window, so hit-testing,
focus and signal wiring are exercised the way a user would. In order, it checks:

0. **Environment**: Qt version, platform, scene-graph API, screen size, and that the three bundled font families registered and are what the headline, UI text and numbers actually render in.
1. **Responsive matrix, first, while the app is in its default state**: at 1180x749, 1366x768 and 1600x900, Home (top and bottom), each of Media / Edit / Color / Audio / Text, and Export are captured. At each size: the side panel appears only above 1500 px; no named control crosses the window edge or overlaps a neighbour; the featured card's title, button and clip strip do not collide; **no visible Text is elided or wider than its box** (the audit was checked to fail at an unsupported 760 px width); "← Projects" returns Home from every workspace.
2. **Startup**: the app launches into Home, the featured card and all eight recent cards exist and contain real imagery, the checked preset has the paper selection edge **in the rendered frame**.
3. **Format presets**, **filters and search** (counts, combination, empty state, ×, Escape), **selection** (a click selects and does not open; the selected card carries the paper ring in the frame and its neighbour does not).
4. **Navigation**: featured card -> Edit; brand mark and "← Projects" -> Home; select + Open; double-click opens it; hover then the Open pill; the title follows the project; Recent re-sorts by last opened; opening a project does not relabel it "edited"; Undo / Redo are visibly unavailable.
5. **Leaving a project stops playback** in Edit, Audio and Text.
6. **Create / import (mock)**: Create adds an in-memory "Not saved" project (also marked on the featured card) and opens it; "Import media first" opens the Media placeholder; "Open from disk…" and Settings are disabled.
7. **Nothing is persisted**: no file appears under the app's data/config folders and no `QSettings` key is written.

After every step it requires that no QML warning or error was logged, and again for the whole run. The report ends with a **coverage table** saying, per requested size, how many frames were captured at exactly that size on which platform and renderer, or that the size was not captured. Every PNG has a caption strip under the image with platform, scene-graph API and the real window size (amber = offscreen, not Windows pixels; red = size not granted).

Locally on macOS or Linux you can run the same test against a desktop session: `FrameEase --smoke-test --out smoke-out`.
`QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software` also works, but that software renderer ignores scroll clipping for some vector items, so use CI or a real GPU for visual review.

**What a pass does not prove**

- Anything about drag, trim, snapping, sliders, wheels or playback inside the workspaces. Only Home and navigation are interaction-tested.
- Anything about other machines. CI renders with Direct3D 11 on the *Microsoft Basic Render Driver* (software WARP): no real GPU, no 4K, no high-DPI scaling (devicePixelRatio is 1).
- Pixel correctness. No image comparison runs in CI; screenshots are reviewed by eye. The automated checks are structural (geometry, text fit, the selection edge sampled in the frame, regions that are not flat colour).
- Keyboard shortcuts. A synthetic `QKeyEvent` bypasses Qt's shortcut map, so `Ctrl+0`, `Ctrl+K` and `Space` are not asserted (Escape and the Tab / Enter handlers are).
- Real file drops, tooltips, hover animation timing or screen-reader output. Implemented, not asserted.
- Media and Export, which are placeholders.

## Known issues

- `qmllint` reports about 145 "unqualified access" style notices (delegates reading ids and model roles from enclosing scopes). They work at runtime and are not fixed. Adding `pragma ComponentBehavior: Bound` to the affected files would clear them.
- Every project opens the same demo timeline, and edits made to it in one project are visible in every other (it is one shared singleton).
- The offscreen software renderer paints the Edit timeline's waveform shapes outside their clip and leaves them behind along the status bar after the workspace hides. That is a property of that renderer (it is why the offscreen pass is non-gating), not seen in the real-platform pass.
- Home recent cards are not arrow-key navigable (Tab moves between them). Reduced-motion is not read by the QML hover and lift animations.
- Windows CI uses a floating `6.8.*` Qt version; pin it if reproducibility matters.

## Fonts

Instrument Sans, Instrument Serif and Geist Mono (all SIL OFL 1.1, redistributable) are embedded in the executable
from `resources/fonts` and registered in `src/main.cpp` before the engine loads. Licences, provenance and the one
modification (static weights cut from the variable fonts) are in [`resources/fonts/README.md`](resources/fonts/README.md).

`Theme.fontUI / fontMono / fontDisplay` are single family names on purpose: QML's `font.family` does not accept a
CSS-style list, so the earlier `"Instrument Sans, Segoe UI Variable, ..."` strings were looked up as one non-existent family
and silently fell back to the default font. The fallback chain now lives in `main.cpp` (`QFont::insertSubstitutions`) and
is only used if a bundled font fails to load.

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
qml/components/                   FEIcon, FEIconButton, FEButton, FEChip, FESlider, FESegmented, FESection, FETag, FEKeyCap, FESearchField, FERoundClip,
                                  FEDisabledTip, FEUnavailableButton, FEUnavailableIconButton, BrandMark, CoastalScene, WorkspacePlaceholder
qml/home/                         HomeScreen, ContinueHero, ProjectCard, FormatCard, ProjectThumb, SunGlow, MockLibrary (singleton)
resources/fonts/                  bundled OFL fonts + licences
tools/                            ci/Set-DisplayResolution.ps1 (CI desktop size), make-static-fonts.py (font weights)
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
| Back to Home (from any workspace) | The FrameEase mark, the "← Projects" button, or `Ctrl+0`. Playback is stopped when you leave |

**Explicitly not real**

- Nothing is saved or loaded. Created projects disappear when the app closes.
- Every project, including a new one, opens the same demo timeline (Coastal Light). Only the name, format and "Not saved" tag in the top bar change.
- "Open from disk…", "Show in folder", "Duplicate", Settings, and the editor's Undo and Redo are visibly disabled and explain why on hover. The Quick starts panel (windows 1500 px and wider) is labelled "Needs engine" and is not interactive.
- `Ctrl+K` only searches projects. There is no command palette yet.

**Responsive:** at 1500 px and below the side panel is hidden and Recent shows three columns; above 1500 px it shows the panel and four columns (the design's `max-width: 1500px` breakpoint).

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
