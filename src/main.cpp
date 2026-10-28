#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
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

int runSmokeTest(QQmlApplicationEngine &engine, const QString &outDir, QTextStream &report)
{
    int failures = 0;
    auto check = [&](bool ok, const QString &what) {
        report << (ok ? "PASS  " : "FAIL  ") << what << "\n";
        if (!ok) ++failures;
    };

    const auto roots = engine.rootObjects();
    check(!roots.isEmpty(), QStringLiteral("QML root object created (FrameEase/Main)"));
    if (roots.isEmpty())
        return failures;

    auto *window = qobject_cast<QQuickWindow *>(roots.first());
    check(window != nullptr, QStringLiteral("root object is a QQuickWindow"));
    if (!window)
        return failures;
    wait(500);
    check(window->isVisible() && window->width() > 0 && window->height() > 0,
          QStringLiteral("window visible, %1x%2").arg(window->width()).arg(window->height()));

    // Workspace indices in Main.qml: 1 Edit, 2 Color, 3 Audio, 4 Text. Home/Media/Export are placeholders
    // and are intentionally not exercised in this pass.
    const struct { int index; const char *name; } workspaces[] = { {1, "Edit"}, {2, "Color"}, {3, "Audio"}, {4, "Text"} };

    QDir().mkpath(outDir);
    for (const auto &w : workspaces) {
        const int before = g_qmlProblems.size();
        check(window->setProperty("current", w.index), QStringLiteral("switch to %1 workspace").arg(QString::fromLatin1(w.name)));
        wait(900);                                    // let bindings settle and a few frames render
        const QImage frame = window->grabWindow();
        check(looksRendered(frame), QStringLiteral("%1 workspace rendered a non-blank frame").arg(QString::fromLatin1(w.name)));
        if (!frame.isNull())
            frame.save(QDir(outDir).filePath(QStringLiteral("%1.png").arg(QString::fromLatin1(w.name).toLower())));
        check(g_qmlProblems.size() == before,
              QStringLiteral("%1 workspace produced no QML warnings/errors").arg(QString::fromLatin1(w.name)));
        for (int i = before; i < g_qmlProblems.size(); ++i)
            report << "      qml: " << g_qmlProblems.at(i) << "\n";
    }

    check(g_qmlProblems.isEmpty(), QStringLiteral("no QML warnings/errors over the whole run (%1)").arg(g_qmlProblems.size()));
    return failures;
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
