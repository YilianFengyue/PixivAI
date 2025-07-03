#include "simpledb.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QFileInfo>

SimpleDB::SimpleDB(QObject *parent) : QObject(parent)
{
    initDB();
}

SimpleDB::~SimpleDB()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

bool SimpleDB::initDB()
{
    // 数据库路径
    QString dbPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dbPath);
    dbPath += "/simple_records.db";

    qDebug() << "📁 数据库路径:" << dbPath;

    // 创建连接
    m_db = QSqlDatabase::addDatabase("QSQLITE", "SimpleConnection");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qDebug() << "❌ 数据库打开失败:" << m_db.lastError().text();
        return false;
    }

    // 创建简单表
    QSqlQuery query(m_db);
    QString sql = R"(
        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT,
            image_name TEXT,
            type TEXT,
            result TEXT,
            confidence REAL,
            created_at TEXT
        )
    )";

    if (!query.exec(sql)) {
        qDebug() << "❌ 创建表失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "✅ 数据库初始化成功";
    return true;
}

bool SimpleDB::saveRecord(const QString& imagePath, const QString& type,
                          const QString& result, double confidence)
{
    qDebug() << "💾 保存记录:" << type << confidence;

    QSqlQuery query(m_db);
    query.prepare("INSERT INTO records (image_path, image_name, type, result, confidence, created_at) VALUES (?, ?, ?, ?, ?, ?)");

    QFileInfo fileInfo(imagePath);
    QString imageName = fileInfo.fileName();
    QString currentTime = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");

    query.addBindValue(imagePath);
    query.addBindValue(imageName);
    query.addBindValue(type);
    query.addBindValue(result);
    query.addBindValue(confidence);
    query.addBindValue(currentTime);

    if (!query.exec()) {
        qDebug() << "❌ 保存失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "✅ 保存成功";
    return true;
}

QVariantList SimpleDB::getAllRecords()
{
    QVariantList records;

    QSqlQuery query("SELECT * FROM records ORDER BY id DESC", m_db);

    while (query.next()) {
        QVariantMap record;
        record["id"] = query.value("id").toInt();
        record["imagePath"] = query.value("image_path").toString();
        record["imageName"] = query.value("image_name").toString();
        record["type"] = query.value("type").toString();
        record["result"] = query.value("result").toString();
        record["confidence"] = query.value("confidence").toDouble();
        record["createdAt"] = query.value("created_at").toString();

        // 格式化置信度
        double conf = record["confidence"].toDouble();
        record["confidenceText"] = conf > 0 ? QString::number(conf * 100, 'f', 1) + "%" : "N/A";

        // 格式化类型
        record["typeText"] = (record["type"].toString() == "classification") ? "图像分类" : "目标检测";

        records.append(record);
    }

    qDebug() << "📋 查询到" << records.size() << "条记录";
    return records;
}

bool SimpleDB::deleteRecord(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM records WHERE id = ?");
    query.addBindValue(id);

    if (!query.exec()) {
        qDebug() << "❌ 删除失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "🗑️ 删除成功";
    return true;
}

bool SimpleDB::clearAll()
{
    QSqlQuery query("DELETE FROM records", m_db);

    if (!query.exec()) {
        qDebug() << "❌ 清空失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "🧹 清空成功";
    return true;
}

int SimpleDB::getCount()
{
    QSqlQuery query("SELECT COUNT(*) FROM records", m_db);

    if (query.next()) {
        return query.value(0).toInt();
    }

    return 0;
}
