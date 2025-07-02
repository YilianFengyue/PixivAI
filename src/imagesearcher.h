#ifndef IMAGESEARCHER_H
#define IMAGESEARCHER_H

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>

class ImageSearcher : public QObject
{
    Q_OBJECT
public:
    explicit ImageSearcher(QObject *parent = nullptr);

    // 这个函数是暴露给 QML 用的，QML 可以直接调用它来开始搜索
    Q_INVOKABLE void searchByFile(const QString& localFilePath);

signals:
    // 搜索成功后，发出这个信号，并把结果(JSON对象)传给 QML
    void searchSuccess(const QJsonObject& result);

    // 搜索失败后，发出这个信号，并把错误信息传给 QML
    void searchError(const QString& message);

private slots:
    // 当网络请求完成时，这个槽函数会被调用
    void onReplyFinished(QNetworkReply* reply);

private:
    QNetworkAccessManager *m_networkManager;
};

#endif // IMAGESEARCHER_H
