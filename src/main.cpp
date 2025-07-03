#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTranslator>
#include "reverseimagesearch.h"
#include <QIcon>
//opencvTest
#include "opencvtest.h"
#include "simpledb.h"  // 新增：引入简单数据库
#include "filedownloader.h" //文件下载器
#include <QQmlContext>
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
    qmlRegisterSingletonInstance("Tools",1,0,"Downloader", new FileDownloader(&app));
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

    // 新增：创建全局数据库实例
    SimpleDB* db = new SimpleDB(&app);
    engine.rootContext()->setContextProperty("simpleDB", db);
    const QUrl url(QStringLiteral("qrc:/App.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
