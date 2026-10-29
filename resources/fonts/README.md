# Bundled fonts

FrameEase ships the three typefaces of its design so the UI looks the same on every machine.
All three are licensed under the **SIL Open Font License 1.1**, which allows bundling and redistribution
with software, including commercial software, provided the copyright notice and licence travel with the fonts.
They do (`OFL-*.txt` in this folder). None of them declares a Reserved Font Name.

| Font | Used for | Files | Licence |
| --- | --- | --- | --- |
| Instrument Sans | UI text | `InstrumentSans-Regular / Medium / SemiBold.ttf` | `OFL-InstrumentSans.txt` |
| Geist Mono | timecode, numbers, key caps | `GeistMono-Regular / Medium.ttf` | `OFL-GeistMono.txt` |
| Instrument Serif | headings, empty states (regular + italic) | `InstrumentSerif-Regular / Italic.ttf` | `OFL-InstrumentSerif.txt` |

## Provenance and the one modification

The files come from the Google Fonts repository (`ofl/instrumentsans`, `ofl/geistmono`, `ofl/instrumentserif`).
Instrument Serif is unmodified. Instrument Sans and Geist Mono are published there as *variable* fonts only; Qt
registers just the default instance of a variable font on some platforms and would fake Medium and SemiBold, so
the weights the UI uses were exported as **static instances** with `fontTools.varLib.instancer`
(`tools/make-static-fonts.py`, Instrument Sans at width 100). Outlines are not edited. That is a Modified
Version under the OFL: it keeps the original family names, which is allowed because no Reserved Font Name is
declared, and the licence text is included unchanged.

## How they are loaded

`CMakeLists.txt` embeds this folder in the executable under `:/FrameEase/fonts`, and `src/main.cpp` registers every
file with `QFontDatabase::addApplicationFont` before the QML engine starts, so `Theme.fontUI / fontMono /
fontDisplay` resolve to them first. The smoke test checks that all three families registered. If a font fails to
load, the fallback stack in `Theme.qml` (Segoe UI Variable, Cascadia Mono, Georgia) is used.
