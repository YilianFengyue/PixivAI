#ifndef SIMPLEDB_H
#define SIMPLEDB_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QSqlDatabase>

class SimpleDB : public QObject
{
    Q_OBJECT

public:
    explicit SimpleDB(QObject *parent = nullptr);
    ~SimpleDB();

    // QML 可调用的简单方法
    Q_INVOKABLE bool saveRecord(const QString& imagePath,
                                const QString& type,  // "classification" 或 "detection"
                                const QString& result,
                                double confidence = 0.0);

    Q_INVOKABLE QVariantList getAllRecords();
    Q_INVOKABLE bool deleteRecord(int id);
    Q_INVOKABLE bool clearAll();
    Q_INVOKABLE int getCount();

private:
    QSqlDatabase m_db;
    bool initDB();
};

#endif // SIMPLEDB_H
