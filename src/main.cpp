#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("FrameEase");
    app.setOrganizationName("FrameEase");

    // "Basic" is the only Qt Quick Controls style that is fully restylable
    // without fighting a native look; every control is skinned by FE* components.
    QQuickStyle::setStyle("Basic");

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("FrameEase", "Main");
    return app.exec();
}
