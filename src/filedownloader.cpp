#include "filedownloader.h"
#include <QFile>
#include <QFileInfo>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

FileDownloader::FileDownloader(QObject *parent) : QObject(parent) {}

/* 最小实现：一次 GET ——> 写文件 ——> 发信号 */
void FileDownloader::download(const QString &url, const QString &savePath)
{
    if (url.isEmpty() || savePath.isEmpty()) {
        emit failure("url 或 savePath 为空");
        return;
    }

    QUrl qurl(url);
    if (!qurl.isValid()) {
        emit failure("无效的 URL");
        return;
    }

    /* 确保目标目录存在 */
    QFileInfo fi(savePath);
    if (!fi.dir().exists())
        fi.dir().mkpath(".");

    QNetworkReply *reply = m_mgr.get(QNetworkRequest(qurl));

    /* 只等 finished，进度/SSL 错误可按需再加 */
    connect(reply, &QNetworkReply::finished, this, [=]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit failure("网络错误: " + reply->errorString());
            return;
        }

        QByteArray data = reply->readAll();
        QFile file(savePath);
        if (!file.open(QIODevice::WriteOnly)) {
            emit failure("无法写入文件: " + file.errorString());
            return;
        }
        file.write(data);
        file.close();

        qDebug() << "✅ File saved:" << savePath;
        emit success(savePath);
    });
}
