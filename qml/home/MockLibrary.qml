pragma Singleton
import QtQuick

// MOCK project library for the Home screen. Nothing here touches the disk:
//  - the eight projects below are hard-coded sample data,
//  - "creating" a project only adds an entry to this in-memory list for the current session,
//  - opening a project only reorders the list ("last opened") and always shows the same demo timeline
//    (edits made to it in one project are visible in every other, because the demo timeline is one shared singleton).
// When the project format and C++ core land, this singleton is replaced by a QAbstractListModel
// with the same roles, so HomeScreen does not change.
QtObject {
    id: lib

    readonly property var formats: [
        { k: "wide", name: "Widescreen", meta: "16:9 · 1920×1080",  w: 44, h: 25, short: "widescreen", spec: "1080p · 24p",       kind: "Film"  },
        { k: "tall", name: "Vertical",   meta: "9:16 · 1080×1920",  w: 22, h: 40, short: "vertical",   spec: "1080×1920 · 30p",   kind: "Short" },
        { k: "sq",   name: "Square",     meta: "1:1 · 1080×1080",   w: 34, h: 34, short: "square",     spec: "1080×1080 · 30p",   kind: "Short" },
        { k: "cine", name: "Cinema",     meta: "2.39:1 · 4096×1716", w: 48, h: 20, short: "cinema",     spec: "4096×1716 · 24p",   kind: "Film"  }
    ]

    // Most recently opened first. `segments` are relative clip lengths for the featured strip.
    property var projects: [
        { id: "coastal",  name: "Coastal Light",       kind: "Film",  shared: false, dur: "2:24",  pal: "sun",   sx: 72, spec: "4K · 24p",        edited: "2 min ago",  version: "v3",
          resume: "Playhead at 0:05 · Title selected", segments: [16, 22, 23, 27, 32, 24], unsaved: false },
        { id: "market",   name: "Market Day — cut 2",  kind: "Film",  shared: true,  dur: "6:10",  pal: "fish",  sx: 30, spec: "1080p · 25p",     edited: "Yesterday",  version: "v2",
          resume: "Playhead at 1:42 · Cut selected",   segments: [12, 30, 18, 26, 14],     unsaved: false },
        { id: "studio",   name: "Studio tour",         kind: "Short", shared: false, dur: "0:48",  pal: "harb",  sx: 60, spec: "1080×1920 · 30p", edited: "Yesterday",  version: "v1",
          resume: "Playhead at 0:12 · Caption selected", segments: [20, 25, 30, 25],         unsaved: false },
        { id: "rain",     name: "Rain walk",           kind: "Film",  shared: false, dur: "3:05",  pal: "cliff", sx: 20, spec: "4K · 24p",        edited: "Mon",        version: "v4",
          resume: "Playhead at 2:18 · Colour pass",    segments: [24, 18, 30, 28],         unsaved: false },
        { id: "teaser",   name: "Product teaser v5",   kind: "Short", shared: true,  dur: "0:30",  pal: "dusk",  sx: 50, spec: "1080p · 30p",     edited: "Mon",        version: "v5",
          resume: "Playhead at 0:21 · Audio mix",     segments: [18, 22, 26, 34],         unsaved: false },
        { id: "mara",     name: "Mara interview",      kind: "Film",  shared: false, dur: "18:42", pal: "coda",  sx: 80, spec: "4K · 24p",        edited: "3 days ago", version: "v2",
          resume: "Playhead at 9:30 · Subtitles",     segments: [30, 28, 26, 16],         unsaved: false },
        { id: "night",    name: "Night drive",         kind: "Short", shared: false, dur: "1:12",  pal: "dusk",  sx: 25, spec: "1080p · 24p",     edited: "Last week",  version: "v1",
          resume: "Playhead at 0:40 · Clip selected",  segments: [22, 26, 24, 28],         unsaved: false },
        { id: "birthday", name: "Birthday reel",       kind: "Short", shared: false, dur: "2:02",  pal: "harb",  sx: 40, spec: "1080p · 30p",     edited: "Last week",  version: "v1",
          resume: "Playhead at 1:05 · Music selected", segments: [26, 20, 28, 26],         unsaved: false }
    ]

    property int createdCount: 0

    function byId(id) {
        for (let i = 0; i < projects.length; ++i)
            if (projects[i].id === id) return projects[i]
        return null
    }

    function format(key) {
        for (let i = 0; i < formats.length; ++i)
            if (formats[i].k === key) return formats[i]
        return formats[0]
    }

    // "Last opened" bookkeeping only: moves the project to the front. Opening is not editing, so `edited` is left alone.
    function touch(id) {
        const p = byId(id)
        if (!p) return
        projects = [p].concat(projects.filter(q => q.id !== id))
    }

    // Adds an in-memory, unsaved entry and returns its id.
    function create(formatKey) {
        const f = format(formatKey)
        createdCount += 1
        const id = "new" + createdCount
        const p = { id: id, name: "Untitled " + createdCount, kind: f.kind, shared: false, dur: "0:00", pal: "coda", sx: 50,
                    spec: f.spec, edited: "Just now", version: "v1", resume: "Empty project · " + f.short + " · not saved",
                    segments: [], unsaved: true }
        projects = [p].concat(projects)
        return id
    }

    readonly property var quickStarts: [
        { name: "Cut to the beat",           meta: "Drop a track — we place markers on every downbeat.",  d: "M3 12h2l2-7 3 14 3-10 2 3h6",                                       c1: "#6C4C7F", c2: "#3a2748" },
        { name: "Auto-subtitle an interview", meta: "Speech to editable captions, synced to the timeline.", d: "M4 7h16M4 12h10M4 17h13",                                           c1: "#3F6D52", c2: "#25402f" },
        { name: "Vertical from widescreen",   meta: "Reframe 16:9 footage with subject tracking.",          d: "M8 3h8v18H8z",                                                      c1: "#2e6670", c2: "#173a40" },
        { name: "Look from a reference",      meta: "Match the colour of a still or another clip.",         d: "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z",       c1: "#a06a3a", c2: "#58361b" }
    ]

    readonly property var keys: [
        { key: "Space", what: "Play / pause" },
        { key: "S",     what: "Split at the playhead" },
        { key: "B",     what: "Blade tool" },
        { key: "N",     what: "Toggle snapping" },
        { key: "Ctrl K", what: "Search projects (here on Home)" }
    ]
}
