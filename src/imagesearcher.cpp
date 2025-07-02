#include "imagesearcher.h"
#include <QHttpMultiPart>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrlQuery>
#include <QMimeDatabase>

ImageSearcher::ImageSearcher(QObject *parent) : QObject(parent)
{
    m_networkManager = new QNetworkAccessManager(this);
    // 连接网络回复完成的信号到我们的处理槽函数
    connect(m_networkManager, &QNetworkAccessManager::finished, this, &ImageSearcher::onReplyFinished);
}

// QML调用的函数
void ImageSearcher::searchByFile(const QString &localFilePath)
{
    // 1. 准备请求的各个部分
    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // 2. 添加文件部分
    QHttpPart filePart;
    QFile *file = new QFile(localFilePath);
    if (!file->open(QIODevice::ReadOnly)) {
        emit searchError("无法打开文件: " + localFilePath);
        delete file;
        delete multiPart;
        return;
    }
    // 根据文件后缀名自动判断 MIME 类型 (例如 'image/jpeg')
    QMimeDatabase db;
    QMimeType mimeType = db.mimeTypeForFile(localFilePath);
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(mimeType.name()));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"file\"; filename=\"" + file->fileName() + "\""));
    filePart.setBodyDevice(file);
    // 把 file 的父对象设为 multiPart, 这样 multiPart 被删除时, file 也会被删除
    file->setParent(multiPart);
    multiPart->append(filePart);

    // 3. 添加其他表单字段 (API Key, db, numres)
    QHttpPart apiKeyPart;
    apiKeyPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"api_key\""));
    apiKeyPart.setBody("73338e9fd18a060552fcd2a6e48e41eeabec3e20");
    multiPart->append(apiKeyPart);

    QHttpPart dbPart;
    dbPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"db\""));
    dbPart.setBody("999");
    multiPart->append(dbPart);

    QHttpPart numresPart;
    numresPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"numres\""));
    numresPart.setBody("5");
    multiPart->append(numresPart);

    // 4. 创建并发送POST请求
    QUrl url("https://saucenao.com/search.php");
    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->post(request, multiPart);

    // multiPart 会在请求发送完毕后被 reply 自动删除
    multiPart->setParent(reply);
}

// 网络请求结束后的处理函数
void ImageSearcher::onReplyFinished(QNetworkReply *reply)
{
    if (reply->error()) {
        emit searchError("网络错误: " + reply->errorString());
    } else {
        QByteArray responseData = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(responseData);
        if (doc.isObject()) {
            emit searchSuccess(doc.object());
        } else {
            emit searchError("返回的不是有效的JSON数据");
        }
    }
    // 回收 reply 对象
    reply->deleteLater();
}
