#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTranslator>
#include "reverseimagesearch.h"
#include <QIcon>
//opencvTest
#include "opencvtest.h"
int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QGuiApplication app(argc, argv);
    //加入图标
    app.setWindowIcon(QIcon("qrc:/logo.ico"));
    qmlRegisterType<ReverseImageSearch>("ImageSearch", 1, 0, "ImageSearcher");
    qmlRegisterType<OpenCVTest>("OpenCVTest", 1, 0, "OpenCVTest");
    QTranslator translator;
    const QStringList uiLanguages = QLocale::system().uiLanguages();
    for (const QString &locale : uiLanguages) {
        const QString baseName = "PixivAI_" + QLocale(locale).name();
        if (translator.load("./i18n/"+ baseName)) {
            app.installTranslator(&translator);
            break;
        }
    }

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/App.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
