#include "reverseimagesearch.h"
#include <QMimeDatabase>
#include <QMimeType>
#include <QStandardPaths>
#include <QDir>
#include <QUrlQuery>          // 添加：QUrlQuery支持

// API配置常量
const QString ReverseImageSearch::SAUCENAO_API_URL = "https://saucenao.com/search.php";
const QString ReverseImageSearch::SAUCENAO_API_KEY = "73338e9fd18a060552fcd2a6e48e41eeabec3e20";
const QString ReverseImageSearch::PIXIV_API_URL = "https://api.obfs.dev/api/pixiv/illust";

ReverseImageSearch::ReverseImageSearch(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_isSearching(false)
{
    qDebug() << "ReverseImageSearch initialized";
}

ReverseImageSearch::~ReverseImageSearch()
{
    cleanup();
}

void ReverseImageSearch::searchImage(const QString& filePath)
{
    qDebug() << "开始搜索图片:" << filePath;

    // 检查是否正在搜索
    if (m_isSearching) {
        emitError("搜索正在进行中，请稍后再试");
        return;
    }

    // 检查文件是否存在
    if (!QFile::exists(filePath)) {
        emitError("文件不存在: " + filePath);
        return;
    }

    // 检查文件类型
    if (!isValidImageFile(filePath)) {
        emitError("不支持的图片格式");
        return;
    }

    // 检查文件大小 (限制20MB)
    QFileInfo fileInfo(filePath);
    if (fileInfo.size() > 20 * 1024 * 1024) {
        emitError("文件过大，请选择小于20MB的图片");
        return;
    }

    m_isSearching = true;
    m_currentFilePath = filePath;

    emit searchProgress("正在上传图片到SauceNao...");

    // 开始上传到SauceNao
    uploadToSauceNao(filePath);
}

void ReverseImageSearch::uploadToSauceNao(const QString& filePath)
{
    qDebug() << "上传文件到SauceNao:" << filePath;

    // 创建multipart表单数据
    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // 添加API参数
    QHttpPart apiKeyPart;
    apiKeyPart.setHeader(QNetworkRequest::ContentDispositionHeader, "form-data; name=\"api_key\"");
    apiKeyPart.setBody(SAUCENAO_API_KEY.toUtf8());
    multiPart->append(apiKeyPart);

    QHttpPart outputTypePart;
    outputTypePart.setHeader(QNetworkRequest::ContentDispositionHeader, "form-data; name=\"output_type\"");
    outputTypePart.setBody("2");
    multiPart->append(outputTypePart);

    QHttpPart dbPart;
    dbPart.setHeader(QNetworkRequest::ContentDispositionHeader, "form-data; name=\"db\"");
    dbPart.setBody("999");
    multiPart->append(dbPart);

    QHttpPart numresPart;
    numresPart.setHeader(QNetworkRequest::ContentDispositionHeader, "form-data; name=\"numres\"");
    numresPart.setBody("5");
    multiPart->append(numresPart);

    // 添加文件
    QHttpPart filePart;
    QFileInfo fileInfo(filePath);
    QString fileName = fileInfo.fileName();

    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QString("form-data; name=\"file\"; filename=\"%1\"").arg(fileName));

    // 设置MIME类型
    QMimeDatabase mimeDb;
    QMimeType mimeType = mimeDb.mimeTypeForFile(filePath);
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, mimeType.name());

    // 读取文件内容
    QFile *file = new QFile(filePath);
    if (!file->open(QIODevice::ReadOnly)) {
        emitError("无法打开文件: " + filePath);
        delete multiPart;
        delete file;
        return;
    }

    filePart.setBodyDevice(file);
    file->setParent(multiPart); // 让multiPart管理file的生命周期
    multiPart->append(filePart);

    // 创建请求 - 修复Qt6语法
    QNetworkRequest request;
    request.setUrl(QUrl(SAUCENAO_API_URL));
    request.setHeader(QNetworkRequest::UserAgentHeader, "QtReverseImageSearch/1.0");

    // 发送POST请求
    m_currentReply = m_networkManager->post(request, multiPart);
    multiPart->setParent(m_currentReply); // 让reply管理multiPart的生命周期

    // 连接信号
    connect(m_currentReply, &QNetworkReply::finished, this, &ReverseImageSearch::handleSauceNaoReply);
    connect(m_currentReply, QOverload<QNetworkReply::NetworkError>::of(&QNetworkReply::errorOccurred),
            this, &ReverseImageSearch::handleNetworkError);

    qDebug() << "SauceNao请求已发送";
}

void ReverseImageSearch::handleSauceNaoReply()
{
    if (!m_currentReply) {
        return;
    }

    emit searchProgress("正在解析SauceNao响应...");

    // 读取响应数据
    QByteArray responseData = m_currentReply->readAll();
    int statusCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    qDebug() << "SauceNao响应状态码:" << statusCode;
    qDebug() << "SauceNao响应数据:" << responseData.left(500) << "..."; // 只打印前500字符

    m_currentReply->deleteLater();
    m_currentReply = nullptr;

    // 检查HTTP状态码
    if (statusCode != 200) {
        emitError(QString("SauceNao API请求失败，状态码: %1").arg(statusCode));
        return;
    }

    // 解析JSON响应
    QJsonParseError parseError;
    QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        emitError("解析SauceNao响应失败: " + parseError.errorString());
        return;
    }

    QJsonObject jsonObj = jsonDoc.object();

    // 检查API响应状态
    QJsonObject header = jsonObj["header"].toObject();
    int apiStatus = header["status"].toInt();

    if (apiStatus != 0) {
        emitError("SauceNao API错误，状态: " + QString::number(apiStatus));
        return;
    }

    // 查找Pixiv结果
    QJsonArray results = jsonObj["results"].toArray();
    QString bestPixivId;
    QString bestSimilarity;
    double highestSimilarity = 0.0;

    for (const auto& resultValue : results) {
        QJsonObject result = resultValue.toObject();
        QJsonObject resultHeader = result["header"].toObject();
        QJsonObject resultData = result["data"].toObject();

        // 检查是否是Pixiv源
        int indexId = resultHeader["index_id"].toInt();
        if (indexId == 5) { // Pixiv Images index
            double similarity = resultHeader["similarity"].toString().toDouble();

            if (similarity > highestSimilarity) {
                highestSimilarity = similarity;
                bestPixivId = QString::number(resultData["pixiv_id"].toInt());
                bestSimilarity = resultHeader["similarity"].toString();
            }
        }
    }

    // 检查是否找到Pixiv结果
    if (bestPixivId.isEmpty()) {
        emitError("未找到相关的Pixiv作品");
        return;
    }

    qDebug() << "找到最佳匹配的Pixiv ID:" << bestPixivId << "相似度:" << bestSimilarity << "%";

    // 获取Pixiv详细信息
    getPixivDetails(bestPixivId, bestSimilarity);
}

void ReverseImageSearch::getPixivDetails(const QString& pixivId, const QString& similarity)
{
    emit searchProgress("正在获取Pixiv作品详情...");

    // 构建URL
    QString urlString = QString("%1?id=%2").arg(PIXIV_API_URL, pixivId);

    // 创建请求 - 修复Qt6语法
    QNetworkRequest request;
    request.setUrl(QUrl(urlString));
    request.setHeader(QNetworkRequest::UserAgentHeader, "QtReverseImageSearch/1.0");

    // 保存相似度信息 (使用setRawHeader方法)
    request.setRawHeader("X-Similarity", similarity.toUtf8());

    m_currentReply = m_networkManager->get(request);

    connect(m_currentReply, &QNetworkReply::finished, this, &ReverseImageSearch::handlePixivReply);
    connect(m_currentReply, QOverload<QNetworkReply::NetworkError>::of(&QNetworkReply::errorOccurred),
            this, &ReverseImageSearch::handleNetworkError);

    qDebug() << "Pixiv API请求已发送:" << urlString;
}

void ReverseImageSearch::handlePixivReply()
{
    if (!m_currentReply) {
        return;
    }

    emit searchProgress("正在处理Pixiv作品信息...");

    // 获取相似度信息
    // QString similarity = QString::fromUtf8(m_currentReply->rawHeader("X-Similarity"));

    QString similarity = QString::fromUtf8(m_currentReply->request().rawHeader("X-Similarity"));
    QByteArray responseData = m_currentReply->readAll();
    int statusCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    qDebug() << "Pixiv响应状态码:" << statusCode;

    m_currentReply->deleteLater();
    m_currentReply = nullptr;
    m_isSearching = false;

    if (statusCode != 200) {
        emitError(QString("Pixiv API请求失败，状态码: %1").arg(statusCode));
        return;
    }

    // 解析JSON响应
    QJsonParseError parseError;
    QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        emitError("解析Pixiv响应失败: " + parseError.errorString());
        return;
    }

    QJsonObject jsonObj = jsonDoc.object();
    QJsonObject illust = jsonObj["illust"].toObject();

    if (illust.isEmpty()) {
        emitError("Pixiv作品信息为空");
        return;
    }

    // 处理并发送结果
    QVariantMap result = processPixivResponse(illust, similarity);
    emit searchCompleted(result);

    qDebug() << "搜索完成，结果已发送";
}

QVariantMap ReverseImageSearch::processPixivResponse(const QJsonObject& illust, const QString& similarity)
{
    QVariantMap result;

    // 基本信息
    result["pixivId"] = illust["id"].toInt();
    result["title"] = illust["title"].toString();
    result["similarity"] = similarity;

    // 作者信息
    QJsonObject user = illust["user"].toObject();
    result["author"] = user["name"].toString();
    result["authorId"] = user["id"].toInt();

    // 图片信息
    result["width"] = illust["width"].toInt();
    result["height"] = illust["height"].toInt();
    result["resolution"] = QString("%1x%2").arg(illust["width"].toInt()).arg(illust["height"].toInt());

    // 统计信息
    result["views"] = formatNumber(illust["total_view"].toInt());
    result["bookmarks"] = formatNumber(illust["total_bookmarks"].toInt());

    // 图片URL
    QJsonObject imageUrls = illust["image_urls"].toObject();
    result["imageUrl"] = imageUrls["large"].toString();

    // 原图URL
    QJsonObject metaSinglePage = illust["meta_single_page"].toObject();
    if (!metaSinglePage.isEmpty()) {
        result["originalUrl"] = metaSinglePage["original_image_url"].toString();
    } else {
        result["originalUrl"] = imageUrls["large"].toString();
    }

    // 标签
    QJsonArray tags = illust["tags"].toArray();
    QStringList tagList;
    for (const auto& tagValue : tags) {
        QJsonObject tag = tagValue.toObject();
        tagList << tag["name"].toString();
    }
    result["tags"] = tagList.join(", ");

    // 创建时间
    result["createDate"] = illust["create_date"].toString();

    // 工具
    QJsonArray tools = illust["tools"].toArray();
    QStringList toolList;
    for (const auto& tool : tools) {
        toolList << tool.toString();
    }
    result["tools"] = toolList.join(", ");

    return result;
}

void ReverseImageSearch::cancelSearch()
{
    if (m_currentReply) {
        m_currentReply->abort();
    }
    cleanup();
    emit searchProgress("搜索已取消");
}

void ReverseImageSearch::handleNetworkError(QNetworkReply::NetworkError error)
{
    QString errorString;
    switch (error) {
    case QNetworkReply::TimeoutError:
        errorString = "网络请求超时";
        break;
    case QNetworkReply::ConnectionRefusedError:
        errorString = "连接被拒绝";
        break;
    case QNetworkReply::HostNotFoundError:
        errorString = "服务器未找到";
        break;
    case QNetworkReply::ContentNotFoundError:
        errorString = "内容未找到";
        break;
    default:
        errorString = QString("网络错误: %1").arg(error);
        break;
    }

    emitError(errorString);
}

void ReverseImageSearch::cleanup()
{
    if (m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
    m_isSearching = false;
}

void ReverseImageSearch::emitError(const QString& errorMessage)
{
    qDebug() << "错误:" << errorMessage;
    cleanup();
    emit searchFailed(errorMessage);
}

QString ReverseImageSearch::formatFileSize(qint64 bytes)
{
    const qint64 KB = 1024;
    const qint64 MB = KB * 1024;
    const qint64 GB = MB * 1024;

    if (bytes < KB) {
        return QString("%1 B").arg(bytes);
    } else if (bytes < MB) {
        return QString("%1 KB").arg(bytes / KB);
    } else if (bytes < GB) {
        return QString("%1 MB").arg(bytes / MB);
    } else {
        return QString("%1 GB").arg(bytes / GB);
    }
}

QString ReverseImageSearch::formatNumber(int number)
{
    if (number < 1000) {
        return QString::number(number);
    } else if (number < 1000000) {
        return QString("%1K").arg(number / 1000.0, 0, 'f', 1);
    } else {
        return QString("%1M").arg(number / 1000000.0, 0, 'f', 1);
    }
}

bool ReverseImageSearch::isValidImageFile(const QString& filePath)
{
    QMimeDatabase mimeDb;
    QMimeType mimeType = mimeDb.mimeTypeForFile(filePath);
    QString mimeTypeName = mimeType.name();

    return mimeTypeName.startsWith("image/") &&
           (mimeTypeName.contains("jpeg") ||
            mimeTypeName.contains("png") ||
            mimeTypeName.contains("gif") ||
            mimeTypeName.contains("bmp"));
}
