#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>

/* -----------------------------------------------------------
 *  FileDownloader  ——  把网络 url 保存成本地文件
 *  QML 用法:
 *      Downloader.download("https://xx/abc.jpg",
 *                          "C:/Users/you/Pictures/abc.jpg")
 * ----------------------------------------------------------- */
class FileDownloader : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY(FileDownloader)

public:
    explicit FileDownloader(QObject *parent = nullptr);

    /* 供 QML 直接调用
       url       : http/https 图片地址
       savePath  : 本地完整路径
    */
    Q_INVOKABLE void download(const QString &url, const QString &savePath);

signals:
    void success(const QString &filePath);      // 保存成功
    void failure(const QString &reason);        // 网络/IO 失败

private:
    QNetworkAccessManager m_mgr;                // 一行就够用
};
