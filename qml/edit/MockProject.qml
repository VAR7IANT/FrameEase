pragma Singleton
import QtQuick

// UI-level mock state. Everything in here is a stand-in for the C++ editing core
// (a QAbstractListModel exposing the same roles) so the QML never changes when the engine lands.
QtObject {
    readonly property real total: 144       // seconds
    readonly property int fps: 24

    readonly property var tracks: [
        { id: "V3", name: "Titles",   h: 34, kind: "title",    color: "#E3CFA8", video: true  },
        { id: "V2", name: "B-roll",   h: 52, kind: "broll",    color: "#7FA6C9", video: true  },
        { id: "V1", name: "Main",     h: 64, kind: "main",     color: "#5FB3BC", video: true  },
        { id: "A1", name: "Dialogue", h: 48, kind: "dialogue", color: "#7FC08F", video: false },
        { id: "A2", name: "Music",    h: 48, kind: "music",    color: "#B795D0", video: false },
        { id: "A3", name: "Sound FX", h: 34, kind: "sfx",      color: "#D6AE5E", video: false }
    ]

    // Sky/sea palettes shared by the preview, thumbnails and clip filmstrips.
    readonly property var pal: ({
        sun:   { top: "#26365e", mid: "#d98c7a", hor: "#ffc58a", s1: "#6b86a0", s2: "#142230", sun: "#fff1d0" },
        harb:  { top: "#5d8fb3", mid: "#a9c8d6", hor: "#efe3cc", s1: "#4a7c8a", s2: "#14303a", sun: "#fffbea" },
        fish:  { top: "#3a4b52", mid: "#7e8f86", hor: "#d9c9a0", s1: "#5f6f66", s2: "#1d2a28", sun: "#f3e2b5" },
        cliff: { top: "#2f6f9f", mid: "#7fb5d0", hor: "#e8f0e8", s1: "#2f7e8c", s2: "#0d3340", sun: "#ffffff" },
        dusk:  { top: "#1b1740", mid: "#7a3a72", hor: "#ff8a5c", s1: "#5a3a6a", s2: "#120c24", sun: "#ffd7a0" },
        coda:  { top: "#0f1217", mid: "#1a2230", hor: "#2b3a4d", s1: "#1f2c3a", s2: "#080b10", sun: "#6c86a6" }
    })

    property ListModel clips: ListModel {
        ListElement { cid: "t1"; track: "V3"; start: 2;   dur: 7;   src: 0; name: "Coastal Light";                kind: "title";    pal: "" }
        ListElement { cid: "t2"; track: "V3"; start: 31;  dur: 7;   src: 0; name: "Mara Ellison · Fisher & guide"; kind: "title";    pal: "" }
        ListElement { cid: "t3"; track: "V3"; start: 62;  dur: 6;   src: 0; name: "The Cliffs · Chapter 02";      kind: "title";    pal: "" }
        ListElement { cid: "t4"; track: "V3"; start: 122; dur: 14;  src: 0; name: "Fin";                          kind: "title";    pal: "" }
        ListElement { cid: "b1"; track: "V2"; start: 14;  dur: 8;   src: 0; name: "Gulls_over_pier";             kind: "broll";    pal: "harb" }
        ListElement { cid: "b2"; track: "V2"; start: 40;  dur: 7;   src: 0; name: "Waves_macro";                 kind: "broll";    pal: "cliff" }
        ListElement { cid: "b3"; track: "V2"; start: 70;  dur: 9;   src: 0; name: "Net_detail";                  kind: "broll";    pal: "fish" }
        ListElement { cid: "b4"; track: "V2"; start: 92;  dur: 10;  src: 0; name: "Boat_wake";                   kind: "broll";    pal: "dusk" }
        ListElement { cid: "b5"; track: "V2"; start: 108; dur: 9;   src: 0; name: "Lighthouse_blue";             kind: "broll";    pal: "coda" }
        ListElement { cid: "m1"; track: "V1"; start: 0;   dur: 16;  src: 0; name: "Sunrise_Drone_04";            kind: "main";     pal: "sun" }
        ListElement { cid: "m2"; track: "V1"; start: 16;  dur: 22;  src: 0; name: "Harbour_Walk";               kind: "main";     pal: "harb" }
        ListElement { cid: "m3"; track: "V1"; start: 38;  dur: 23;  src: 0; name: "Fishermen_Cu";               kind: "main";     pal: "fish" }
        ListElement { cid: "m4"; track: "V1"; start: 61;  dur: 27;  src: 0; name: "Cliffs_Wide";                kind: "main";     pal: "cliff" }
        ListElement { cid: "m5"; track: "V1"; start: 88;  dur: 32;  src: 0; name: "Dusk_Timelapse";            kind: "main";     pal: "dusk" }
        ListElement { cid: "m6"; track: "V1"; start: 120; dur: 24;  src: 0; name: "Night_Harbour_BG";           kind: "main";     pal: "coda" }
        ListElement { cid: "d1"; track: "A1"; start: 16;  dur: 45;  src: 0; name: "Mara_Interview_A";           kind: "dialogue"; pal: "" }
        ListElement { cid: "d2"; track: "A1"; start: 118; dur: 22;  src: 0; name: "VO_Outro_take3";             kind: "dialogue"; pal: "" }
        ListElement { cid: "u1"; track: "A2"; start: 0;   dur: 144; src: 0; name: "Tidal_Score_v2";             kind: "music";    pal: "" }
        ListElement { cid: "x1"; track: "A3"; start: 14;  dur: 7;   src: 0; name: "Gulls_amb";                  kind: "sfx";      pal: "" }
        ListElement { cid: "x2"; track: "A3"; start: 40;  dur: 7;   src: 0; name: "Wave_hits";                  kind: "sfx";      pal: "" }
        ListElement { cid: "x3"; track: "A3"; start: 92;  dur: 9;   src: 0; name: "Wake_whoosh";                kind: "sfx";      pal: "" }
    }

    readonly property var media: [
        { n: "Sunrise_Drone_04", d: "0:16", pal: "sun",   sx: 0.72, used: true  },
        { n: "Harbour_Walk",     d: "0:22", pal: "harb",  sx: 0.30, used: true  },
        { n: "Fishermen_Cu",     d: "0:23", pal: "fish",  sx: 0.55, used: true  },
        { n: "Cliffs_Wide",      d: "0:27", pal: "cliff", sx: 0.22, used: true  },
        { n: "Dusk_Timelapse",   d: "0:32", pal: "dusk",  sx: 0.64, used: true  },
        { n: "Gulls_over_pier",  d: "0:08", pal: "harb",  sx: 0.80, used: true  },
        { n: "Waves_macro",      d: "0:12", pal: "cliff", sx: 0.45, used: true  },
        { n: "Lighthouse_blue",  d: "0:19", pal: "coda",  sx: 0.36, used: false },
        { n: "Kelp_underwater",  d: "0:14", pal: "fish",  sx: 0.50, used: false }
    ]

    function trackById(id) {
        for (let i = 0; i < tracks.length; i++) if (tracks[i].id === id) return tracks[i]
        return null
    }

    function timecode(t) {
        const f = Math.floor(t * fps + 1e-6), s = Math.floor(f / fps)
        const p = (n) => (n < 10 ? "0" : "") + n
        return p(Math.floor(s / 3600)) + ":" + p(Math.floor(s / 60) % 60) + ":" + p(s % 60) + ":" + p(f % fps)
    }

    // The clip on `trackId` under time `t`, or null.
    function clipAt(trackId, t) {
        for (let i = 0; i < clips.count; i++) {
            const c = clips.get(i)
            if (c.track === trackId && t >= c.start && t < c.start + c.dur) return c
        }
        return null
    }
}
