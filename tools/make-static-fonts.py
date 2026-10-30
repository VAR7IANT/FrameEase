#!/usr/bin/env python3
"""Regenerates the static weights in resources/fonts from the upstream variable fonts.

Qt only registers the default instance of a variable font on some platforms, so Medium / SemiBold would be
synthesised. Static instances register as real weights everywhere.

    pip install fonttools
    python tools/make-static-fonts.py "InstrumentSans[wdth,wght].ttf" "GeistMono[wght].ttf" resources/fonts

Sources (SIL OFL 1.1, no Reserved Font Names declared):
    https://github.com/google/fonts/tree/main/ofl/instrumentsans   InstrumentSans[wdth,wght].ttf
    https://github.com/google/fonts/tree/main/ofl/geistmono        GeistMono[wght].ttf
Instrument Serif is used unmodified (InstrumentSerif-Regular.ttf, InstrumentSerif-Italic.ttf).
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

sans, mono, out = sys.argv[1], sys.argv[2], sys.argv[3]
jobs = [(sans, "InstrumentSans", {"wdth": 100, "wght": w}, n) for w, n in [(400, "Regular"), (500, "Medium"), (600, "SemiBold")]]
jobs += [(mono, "GeistMono", {"wght": w}, n) for w, n in [(400, "Regular"), (500, "Medium")]]
for src, fam, loc, style in jobs:
    font = instancer.instantiateVariableFont(TTFont(src), loc, updateFontNames=True)
    font.save(f"{out}/{fam}-{style}.ttf")
    print(f"{fam}-{style}.ttf  wght={loc['wght']}")
