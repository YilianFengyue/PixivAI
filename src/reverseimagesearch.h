#ifndef REVERSEIMAGESEARCH_H
#define REVERSEIMAGESEARCH_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>
#include <QVariantList>
#include <QDebug>
#include <QTimer>

class ReverseImageSearch : public QObject
{
    Q_OBJECT

public:
    explicit ReverseImageSearch(QObject *parent = nullptr);
    ~ReverseImageSearch();

    // QML可调用的方法
    Q_INVOKABLE void searchImage(const QString& filePath);
    Q_INVOKABLE void cancelSearch();

signals:
    // 搜索完成信号
    void searchCompleted(const QVariantMap& result);

    // 搜索失败信号
    void searchFailed(const QString& error);

    // 搜索进度信号
    void searchProgress(const QString& status);

private slots:
    // SauceNao响应处理
    void handleSauceNaoReply();

    // Pixiv API响应处理
    void handlePixivReply();

    // 网络错误处理
    void handleNetworkError(QNetworkReply::NetworkError error);

private:
    // 网络管理器
    QNetworkAccessManager* m_networkManager;

    // 当前请求
    QNetworkReply* m_currentReply;

    // 搜索状态
    bool m_isSearching;
    QString m_currentFilePath;

    // API配置
    static const QString SAUCENAO_API_URL;
    static const QString SAUCENAO_API_KEY;
    static const QString PIXIV_API_URL;

    // 私有方法
    void uploadToSauceNao(const QString& filePath);
    void getPixivDetails(const QString& pixivId, const QString& similarity);
    QVariantMap processPixivResponse(const QJsonObject& pixivData, const QString& similarity);
    void cleanup();
    void emitError(const QString& errorMessage);

    // 工具方法
    QString formatFileSize(qint64 bytes);
    QString formatNumber(int number);
    bool isValidImageFile(const QString& filePath);
};

#endif // ReverseImageSearch.h
