#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QFontInfo>
#include <QGuiApplication>
#include <QImage>
#include <QJSValue>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QScreen>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>
#include <QVariantMap>

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

QString sizeTag(const QSize &s) { return QStringLiteral("%1x%2").arg(s.width()).arg(s.height()); }

QString graphicsApiName(QQuickWindow *w)
{
    QSGRendererInterface *ri = w->rendererInterface();
    if (!ri)
        return QStringLiteral("unknown");
    switch (ri->graphicsApi()) {
    case QSGRendererInterface::Software: return QStringLiteral("Software");
    case QSGRendererInterface::OpenGL: return QStringLiteral("OpenGL");
    case QSGRendererInterface::Direct3D11: return QStringLiteral("Direct3D11");
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
    case QSGRendererInterface::Direct3D12: return QStringLiteral("Direct3D12");
#endif
    case QSGRendererInterface::Vulkan: return QStringLiteral("Vulkan");
    case QSGRendererInterface::Metal: return QStringLiteral("Metal");
    case QSGRendererInterface::Null: return QStringLiteral("Null");
    default: return QStringLiteral("api-%1").arg(int(ri->graphicsApi()));
    }
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

// Fraction of columns along the TOP edge of `r` (scene coordinates) that show a paper-cream pixel within `reach`
// pixels of the edge. This is how a selected card / checked preset is told apart from its neighbours in the frame itself:
// selection and focus are paper-cream (Theme.paper), nothing else on those edges is.
qreal paperEdgeFraction(const QImage &img, const QRectF &r, int reach, int inset)
{
    const int pr = 0xF2, pg = 0xE9, pb = 0xD8;
    const qreal dpr = img.devicePixelRatio();
    int hit = 0, total = 0;
    for (qreal x = r.left() + inset; x < r.right() - inset; x += 4) {
        ++total;
        for (int dy = -reach; dy <= reach; ++dy) {
            const QPoint p(qRound(x * dpr), qRound((r.top() + dy) * dpr));
            if (!img.rect().contains(p))
                continue;
            const QColor c = img.pixelColor(p);
            if (qAbs(c.red() - pr) + qAbs(c.green() - pg) + qAbs(c.blue() - pb) < 36) { ++hit; break; }
        }
    }
    return total ? qreal(hit) / total : 0;
}

// Any visible Text whose content is cut off (elided) or wider than its own box, under `scope`.
void collectTextProblems(QQuickItem *it, QStringList &bad, int &count)
{
    if (it->inherits("QQuickText") && it->isVisible() && it->opacity() > 0.01 && it->width() > 0) {
        ++count;
        const qreal cw = it->property("contentWidth").toReal();
        const QString text = it->property("text").toString().left(36);
        if (it->property("truncated").toBool())
            bad << QStringLiteral("elided \"%1\" (%2 > %3 px)").arg(text).arg(cw, 0, 'f', 0).arg(it->width(), 0, 'f', 0);
        else if (cw > it->width() + 1.0)
            bad << QStringLiteral("overflowing \"%1\" (%2 > %3 px)").arg(text).arg(cw, 0, 'f', 0).arg(it->width(), 0, 'f', 0);
    }
    for (QQuickItem *c : it->childItems())
        collectTextProblems(c, bad, count);
}

// What the app has left on disk under its own data/config folders. The Qt pipeline cache lives in CacheLocation and
// is deliberately not counted: it is a renderer cache, not project data.
QStringList appDiskState()
{
    QStringList roots;
    for (auto loc : { QStandardPaths::AppDataLocation, QStandardPaths::AppLocalDataLocation, QStandardPaths::AppConfigLocation })
        roots << QStandardPaths::standardLocations(loc);
    roots.removeDuplicates();
    QStringList files;
    for (const QString &root : std::as_const(roots)) {
        QDirIterator it(root, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString f = it.next();
            files << f + QLatin1Char(':') + QString::number(QFileInfo(f).size());
        }
    }
    files.sort();
    return files;
}

struct Capture {
    QString file, view, api;
    QSize requested, actual;
};

class Smoke
{
public:
    Smoke(QQuickWindow *w, const QString &out, QTextStream &r, bool exact)
        : win(w), outDir(out), report(r), exactSizes(exact), platform(QGuiApplication::platformName()) {}
    int failures = 0;
    QList<Capture> captures;

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
    // `project` is a JS object on the QML side; convert it before treating it as a map.
    QVariantMap projectOf(const QString &item)
    {
        QVariant v = prop(item, "project");
        if (v.canConvert<QJSValue>())
            v = v.value<QJSValue>().toVariant();
        return v.toMap();
    }

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

    QQuickItem *homeScroll() { return find("homeScroll"); }
    void scrollHomeTo(qreal y)
    {
        if (QQuickItem *flick = homeScroll()) {
            const qreal maxY = qMax<qreal>(0, flick->property("contentHeight").toReal() - flick->height());
            flick->setProperty("contentY", qBound<qreal>(0, y, maxY));
            wait(200);
        }
    }
    void scrollHomeToEnd() { scrollHomeTo(1e9); }

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

    // ---- window size ------------------------------------------------------------------------------
    // Asks for a client size and reports what the platform really granted. A capture is only ever named for the size
    // the window actually has; if the platform clamps the request (a hosted runner's desktop is smaller than the window),
    // the file name and caption say so, and with --exact-sizes the run fails instead of passing quietly.
    bool resizeTo(const QSize &want)
    {
        requested = want;
        win->resize(want);
        QElapsedTimer tm;
        tm.start();
        while (win->size() != want && tm.elapsed() < 4000)
            wait(100);
        wait(600);
        const bool exact = win->size() == want;
        const QString msg = QStringLiteral("window asked for %1, platform granted %2 (%3)")
                                .arg(sizeTag(want), sizeTag(win->size()), exact ? QStringLiteral("exact") : QStringLiteral("CLAMPED"));
        if (exact)
            check(true, msg);
        else if (exactSizes)
            check(false, msg + QStringLiteral(" — the display is too small for this size, so it cannot be captured"));
        else
            info(msg + QStringLiteral(" — captures are labelled with the actual size and do NOT count as this size"));
        return exact;
    }

    // Saves the frame as "<platform>--<view>--<actual size>[--CLAMPED-from-<requested>].png" with a caption strip under the
    // image stating platform, scene-graph API and the real window size, so a PNG can never be mistaken for another renderer
    // or another size once it is detached from the report.
    QImage shot(const QString &view, bool requireRendered = true)
    {
        const QImage frame = win->grabWindow();
        const bool sizeOk = frame.width() == qRound(win->width() * frame.devicePixelRatio())
                         && frame.height() == qRound(win->height() * frame.devicePixelRatio());
        if (requireRendered)
            check(looksRendered(frame) && sizeOk,
                  QStringLiteral("%1 rendered a non-blank frame of the window's size (%2)").arg(view, sizeTag(win->size())));
        if (frame.isNull())
            return frame;

        const QString api = graphicsApiName(win);
        const bool clamped = requested.isValid() && requested != win->size();
        QString name = QStringLiteral("%1--%2--%3").arg(platform, view, sizeTag(win->size()));
        if (clamped)
            name += QStringLiteral("--CLAMPED-from-") + sizeTag(requested);

        const bool real = platform != QLatin1String("offscreen") && platform != QLatin1String("minimal");
        QString caption = QStringLiteral("%1 | %2 | window %3 | Qt %4").arg(platform.toUpper(), api, sizeTag(win->size()), QString::fromLatin1(qVersion()));
        if (clamped)
            caption += QStringLiteral(" | ASKED FOR %1, NOT GRANTED").arg(sizeTag(requested));
        caption += real ? QStringLiteral(" | real platform") : QStringLiteral(" | offscreen software render: layout evidence, NOT Windows pixels");

        const int bar = 22;
        QImage out(frame.width(), frame.height() + bar, QImage::Format_RGB32);
        out.fill(clamped ? QColor(0x6B, 0x1D, 0x1D) : real ? QColor(0x0B, 0x3D, 0x2E) : QColor(0x5A, 0x3A, 0x00));
        {
            QPainter p(&out);
            p.drawImage(0, 0, frame);
            QFont f(QStringLiteral("Geist Mono"));
            f.setPixelSize(12);
            p.setFont(f);
            p.setPen(Qt::white);
            p.drawText(QRect(8, frame.height(), out.width() - 16, bar), Qt::AlignVCenter | Qt::AlignLeft, caption);
        }
        out.save(QDir(outDir).filePath(name + QStringLiteral(".png")));
        captures.append({ name + QStringLiteral(".png"), view, api, requested, win->size() });
        return frame;
    }

    // ---- layout audits --------------------------------------------------------------------------
    // Geometry audit on named controls: nothing may stick out of the window or overlap its neighbour.
    void geometry(const QString &label, const QStringList &names, const QList<QStringList> &rows, bool vertical = false)
    {
        const QRectF bounds(0, 0, win->width(), win->height());
        QStringList outside, missing;
        for (const QString &n : names) {
            QQuickItem *it = find(n);
            if (!it) { missing << n; continue; }
            const QRectF r = sceneRect(it);
            if (r.left() < -0.5 || r.right() > bounds.right() + 0.5 || (vertical && (r.top() < -0.5 || r.bottom() > bounds.bottom() + 0.5)))
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

    // No visible Text under `scopeName` may be elided or wider than its box (that is what "clipped text" looks like).
    // `minTexts` guards against an audit that passes only because it found nothing to look at.
    void textAudit(const QString &label, const QString &scopeName, int minTexts)
    {
        QQuickItem *scope = find(scopeName);
        if (!scope) {
            check(false, label + QStringLiteral(": text audit scope \"%1\" not found").arg(scopeName));
            return;
        }
        QStringList bad;
        int count = 0;
        collectTextProblems(scope, bad, count);
        check(count >= minTexts && bad.isEmpty(),
              label + QStringLiteral(": %1 visible texts (at least %2 expected), none elided or overflowing").arg(count).arg(minTexts)
                  + (bad.isEmpty() ? QString() : QStringLiteral(" — ") + bad.join("; ") + QStringLiteral(" [scope %1x%2, window %3]").arg(scope->width()).arg(scope->height()).arg(sizeTag(win->size())))
                  + (find("homeScroll") ? QStringLiteral(" [scroller %1, side panel %2]").arg(find("homeScroll")->width()).arg(find("homeSide") ? "shown" : "hidden") : QString()));
    }

    QQuickWindow *win;
    QString outDir;
    QTextStream &report;
    bool exactSizes;
    QString platform;
    QSize requested;
};

const QStringList kHomeControls = {
    QStringLiteral("searchField"), QStringLiteral("settingsButton"), QStringLiteral("heroContinue"),
    QStringLiteral("formatCard.wide"), QStringLiteral("formatCard.tall"), QStringLiteral("formatCard.sq"), QStringLiteral("formatCard.cine"),
    QStringLiteral("createProject"), QStringLiteral("importFirst"), QStringLiteral("openFromDisk"),
    QStringLiteral("filterChip.All"), QStringLiteral("filterChip.Films"), QStringLiteral("filterChip.Shorts"), QStringLiteral("filterChip.Shared")
};
const QList<QStringList> kHomeRows = {
    { QStringLiteral("searchField"), QStringLiteral("settingsButton") },
    { QStringLiteral("formatCard.wide"), QStringLiteral("formatCard.tall"), QStringLiteral("formatCard.sq"), QStringLiteral("formatCard.cine") },
    { QStringLiteral("createProject"), QStringLiteral("importFirst"), QStringLiteral("openFromDisk") },
    { QStringLiteral("filterChip.All"), QStringLiteral("filterChip.Films"), QStringLiteral("filterChip.Shorts"), QStringLiteral("filterChip.Shared") }
};
// Everything in the editor's top bar, left to right. They share one row, so none may overlap another or leave the window.
const QStringList kTopBar = {
    QStringLiteral("brandHome"), QStringLiteral("homeButton"),
    QStringLiteral("tab.Media"), QStringLiteral("tab.Edit"), QStringLiteral("tab.Color"), QStringLiteral("tab.Audio"), QStringLiteral("tab.Text"),
    QStringLiteral("undoButton"), QStringLiteral("redoButton"), QStringLiteral("exportButton")
};
// The featured card's own parts must not collide: title block above the call to action above the clip strip.
const QList<QStringList> kHeroParts = { { QStringLiteral("heroTitleBlock"), QStringLiteral("heroCta"), QStringLiteral("heroStrip") } };

const struct { const char *name; int index; } kWorkspaces[] = { { "Media", 0 }, { "Edit", 1 }, { "Color", 2 }, { "Audio", 3 }, { "Text", 4 } };

int runSmokeTest(QQmlApplicationEngine &engine, const QString &outDir, QTextStream &report, bool exactSizes, const QStringList &bundledFamilies)
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
    Smoke t(window, outDir, report, exactSizes);
    t.check(true, QStringLiteral("QML root object created (FrameEase/Main)"));
    t.check(true, QStringLiteral("root object is a QQuickWindow"));
    wait(600);
    t.check(window->isVisible() && window->width() > 0 && window->height() > 0,
            QStringLiteral("window visible, %1").arg(sizeTag(window->size())));

    const QStringList diskBefore = appDiskState();

    // ---------------------------------------------------------------- what this run is actually running on
    t.section(QStringLiteral("Environment (what the evidence below is evidence of)"));
    {
        QScreen *s = window->screen();
        t.info(QStringLiteral("Qt %1, platform \"%2\", scene graph API %3").arg(QString::fromLatin1(qVersion()), QGuiApplication::platformName(), graphicsApiName(window)));
        if (s)
            t.info(QStringLiteral("screen \"%1\": %2 (available %3), devicePixelRatio %4, logical DPI %5")
                       .arg(s->name(), sizeTag(s->geometry().size()), sizeTag(s->availableGeometry().size())).arg(s->devicePixelRatio()).arg(s->logicalDotsPerInch(), 0, 'f', 0));
        t.info(QStringLiteral("window at launch: %1 (frame margins %2,%3)").arg(sizeTag(window->size())).arg(window->frameMargins().left() + window->frameMargins().right()).arg(window->frameMargins().top() + window->frameMargins().bottom()));
        t.info(t.exactSizes ? QStringLiteral("--exact-sizes: a window size the platform does not grant is a FAILURE")
                            : QStringLiteral("no --exact-sizes: a clamped window is reported and labelled, not failed"));
    }

    t.section(QStringLiteral("Bundled fonts"));
    for (const QString &fam : { QStringLiteral("Instrument Sans"), QStringLiteral("Instrument Serif"), QStringLiteral("Geist Mono") })
        t.check(bundledFamilies.contains(fam) && QFontDatabase::families().contains(fam), QStringLiteral("font family \"%1\" is registered from the embedded files").arg(fam));

    // ---------------------------------------------------------------- Home at startup, at the size the app opens with
    t.section(QStringLiteral("Home: startup"));
    t.step(QStringLiteral("Home startup"), [&] {
        t.check(t.winBool("atHome"), QStringLiteral("app launches into Home (atHome = true)"));
        t.check(t.find("homeScreen") != nullptr, QStringLiteral("Home screen is on screen"));
        t.check(t.find("tab.Edit") == nullptr, QStringLiteral("editor top bar is not showing on Home"));
        t.check(t.find("heroContinue") != nullptr, QStringLiteral("featured \"Continue editing\" card present"));
        t.check(t.countCards() == 8, QStringLiteral("Recent grid lists all 8 mock projects (found %1)").arg(t.countCards()));
        const QImage f = t.shot(QStringLiteral("home-startup-default-size"));
        if (QQuickItem *hero = t.find("heroContinue"))
            t.check(regionVaries(f, sceneRect(hero)), QStringLiteral("featured card shows a rendered poster (not a flat fill)"));
        t.check(window->title() == QLatin1String("FrameEase"), QStringLiteral("window title on Home is \"FrameEase\" (is \"%1\")").arg(window->title()));
        // the checked preset is paper-edged in the frame itself, an unchecked one is not
        if (QQuickItem *w = t.find("formatCard.wide"))
            t.check(paperEdgeFraction(f, sceneRect(w), 3, 16) > 0.8, QStringLiteral("checked preset (Widescreen) has the paper selection edge in the frame (%1)").arg(paperEdgeFraction(f, sceneRect(w), 3, 16), 0, 'f', 2));
        if (QQuickItem *v = t.find("formatCard.tall"))
            t.check(paperEdgeFraction(f, sceneRect(v), 3, 16) < 0.1, QStringLiteral("unchecked preset (Vertical) does not (%1)").arg(paperEdgeFraction(f, sceneRect(v), 3, 16), 0, 'f', 2));
    });
    t.step(QStringLiteral("typography"), [&] {
        auto resolved = [&](const QString &item) {
            QQuickItem *it = t.find(item);
            return it ? QFontInfo(it->property("font").value<QFont>()).family() : QStringLiteral("<item not found>");
        };
        t.check(resolved("homeHeadline") == QLatin1String("Instrument Serif"), QStringLiteral("headline renders in Instrument Serif (is \"%1\")").arg(resolved("homeHeadline")));
        t.check(resolved("searchField") == QLatin1String("Instrument Sans"), QStringLiteral("UI text renders in Instrument Sans (is \"%1\")").arg(resolved("searchField")));
        t.check(resolved("recentCount") == QLatin1String("Geist Mono"), QStringLiteral("numbers render in Geist Mono (is \"%1\")").arg(resolved("recentCount")));
    });
    t.check(t.prop("openFromDisk", "available").toBool() == false, QStringLiteral("\"Open from disk…\" is visibly disabled (no filesystem in this build)"));
    t.check(t.prop("settingsButton", "available").toBool() == false, QStringLiteral("Settings is visibly disabled (not built yet)"));

    // ---------------------------------------------------------------- responsive matrix
    // Every view at every size, FIRST, while the app is still in its default state (Coastal Light featured, nothing selected),
    // so the evidence frames show the shipped screen and not whatever the interactive tests below leave behind.
    // A size the platform does not grant is reported as such and never counted.
    t.section(QStringLiteral("Responsive matrix: Home and every workspace at each size"));
    auto ensureHome = [&] { if (!t.winBool("atHome")) t.click("brandHome"); };
    auto ensureEditor = [&] { if (t.winBool("atHome")) t.click("heroContinue"); };
    const QSize sizes[] = { QSize(1180, 749), QSize(1366, 768), QSize(1600, 900) };
    for (const QSize &want : sizes) {
        t.resizeTo(want);
        const QString sz = sizeTag(window->size());

        t.step(QStringLiteral("Home @") + sz, [&] {
            ensureHome();
            t.scrollHomeTo(0);
            const bool wide = window->width() > 1500;
            t.check((t.find("homeSide") != nullptr) == wide, QStringLiteral("Home @%1: side panel is %2 (shown above 1500)").arg(sz, wide ? "shown" : "hidden"));
            t.shot(QStringLiteral("home-top"));
            t.geometry(QStringLiteral("Home @") + sz, kHomeControls, kHomeRows);
            t.geometry(QStringLiteral("Featured card parts @") + sz, { QStringLiteral("heroTitleBlock"), QStringLiteral("heroCta"), QStringLiteral("heroStrip") }, kHeroParts);
            t.textAudit(QStringLiteral("Home @") + sz, QStringLiteral("homeScreen"), 50);
            t.scrollHomeToEnd();
            t.shot(QStringLiteral("home-bottom"));
            t.scrollHomeTo(0);
        });

        for (const auto &w : kWorkspaces) {
            const QString name = QString::fromLatin1(w.name);
            t.step(name + QStringLiteral(" @") + sz, [&] {
                ensureEditor();
                t.click("tab." + name);
                t.check(t.winInt("current") == w.index && t.prop("tab." + name, "on").toBool(),
                        QStringLiteral("%1 @%2: tab switches to it (current = %3)").arg(name, sz).arg(t.winInt("current")));
                wait(650);
                t.shot(QStringLiteral("workspace-") + name.toLower());
                t.check(t.find("homeScreen") == nullptr, QStringLiteral("%1 @%2: Home is not showing through").arg(name, sz));
                if (w.index == 1) {
                    t.geometry(QStringLiteral("Editor top bar @") + sz, kTopBar, { kTopBar }, true);
                    t.textAudit(QStringLiteral("Editor top bar @") + sz, QStringLiteral("editorTopBar"), 8);
                }
                t.click("homeButton");
                t.check(t.winBool("atHome") && t.find("homeScreen") != nullptr, QStringLiteral("%1 @%2: \"← Projects\" returns Home from here").arg(name, sz));
            });
        }
        t.step(QStringLiteral("Export @") + sz, [&] {
            ensureEditor();
            t.click("exportButton");
            t.check(t.winInt("current") == 5, QStringLiteral("Export @%1: the Export button opens the (placeholder) Export page").arg(sz));
            wait(300);
            t.shot(QStringLiteral("workspace-export"));
            t.click("brandHome");
            t.check(t.winBool("atHome"), QStringLiteral("Export @%1: the brand mark returns Home from here too").arg(sz));
        });
    }

    // The rest of the interactive pass runs at the smallest supported window, the tightest layout.
    t.section(QStringLiteral("Interactive pass window size"));
    t.resizeTo(QSize(1180, 749));
    t.geometry(QStringLiteral("Home @%1").arg(sizeTag(window->size())), kHomeControls, kHomeRows);
    t.geometry(QStringLiteral("Featured card parts @%1").arg(sizeTag(window->size())), { QStringLiteral("heroTitleBlock"), QStringLiteral("heroCta"), QStringLiteral("heroStrip") }, kHeroParts);

    // ---------------------------------------------------------------- new-project presets
    t.section(QStringLiteral("Home: format presets"));
    t.step(QStringLiteral("format presets"), [&] {
        t.check(t.prop("formatCard.wide", "checked").toBool(), QStringLiteral("Widescreen is preselected"));
        t.click("formatCard.tall");
        t.check(t.prop("formatCard.tall", "checked").toBool() && !t.prop("formatCard.wide", "checked").toBool(),
                QStringLiteral("clicking Vertical selects it and deselects Widescreen"));
        t.check(t.prop("createProject", "text").toString() == QLatin1String("Create vertical project"),
                QStringLiteral("create button follows the preset (\"%1\")").arg(t.prop("createProject", "text").toString()));
        const QImage f = t.shot(QStringLiteral("home-preset-vertical"));
        if (QQuickItem *v = t.find("formatCard.tall"))
            t.check(paperEdgeFraction(f, sceneRect(v), 3, 16) > 0.8, QStringLiteral("the newly checked preset carries the paper edge in the frame"));
        if (QQuickItem *w = t.find("formatCard.wide"))
            t.check(paperEdgeFraction(f, sceneRect(w), 3, 16) < 0.1, QStringLiteral("and the previous one lost it"));
        t.click("formatCard.wide");
        t.check(t.prop("createProject", "text").toString() == QLatin1String("Create widescreen project"), QStringLiteral("switching back restores the label"));
    });

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
        t.shot(QStringLiteral("home-search-rain"));
        t.click("filterChip.Shorts");
        t.check(t.countCards() == 0 && t.find("recentEmpty") != nullptr, QStringLiteral("search + Shorts filter combine to an empty state"));
        t.textAudit(QStringLiteral("empty state"), QStringLiteral("homeScreen"), 30);
        t.shot(QStringLiteral("home-empty-state"));
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
        const QImage f = t.shot(QStringLiteral("home-selected-card"));
        // the selection state must be visible in the frame, not only in a property
        if (QQuickItem *c = t.find("projectCard.rain"))
            t.check(paperEdgeFraction(f, sceneRect(c), 6, 36) > 0.7, QStringLiteral("selected card carries the paper ring in the frame (%1)").arg(paperEdgeFraction(f, sceneRect(c), 6, 36), 0, 'f', 2));
        if (QQuickItem *n = t.find("projectCard.teaser"))
            t.check(paperEdgeFraction(f, sceneRect(n), 6, 36) < 0.1, QStringLiteral("its unselected neighbour does not (%1)").arg(paperEdgeFraction(f, sceneRect(n), 6, 36), 0, 'f', 2));
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
        t.shot(QStringLiteral("edit-from-hero"));
        t.check(t.prop("tab.Edit", "on").toBool(), QStringLiteral("Edit tab shows as the active tab"));
        t.check(t.prop("undoButton", "available").toBool() == false && t.prop("redoButton", "available").toBool() == false,
                QStringLiteral("Undo and Redo are visibly unavailable (edits are not tracked yet)"));
    });
    t.step(QStringLiteral("return Home via brand"), [&] {
        t.click("brandHome");
        t.check(t.winBool("atHome") && t.find("homeScreen") != nullptr, QStringLiteral("clicking the FrameEase mark returns Home"));
        t.shot(QStringLiteral("home-after-return"));
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
        t.check(t.projectOf("projectCard.rain").value("edited").toString() == QLatin1String("Mon"),
                QStringLiteral("opening a project does not claim it was edited (still \"%1\")").arg(t.projectOf("projectCard.rain").value("edited").toString()));
        t.check(t.selectedCardIds() == QStringList{QStringLiteral("rain")}, QStringLiteral("the selection survives the round trip (selected: %1)").arg(t.selectedCardIds().join(',')));
    });
    t.step(QStringLiteral("recent: double-click"), [&] {
        t.click("projectCard.market", true);
        t.check(!t.winBool("atHome") && t.winStr("projectId") == QLatin1String("market"), QStringLiteral("double-clicking a card opens it (%1)").arg(t.winStr("projectId")));
        t.click("brandHome");
        t.check(t.winBool("atHome"), QStringLiteral("back to Home again"));
        t.check(t.cardIds().value(0) == QLatin1String("market") && t.cardIds().value(1) == QLatin1String("rain"),
                QStringLiteral("the double-clicked project is now first in Recent (order: %1)").arg(t.cardIds().join(',')));
    });
    t.step(QStringLiteral("recent: hover Open pill"), [&] {
        t.hover("projectCard.studio");
        t.check(t.click("projectCard.studio.open") && !t.winBool("atHome") && t.winStr("projectId") == QLatin1String("studio"),
                QStringLiteral("hovering a card reveals Open, which opens it (%1)").arg(t.winStr("projectId")));
        t.click("brandHome");
    });

    // ---------------------------------------------------------------- playback must not outlive the project view
    t.section(QStringLiteral("Navigation: leaving a project stops playback"));
    for (const char *ws : { "edit", "audio", "text" }) {
        const QString key = QString::fromLatin1(ws);
        const QString tab = QString(key.front().toUpper()) + key.mid(1);
        t.step(tab + QStringLiteral(" playback"), [&] {
            t.click("heroContinue");
            t.click("tab." + tab);
            QQuickItem *w = t.find("workspace." + key);
            t.check(w != nullptr, QStringLiteral("%1 workspace is showing").arg(tab));
            if (!w)
                return;
            w->setProperty("playing", true);
            wait(300);
            t.check(t.winBool("anyPlaying"), QStringLiteral("%1: playback is running").arg(tab));
            t.click("brandHome");
            t.check(t.winBool("atHome") && !t.winBool("anyPlaying"), QStringLiteral("%1: returning Home stops playback").arg(tab));
        });
    }

    // ---------------------------------------------------------------- create / import (mock, not persisted)
    t.section(QStringLiteral("Home: create and import (mock, not saved)"));
    t.step(QStringLiteral("create"), [&] {
        t.click("formatCard.tall");
        t.click("createProject");
        t.check(!t.winBool("atHome") && t.winStr("projectId").startsWith(QLatin1String("new")) && t.winInt("current") == 1,
                QStringLiteral("Create opens a new in-memory project in Edit (%1)").arg(t.winStr("projectId")));
        t.check(t.find("tab.Edit") != nullptr, QStringLiteral("editor is showing for the new project"));
        t.shot(QStringLiteral("edit-new-mock-project"));
        t.click("brandHome");
        t.check(t.countCards() == 9 && t.cardIds().value(0).startsWith(QLatin1String("new")),
                QStringLiteral("the new project is listed first for this session only (%1 cards)").arg(t.countCards()));
        t.check(t.projectOf("heroContinue").value("unsaved").toBool(), QStringLiteral("the featured card is the new project, and it is marked unsaved"));
        t.shot(QStringLiteral("home-with-new-project"));
    });
    t.step(QStringLiteral("import first"), [&] {
        t.click("importFirst");
        t.check(!t.winBool("atHome") && t.winInt("current") == 0, QStringLiteral("\"Import media first\" opens the (placeholder) Media workspace (current = %1)").arg(t.winInt("current")));
        t.click("brandHome");
        t.check(t.winBool("atHome"), QStringLiteral("and Home is one click away"));
    });
    t.section(QStringLiteral("Mock data is never persisted"));
    {
        const QStringList diskAfter = appDiskState();
        t.check(diskAfter == diskBefore, QStringLiteral("the app wrote no file under its data/config folders (%1 before, %2 after)").arg(diskBefore.size()).arg(diskAfter.size()));
        QSettings native(QSettings::NativeFormat, QSettings::UserScope, QStringLiteral("FrameEase"), QStringLiteral("FrameEase"));
        t.check(native.allKeys().isEmpty(), QStringLiteral("no QSettings/registry keys were written (%1 keys)").arg(native.allKeys().size()));
    }

    t.check(g_qmlProblems.isEmpty(), QStringLiteral("no QML warnings/errors over the whole run (%1)").arg(g_qmlProblems.size()));

    // ---------------------------------------------------------------- coverage
    t.section(QStringLiteral("Capture coverage: what each requested size really produced"));
    for (const QSize &want : sizes) {
        int exact = 0, clamped = 0;
        QSize granted;
        for (const Capture &c : std::as_const(t.captures))
            if (c.requested == want) {
                if (c.actual == want) ++exact; else { ++clamped; granted = c.actual; }
            }
        if (exact && !clamped)
            report << "COVER " << sizeTag(want) << ": " << exact << " frames captured at exactly this size on platform \"" << t.platform << "\" (" << graphicsApiName(window) << ")\n";
        else if (!exact)
            report << "COVER " << sizeTag(want) << ": NOT CAPTURED at this size; the platform granted " << sizeTag(granted) << " (" << clamped << " frames saved under that size, flagged CLAMPED)\n";
        else
            report << "COVER " << sizeTag(want) << ": PARTIAL, " << exact << " frames exact and " << clamped << " clamped\n";
    }
    report << "\nFRAMES (file | view | API | requested | actual)\n";
    for (const Capture &c : std::as_const(t.captures))
        report << "FRAME " << c.file << " | " << c.view << " | " << c.api << " | " << (c.requested.isValid() ? sizeTag(c.requested) : QStringLiteral("-"))
               << " | " << sizeTag(c.actual) << (c.requested.isValid() && c.requested != c.actual ? " | CLAMPED" : "") << "\n";
    return t.failures;
}

// The design fonts are embedded (resources/fonts, SIL OFL) so typography does not depend on what the machine has.
// Returns the families that actually registered; a font that fails to load falls back to Theme's stack.
QStringList registerBundledFonts()
{
    QStringList families;
    const QDir dir(QStringLiteral(":/FrameEase/fonts"));
    for (const QString &file : dir.entryList({ QStringLiteral("*.ttf") }, QDir::Files)) {
        const int id = QFontDatabase::addApplicationFont(dir.filePath(file));
        if (id < 0)
            qWarning("bundled font %s failed to load", qPrintable(file));
        else
            families << QFontDatabase::applicationFontFamilies(id);
    }
    families.removeDuplicates();

    // Only used when a family above is not installed: QML cannot express a font stack, so the fallback lives here.
    QFont::insertSubstitutions(QStringLiteral("Instrument Sans"), { QStringLiteral("Segoe UI Variable"), QStringLiteral("Segoe UI"), QStringLiteral("Helvetica Neue"), QStringLiteral("Arial") });
    QFont::insertSubstitutions(QStringLiteral("Geist Mono"), { QStringLiteral("Cascadia Mono"), QStringLiteral("Consolas"), QStringLiteral("Menlo"), QStringLiteral("Courier New") });
    QFont::insertSubstitutions(QStringLiteral("Instrument Serif"), { QStringLiteral("Georgia"), QStringLiteral("Times New Roman") });
    return families;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("FrameEase");
    app.setOrganizationName("FrameEase");

    const QStringList args = app.arguments();
    const bool smoke = args.contains(QStringLiteral("--smoke-test"));
    const bool exactSizes = args.contains(QStringLiteral("--exact-sizes"));
    QString outDir = QStringLiteral("smoke-out");
    if (const int i = args.indexOf(QStringLiteral("--out")); i >= 0 && i + 1 < args.size())
        outDir = args.at(i + 1);

    if (smoke) {
        QDir().mkpath(outDir);
        g_log.setFileName(QDir(outDir).filePath(QStringLiteral("qt-messages.log")));
        g_log.open(QIODevice::WriteOnly | QIODevice::Text);
        qInstallMessageHandler(messageHandler);
    }

    const QStringList bundledFamilies = registerBundledFonts();

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
    report << "FrameEase smoke test\n";
    report << "Qt " << qVersion() << ", platform " << app.platformName() << ", style Basic\n\n";
    int failures = creationFailed ? 1 : 0;
    if (creationFailed)
        report << "FAIL  engine.loadFromModule(\"FrameEase\", \"Main\") reported objectCreationFailed\n";
    failures += runSmokeTest(engine, outDir, report, exactSizes, bundledFamilies);
    report << "\n" << (failures ? "RESULT: FAILED" : "RESULT: PASSED") << " (" << failures << " failing checks)\n";
    report.flush();
    return failures ? 1 : 0;
}
