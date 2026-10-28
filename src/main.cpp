#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSet>
#include <QTextStream>
#include <QTimer>

#include <mutex>

namespace {

// ---- smoke-test plumbing -------------------------------------------------------------------
// In --smoke-test mode every Qt message is appended to a log file (the Windows build is a GUI-subsystem
// exe, so stdout is not available to CI) and QML warnings/errors are collected as failures.
QFile g_log;
std::mutex g_logMutex;
QStringList g_qmlProblems;

void messageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg)
{
    const char *level = type == QtDebugMsg ? "debug" : type == QtInfoMsg ? "info"
                      : type == QtWarningMsg ? "warning" : type == QtCriticalMsg ? "critical" : "fatal";
    std::lock_guard<std::mutex> lock(g_logMutex);
    if (g_log.isOpen()) {
        QTextStream(&g_log) << "[" << level << "] " << msg << "\n";
        g_log.flush();
    }
    const bool fromQml = msg.contains(QStringLiteral(".qml")) || (ctx.category && QByteArray(ctx.category).startsWith("qml"));
    if (fromQml && type != QtDebugMsg && type != QtInfoMsg)
        g_qmlProblems << msg;
}

void wait(int ms)
{
    QEventLoop loop;
    QTimer::singleShot(ms, &loop, &QEventLoop::quit);
    loop.exec();
}

// A frame that is one flat colour means nothing was drawn (or the scene graph failed silently).
bool looksRendered(const QImage &img)
{
    if (img.isNull() || img.width() < 100 || img.height() < 100)
        return false;
    QSet<QRgb> colours;
    for (int y = 0; y < img.height(); y += 17)
        for (int x = 0; x < img.width(); x += 17)
            colours.insert(img.pixel(x, y));
    return colours.size() > 12;
}

// ---- scene-graph helpers: drive the real UI, not properties -------------------------------------
// Items are found by objectName in the visual tree, and clicks/keys are delivered to the window as
// input events, so the test exercises hit-testing, focus and signal wiring the way a user would.

QQuickItem *findItem(QQuickItem *root, const QString &name)
{
    if (!root)
        return nullptr;
    if (root->objectName() == name && root->isVisible() && root->width() > 0 && root->height() > 0)
        return root;
    for (QQuickItem *c : root->childItems())
        if (QQuickItem *f = findItem(c, name))
            return f;
    return nullptr;
}

// Visible items named "<prefix><something>" with no further '.' (so "projectCard.rain" but not "projectCard.rain.open").
void collectItems(QQuickItem *root, const QString &prefix, QList<QQuickItem *> &out)
{
    if (root->isVisible() && root->objectName().startsWith(prefix) && !root->objectName().mid(prefix.size()).contains('.'))
        out << root;
    for (QQuickItem *c : root->childItems())
        collectItems(c, prefix, out);
}

QRectF sceneRect(QQuickItem *it) { return QRectF(it->mapToScene(QPointF(0, 0)), QSizeF(it->width(), it->height())); }

// Does this region of the frame contain real imagery rather than one flat colour?
bool regionVaries(const QImage &img, QRectF r)
{
    const qreal dpr = img.devicePixelRatio();
    const QRect px = QRectF(r.x() * dpr, r.y() * dpr, r.width() * dpr, r.height() * dpr).toRect().intersected(img.rect());
    if (px.width() < 8 || px.height() < 8)
        return false;
    QSet<QRgb> colours;
    for (int y = px.top(); y < px.bottom(); y += 5)
        for (int x = px.left(); x < px.right(); x += 5)
            colours.insert(img.pixel(x, y));
    return colours.size() > 20;
}

class Smoke
{
public:
    Smoke(QQuickWindow *w, const QString &out, QTextStream &r) : win(w), outDir(out), report(r) {}
    int failures = 0;

    void check(bool ok, const QString &what)
    {
        report << (ok ? "PASS  " : "FAIL  ") << what << "\n";
        if (!ok) ++failures;
    }
    void info(const QString &what) { report << "INFO  " << what << "\n"; }
    void section(const QString &title) { report << "\n-- " << title << " --\n"; }

    // Runs `body` and requires that it logged no QML warning or error.
    template <typename F> void step(const QString &name, F body)
    {
        const int before = g_qmlProblems.size();
        body();
        check(g_qmlProblems.size() == before, name + ": no QML warnings/errors");
        for (int i = before; i < g_qmlProblems.size(); ++i)
            report << "      qml: " << g_qmlProblems.at(i) << "\n";
    }

    QQuickItem *find(const QString &name) { return findItem(win->contentItem(), name); }
    QVariant prop(const QString &item, const char *p) { QQuickItem *it = find(item); return it ? it->property(p) : QVariant(); }
    bool winBool(const char *p) { return win->property(p).toBool(); }
    QString winStr(const char *p) { return win->property(p).toString(); }
    int winInt(const char *p) { return win->property(p).toInt(); }

    int countCards()
    {
        QList<QQuickItem *> cards;
        collectItems(win->contentItem(), QStringLiteral("projectCard."), cards);
        return cards.size();
    }
    QStringList cardIds()
    {
        QList<QQuickItem *> cards;
        collectItems(win->contentItem(), QStringLiteral("projectCard."), cards);
        QStringList ids;
        for (auto *c : cards) ids << c->objectName().mid(QStringLiteral("projectCard.").size());
        return ids;
    }
    QStringList selectedCardIds()
    {
        QList<QQuickItem *> cards;
        collectItems(win->contentItem(), QStringLiteral("projectCard."), cards);
        QStringList ids;
        for (auto *c : cards) if (c->property("selected").toBool()) ids << c->objectName().mid(QStringLiteral("projectCard.").size());
        return ids;
    }

    void settle(int ms = 250) { wait(ms); }

    // Scroll the Home page so `it` is on screen.
    void reveal(QQuickItem *it)
    {
        QQuickItem *flick = nullptr;
        for (QQuickItem *p = it->parentItem(); p; p = p->parentItem())
            if (p->objectName() == QLatin1String("homeScroll")) { flick = p; break; }
        if (!flick)
            return;
        const QRectF r = sceneRect(it), v = sceneRect(flick);
        if (r.top() >= v.top() && r.bottom() <= v.bottom())
            return;
        auto *content = flick->property("contentItem").value<QQuickItem *>();
        const qreal y = it->mapToItem(content, QPointF(0, 0)).y() - 90;
        const qreal maxY = qMax<qreal>(0, flick->property("contentHeight").toReal() - flick->height());
        flick->setProperty("contentY", qBound<qreal>(0, y, maxY));
        wait(150);
    }

    void mouse(QEvent::Type t, QPointF p, Qt::MouseButton b)
    {
        QMouseEvent e(t, p, win->mapToGlobal(p), b, t == QEvent::MouseButtonRelease || t == QEvent::MouseMove ? Qt::NoButton : b, Qt::NoModifier);
        QCoreApplication::sendEvent(win, &e);
    }
    void hover(const QString &name)
    {
        if (QQuickItem *it = find(name)) {
            reveal(it);
            mouse(QEvent::MouseMove, it->mapToScene(QPointF(it->width() / 2, it->height() / 2)), Qt::NoButton);
            wait(350);
        }
    }
    bool click(const QString &name, bool dbl = false)
    {
        QQuickItem *it = find(name);
        if (!it) {
            check(false, QStringLiteral("cannot click \"%1\": no such visible item").arg(name));
            return false;
        }
        reveal(it);
        const QPointF p = it->mapToScene(QPointF(it->width() / 2, it->height() / 2));
        mouse(QEvent::MouseMove, p, Qt::NoButton);
        wait(30);
        mouse(QEvent::MouseButtonPress, p, Qt::LeftButton);
        mouse(QEvent::MouseButtonRelease, p, Qt::LeftButton);
        if (dbl) {
            mouse(QEvent::MouseButtonPress, p, Qt::LeftButton);
            mouse(QEvent::MouseButtonRelease, p, Qt::LeftButton);
        }
        settle(dbl ? 350 : 250);
        return true;
    }
    void typeText(const QString &text)
    {
        for (const QChar ch : text) {
            const int key = ch == QLatin1Char(' ') ? int(Qt::Key_Space) : int(ch.toUpper().unicode());
            QKeyEvent down(QEvent::KeyPress, key, Qt::NoModifier, QString(ch));
            QKeyEvent up(QEvent::KeyRelease, key, Qt::NoModifier, QString(ch));
            QCoreApplication::sendEvent(win, &down);
            QCoreApplication::sendEvent(win, &up);
        }
        settle(250);
    }
    void keyClick(Qt::Key key)
    {
        QKeyEvent down(QEvent::KeyPress, key, Qt::NoModifier);
        QKeyEvent up(QEvent::KeyRelease, key, Qt::NoModifier);
        QCoreApplication::sendEvent(win, &down);
        QCoreApplication::sendEvent(win, &up);
        settle(250);
    }

    QImage shot(const QString &file, bool requireRendered = true)
    {
        const QImage frame = win->grabWindow();
        if (requireRendered)
            check(looksRendered(frame), QStringLiteral("%1 rendered a non-blank frame").arg(file));
        if (!frame.isNull())
            frame.save(QDir(outDir).filePath(file + QStringLiteral(".png")));
        return frame;
    }

    // Geometry audit on named controls: nothing may stick out of the window or overlap its neighbour.
    void geometry(const QString &label, const QStringList &names, const QList<QStringList> &rows)
    {
        const QRectF bounds(0, 0, win->width(), win->height());
        QStringList outside, missing;
        for (const QString &n : names) {
            QQuickItem *it = find(n);
            if (!it) { missing << n; continue; }
            const QRectF r = sceneRect(it);
            if (r.left() < -0.5 || r.right() > bounds.right() + 0.5)
                outside << QStringLiteral("%1 (%2..%3 of %4)").arg(n).arg(r.left()).arg(r.right()).arg(bounds.width());
        }
        check(missing.isEmpty(), label + QStringLiteral(": all audited controls present") + (missing.isEmpty() ? QString() : QStringLiteral(" — missing ") + missing.join(", ")));
        check(outside.isEmpty(), label + QStringLiteral(": no control crosses the window edge") + (outside.isEmpty() ? QString() : QStringLiteral(" — ") + outside.join("; ")));
        QStringList overlaps;
        for (const QStringList &row : rows)
            for (int i = 0; i < row.size(); ++i)
                for (int j = i + 1; j < row.size(); ++j) {
                    QQuickItem *a = find(row[i]), *b = find(row[j]);
                    if (a && b && sceneRect(a).adjusted(0.5, 0.5, -0.5, -0.5).intersects(sceneRect(b)))
                        overlaps << row[i] + QStringLiteral(" × ") + row[j];
                }
        check(overlaps.isEmpty(), label + QStringLiteral(": no overlapping neighbours") + (overlaps.isEmpty() ? QString() : QStringLiteral(" — ") + overlaps.join("; ")));
    }

    QQuickWindow *win;
    QString outDir;
    QTextStream &report;
};

const QStringList kHomeControls = {
    QStringLiteral("searchField"), QStringLiteral("heroContinue"),
    QStringLiteral("formatCard.wide"), QStringLiteral("formatCard.tall"), QStringLiteral("formatCard.sq"), QStringLiteral("formatCard.cine"),
    QStringLiteral("createProject"), QStringLiteral("importFirst"), QStringLiteral("openFromDisk"),
    QStringLiteral("filterChip.All"), QStringLiteral("filterChip.Films"), QStringLiteral("filterChip.Shorts"), QStringLiteral("filterChip.Shared")
};
const QList<QStringList> kHomeRows = {
    { QStringLiteral("formatCard.wide"), QStringLiteral("formatCard.tall"), QStringLiteral("formatCard.sq"), QStringLiteral("formatCard.cine") },
    { QStringLiteral("createProject"), QStringLiteral("importFirst"), QStringLiteral("openFromDisk") },
    { QStringLiteral("filterChip.All"), QStringLiteral("filterChip.Films"), QStringLiteral("filterChip.Shorts"), QStringLiteral("filterChip.Shared") }
};

int runSmokeTest(QQmlApplicationEngine &engine, const QString &outDir, QTextStream &report)
{
    QDir().mkpath(outDir);
    const auto roots = engine.rootObjects();
    if (roots.isEmpty()) {
        report << "FAIL  QML root object created (FrameEase/Main)\n";
        return 1;
    }
    auto *window = qobject_cast<QQuickWindow *>(roots.first());
    if (!window) {
        report << "FAIL  root object is a QQuickWindow\n";
        return 1;
    }
    Smoke t(window, outDir, report);
    t.check(true, QStringLiteral("QML root object created (FrameEase/Main)"));
    t.check(true, QStringLiteral("root object is a QQuickWindow"));
    wait(600);
    t.check(window->isVisible() && window->width() > 0 && window->height() > 0,
            QStringLiteral("window visible, %1x%2").arg(window->width()).arg(window->height()));
    const QSize startSize = window->size();

    // ---------------------------------------------------------------- Home at startup
    t.section(QStringLiteral("Home: startup"));
    t.step(QStringLiteral("Home startup"), [&] {
        t.check(t.winBool("atHome"), QStringLiteral("app launches into Home (atHome = true)"));
        t.check(t.find("homeScreen") != nullptr, QStringLiteral("Home screen is on screen"));
        t.check(t.find("tab.Edit") == nullptr, QStringLiteral("editor top bar is not showing on Home"));
        t.check(t.find("heroContinue") != nullptr, QStringLiteral("featured \"Continue editing\" card present"));
        t.check(t.countCards() == 8, QStringLiteral("Recent grid lists all 8 mock projects (found %1)").arg(t.countCards()));
        const QImage f = t.shot(QStringLiteral("01-home-startup"));
        if (QQuickItem *hero = t.find("heroContinue"))
            t.check(regionVaries(f, sceneRect(hero)), QStringLiteral("featured card shows a rendered poster (not a flat fill)"));
        t.reveal(t.find("projectCard.coastal") ? t.find("projectCard.coastal") : t.find("heroContinue"));
        const QImage g = t.shot(QStringLiteral("02-home-recent-grid"));
        if (QQuickItem *c = t.find("projectCard.coastal"))
            t.check(regionVaries(g, sceneRect(c).adjusted(0, 0, 0, -40)), QStringLiteral("project thumbnails show a rendered poster"));
        t.check(window->title() == QLatin1String("FrameEase"), QStringLiteral("window title on Home is \"FrameEase\" (is \"%1\")").arg(window->title()));
    });
    t.geometry(QStringLiteral("Home @%1x%2").arg(startSize.width()).arg(startSize.height()), kHomeControls, kHomeRows);

    // ---------------------------------------------------------------- new-project presets
    t.section(QStringLiteral("Home: format presets"));
    t.step(QStringLiteral("format presets"), [&] {
        t.check(t.prop("formatCard.wide", "checked").toBool(), QStringLiteral("Widescreen is preselected"));
        t.click("formatCard.tall");
        t.check(t.prop("formatCard.tall", "checked").toBool() && !t.prop("formatCard.wide", "checked").toBool(),
                QStringLiteral("clicking Vertical selects it and deselects Widescreen"));
        t.check(t.prop("createProject", "text").toString() == QLatin1String("Create vertical project"),
                QStringLiteral("create button follows the preset (\"%1\")").arg(t.prop("createProject", "text").toString()));
        t.click("formatCard.wide");
        t.check(t.prop("createProject", "text").toString() == QLatin1String("Create widescreen project"), QStringLiteral("switching back restores the label"));
    });
    t.check(t.prop("openFromDisk", "available").toBool() == false, QStringLiteral("\"Open from disk…\" is visibly disabled (no filesystem in this build)"));

    // ---------------------------------------------------------------- filter + search
    // Expected counts come from the fixed mock data in qml/home/MockLibrary.qml.
    t.section(QStringLiteral("Home: filtering and search"));
    t.step(QStringLiteral("filter chips"), [&] {
        t.click("filterChip.Films");
        t.check(t.countCards() == 4, QStringLiteral("Films filter shows 4 (found %1)").arg(t.countCards()));
        t.check(t.prop("filterChip.Films", "checked").toBool() && !t.prop("filterChip.All", "checked").toBool(), QStringLiteral("only the Films chip is checked"));
        t.click("filterChip.Shorts");
        t.check(t.countCards() == 4, QStringLiteral("Shorts filter shows 4 (found %1)").arg(t.countCards()));
        t.click("filterChip.Shared");
        t.check(t.countCards() == 2, QStringLiteral("Shared filter shows 2 (found %1)").arg(t.countCards()));
        t.click("filterChip.All");
        t.check(t.countCards() == 8, QStringLiteral("All filter restores 8 (found %1)").arg(t.countCards()));
    });
    t.step(QStringLiteral("search"), [&] {
        t.click("searchField");
        t.check(t.prop("searchField", "activeFocus").toBool(), QStringLiteral("clicking the search box focuses it"));
        t.typeText(QStringLiteral("rain"));
        t.check(t.prop("searchField", "text").toString() == QLatin1String("rain"), QStringLiteral("typed text reaches the field (\"%1\")").arg(t.prop("searchField", "text").toString()));
        t.check(t.countCards() == 1 && t.cardIds() == QStringList{QStringLiteral("rain")}, QStringLiteral("\"rain\" finds exactly Rain walk (found %1)").arg(t.cardIds().join(',')));
        t.shot(QStringLiteral("03-home-search-rain"));
        t.click("filterChip.Shorts");
        t.check(t.countCards() == 0 && t.find("recentEmpty") != nullptr, QStringLiteral("search + Shorts filter combine to an empty state"));
        t.shot(QStringLiteral("04-home-empty-state"));
        t.click("clearFilters");
        t.check(t.countCards() == 8 && t.prop("searchField", "text").toString().isEmpty() && t.prop("filterChip.All", "checked").toBool(),
                QStringLiteral("\"Clear search and filters\" restores everything"));
        t.click("searchField");
        t.typeText(QStringLiteral("zzzz"));
        t.check(t.countCards() == 0 && t.find("recentEmpty") != nullptr, QStringLiteral("nonsense query shows the empty state"));
        t.click("searchField.clear");
        t.check(t.countCards() == 8, QStringLiteral("the clear (×) button empties the query"));
        t.click("searchField");
        t.typeText(QStringLiteral("night"));
        t.keyClick(Qt::Key_Escape);
        t.check(t.prop("searchField", "text").toString().isEmpty() && t.countCards() == 8, QStringLiteral("Escape clears the query"));
    });

    // ---------------------------------------------------------------- selection
    t.section(QStringLiteral("Home: project selection"));
    t.step(QStringLiteral("selection"), [&] {
        t.check(t.selectedCardIds().isEmpty() && t.find("selectionBar") == nullptr, QStringLiteral("nothing is selected at first"));
        t.click("projectCard.rain");
        t.check(t.selectedCardIds() == QStringList{QStringLiteral("rain")}, QStringLiteral("click selects Rain walk only (selected: %1)").arg(t.selectedCardIds().join(',')));
        t.check(t.find("selectionBar") != nullptr, QStringLiteral("selection actions appear"));
        t.check(t.winBool("atHome"), QStringLiteral("a single click selects but does not open"));
        t.shot(QStringLiteral("05-home-selected"));
        t.click("projectCard.mara");
        t.check(t.selectedCardIds() == QStringList{QStringLiteral("mara")}, QStringLiteral("selecting another card moves the selection (selected: %1)").arg(t.selectedCardIds().join(',')));
        t.click("searchField");
        t.typeText(QStringLiteral("night"));
        t.check(t.selectedCardIds().isEmpty() && t.find("selectionBar") == nullptr, QStringLiteral("filtering the selected card away clears the selection"));
        t.click("searchField.clear");
        t.check(t.countCards() == 8, QStringLiteral("results restored after clearing"));
    });

    // ---------------------------------------------------------------- Home -> Edit -> Home
    t.section(QStringLiteral("Navigation: Home <-> Edit"));
    t.step(QStringLiteral("hero opens Edit"), [&] {
        t.click("heroContinue");
        t.check(!t.winBool("atHome"), QStringLiteral("clicking the featured card leaves Home"));
        t.check(t.winStr("projectId") == QLatin1String("coastal"), QStringLiteral("featured project opened (projectId = %1)").arg(t.winStr("projectId")));
        t.check(t.winInt("current") == 1, QStringLiteral("lands in the Edit workspace (current = %1)").arg(t.winInt("current")));
        t.check(t.find("homeScreen") == nullptr && t.find("tab.Edit") != nullptr, QStringLiteral("Home is hidden and the editor top bar is showing"));
        t.check(window->title() == QStringLiteral("FrameEase · Coastal Light"), QStringLiteral("window title names the project (\"%1\")").arg(window->title()));
        t.shot(QStringLiteral("06-edit-from-hero"));
        t.check(t.prop("tab.Edit", "on").toBool(), QStringLiteral("Edit tab shows as the active tab"));
    });
    t.step(QStringLiteral("return Home via brand"), [&] {
        t.click("brandHome");
        t.check(t.winBool("atHome") && t.find("homeScreen") != nullptr, QStringLiteral("clicking the FrameEase mark returns Home"));
        t.shot(QStringLiteral("07-home-after-return"));
    });
    t.step(QStringLiteral("recent: select then Open"), [&] {
        t.click("projectCard.rain");
        // after returning, the most recently opened project is first; the selection bar's Open acts on the selection
        t.click("selectionOpen");
        t.check(!t.winBool("atHome") && t.winStr("projectId") == QLatin1String("rain") && t.winInt("current") == 1,
                QStringLiteral("selection bar Open enters Edit for the selected project (%1)").arg(t.winStr("projectId")));
        t.check(window->title() == QStringLiteral("FrameEase · Rain walk"), QStringLiteral("title follows the project (\"%1\")").arg(window->title()));
        t.click("homeButton");
        t.check(t.winBool("atHome"), QStringLiteral("\"← Projects\" button returns Home"));
        t.check(t.cardIds().value(0) == QLatin1String("rain") && t.cardIds().value(1) == QLatin1String("coastal"),
                QStringLiteral("Recent re-sorts by last opened (order: %1)").arg(t.cardIds().join(',')));
    });
    t.step(QStringLiteral("recent: double-click"), [&] {
        t.click("projectCard.market", true);
        t.check(!t.winBool("atHome") && t.winStr("projectId") == QLatin1String("market"), QStringLiteral("double-clicking a card opens it (%1)").arg(t.winStr("projectId")));
        t.click("brandHome");
        t.check(t.winBool("atHome"), QStringLiteral("back to Home again"));
    });
    t.step(QStringLiteral("recent: hover Open pill"), [&] {
        t.hover("projectCard.studio");
        t.check(t.click("projectCard.studio.open") && !t.winBool("atHome") && t.winStr("projectId") == QLatin1String("studio"),
                QStringLiteral("hovering a card reveals Open, which opens it (%1)").arg(t.winStr("projectId")));
        t.click("brandHome");
    });

    // ---------------------------------------------------------------- create / import (mock)
    t.section(QStringLiteral("Home: create and import (mock, not saved)"));
    t.step(QStringLiteral("create"), [&] {
        t.click("formatCard.tall");
        t.click("createProject");
        t.check(!t.winBool("atHome") && t.winStr("projectId").startsWith(QLatin1String("new")) && t.winInt("current") == 1,
                QStringLiteral("Create opens a new in-memory project in Edit (%1)").arg(t.winStr("projectId")));
        t.check(t.find("tab.Edit") != nullptr, QStringLiteral("editor is showing for the new project"));
        t.shot(QStringLiteral("08-edit-new-mock-project"));
        t.click("brandHome");
        t.check(t.countCards() == 9 && t.cardIds().value(0).startsWith(QLatin1String("new")),
                QStringLiteral("the new project is listed first for this session only (%1 cards)").arg(t.countCards()));
        t.shot(QStringLiteral("09-home-with-new-project"));
    });
    t.step(QStringLiteral("import first"), [&] {
        t.click("importFirst");
        t.check(!t.winBool("atHome") && t.winInt("current") == 0, QStringLiteral("\"Import media first\" opens the (placeholder) Media workspace (current = %1)").arg(t.winInt("current")));
        t.click("brandHome");
        t.check(t.winBool("atHome"), QStringLiteral("and Home is one click away"));
    });

    // ---------------------------------------------------------------- existing workspaces, through the tab bar
    t.section(QStringLiteral("Workspaces reached through the top-bar tabs"));
    t.click("heroContinue");
    const struct { const char *name; int index; } workspaces[] = { { "Edit", 1 }, { "Color", 2 }, { "Audio", 3 }, { "Text", 4 } };
    for (const auto &w : workspaces) {
        const QString name = QString::fromLatin1(w.name);
        t.step(name + QStringLiteral(" workspace"), [&] {
            t.click("tab." + name);
            t.check(t.winInt("current") == w.index && t.prop("tab." + name, "on").toBool(), QStringLiteral("tab \"%1\" switches to it (current = %2)").arg(name).arg(t.winInt("current")));
            wait(650);
            t.shot(QStringLiteral("workspace-") + name.toLower());
            t.check(t.find("homeScreen") == nullptr, QStringLiteral("%1: Home is not showing through").arg(name));
        });
    }

    // ---------------------------------------------------------------- responsive sizes
    t.section(QStringLiteral("Responsive captures"));
    const QSize sizes[] = { QSize(1180, 749), QSize(1366, 768), QSize(1600, 900) };
    for (const QSize &want : sizes) {
        const QString tag = QStringLiteral("%1x%2").arg(want.width()).arg(want.height());
        window->resize(want);
        wait(700);
        const bool got = window->size() == want;
        if (got)
            t.info(QStringLiteral("window resized to %1").arg(tag));
        else
            t.info(QStringLiteral("requested %1 but the platform gave %2x%3; captures below use the actual size")
                       .arg(tag).arg(window->width()).arg(window->height()));
        const QString actual = QStringLiteral("%1x%2").arg(window->width()).arg(window->height());

        t.step(QStringLiteral("Edit @") + actual, [&] {
            t.click("tab.Edit");
            wait(500);
            t.shot(QStringLiteral("size-edit-") + actual);
        });
        t.step(QStringLiteral("Home @") + actual, [&] {
            t.click("brandHome");
            wait(500);
            if (QQuickItem *flick = t.find("homeScroll"))
                (void)flick->setProperty("contentY", 0);
            wait(200);
            const bool wide = window->width() >= 1500;
            t.check((t.find("homeSide") != nullptr) == wide, QStringLiteral("Home @%1: side panel is %2 (breakpoint 1500)").arg(actual).arg(wide ? "shown" : "hidden"));
            t.shot(QStringLiteral("size-home-") + actual);
            t.geometry(QStringLiteral("Home @") + actual, kHomeControls, kHomeRows);
            if (QQuickItem *flick = t.find("homeScroll")) {
                const qreal maxY = qMax<qreal>(0, flick->property("contentHeight").toReal() - flick->height());
                flick->setProperty("contentY", maxY);
                wait(250);
                t.shot(QStringLiteral("size-home-") + actual + QStringLiteral("-scrolled"));
                (void)flick->setProperty("contentY", 0);
            }
            t.click("heroContinue");   // so the next loop iteration starts inside the editor
        });
    }
    window->resize(startSize);
    wait(400);

    t.check(g_qmlProblems.isEmpty(), QStringLiteral("no QML warnings/errors over the whole run (%1)").arg(g_qmlProblems.size()));
    return t.failures;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("FrameEase");
    app.setOrganizationName("FrameEase");

    const QStringList args = app.arguments();
    const bool smoke = args.contains(QStringLiteral("--smoke-test"));
    QString outDir = QStringLiteral("smoke-out");
    if (const int i = args.indexOf(QStringLiteral("--out")); i >= 0 && i + 1 < args.size())
        outDir = args.at(i + 1);

    if (smoke) {
        QDir().mkpath(outDir);
        g_log.setFileName(QDir(outDir).filePath(QStringLiteral("qt-messages.log")));
        g_log.open(QIODevice::WriteOnly | QIODevice::Text);
        qInstallMessageHandler(messageHandler);
    }

    // "Basic" is the only Qt Quick Controls style that is fully restylable
    // without fighting a native look; every control is skinned by FE* components.
    QQuickStyle::setStyle("Basic");

    QQmlApplicationEngine engine;
    bool creationFailed = false;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [&creationFailed, smoke]() { creationFailed = true; if (!smoke) QCoreApplication::exit(-1); },
                     Qt::DirectConnection);
    engine.loadFromModule("FrameEase", "Main");

    if (!smoke)
        return creationFailed ? -1 : app.exec();

    QFile reportFile(QDir(outDir).filePath(QStringLiteral("smoke-report.txt")));
    reportFile.open(QIODevice::WriteOnly | QIODevice::Text);
    QTextStream report(&reportFile);
    report << "FrameEase startup smoke test\n";
    report << "Qt " << qVersion() << ", platform " << app.platformName() << ", style Basic\n\n";
    int failures = creationFailed ? 1 : 0;
    if (creationFailed)
        report << "FAIL  engine.loadFromModule(\"FrameEase\", \"Main\") reported objectCreationFailed\n";
    failures += runSmokeTest(engine, outDir, report);
    report << "\n" << (failures ? "RESULT: FAILED" : "RESULT: PASSED") << " (" << failures << " failing checks)\n";
    report.flush();
    return failures ? 1 : 0;
}
