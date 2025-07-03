#ifndef OPENCVTEST_H
#define OPENCVTEST_H

#include <QObject>
#include <QProcess>
#include <opencv2/opencv.hpp>
#include <QCamera>
#include <QVideoSink>
#include <QVideoFrame>
#include <QTimer>
#include <QMediaCaptureSession>
#include <QImageCapture>  // 新增

class OpenCVTest : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool cameraActive READ cameraActive NOTIFY cameraActiveChanged)
    Q_PROPERTY(QMediaCaptureSession* captureSession READ captureSession NOTIFY captureSessionChanged)

public:
    explicit OpenCVTest(QObject *parent = nullptr);
    ~OpenCVTest();

public slots:
    // 原有功能保持不变
    QString getOpenCVVersion();
    bool testOpenCV();
    void classifyImage(const QString& imagePath);
    // 新增：增强版AI分类
    void classifyImageEnhanced(const QString& imagePath, const QString& mode);
    // 目标检测功能
    void detectObjects(const QString& imagePath);
    void detectObjectsFromCamera();

    // 摄像头控制
    void startCamera();
    void stopCamera();
    void captureFrame();
    bool cameraActive() const { return m_cameraActive; }
    QMediaCaptureSession* captureSession() const { return m_captureSession; }

    // 设置检测参数
    void setDetectionConfidence(float confidence) { m_detectionConfidence = confidence; }
    void setDetectionModel(const QString& modelType) { m_detectionModel = modelType; }

signals:
    // 原有信号
    void classificationFinished(const QString& result);

    // 目标检测信号
    void objectDetectionFinished(const QString& result);
    void cameraFrameCaptured(const QString& imagePath);
    void cameraActiveChanged();
    void captureSessionChanged();
    void detectionError(const QString& error);
    // 新增：增强版分类完成信号
    void enhancedClassificationFinished(const QString& result);
private slots:
    void onDetectionProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onCameraFrameReady();  // 保留以兼容现有代码
    void onVideoFrameChanged(const QVideoFrame& frame);  // 新增
    void onImageCaptured(const QImage& image);  // 新增


private:
    // 原有成员
    QProcess m_process;
    QString preprocessImage(const QString& imagePath);

    // 目标检测相关
    QProcess m_detectionProcess;
    QCamera* m_camera;
    QVideoSink* m_videoSink;
    QMediaCaptureSession* m_captureSession;
    QImageCapture* m_imageCapture;  // 新增：用于静态图像捕获
    QTimer* m_captureTimer;
    QTimer* m_frameWaitTimer;
    // 新增：增强版分类进程
    QProcess m_enhancedProcess;
    // 状态变量
    bool m_cameraActive;
    bool m_frameReady;
    bool m_pendingDetection;  // 新增：防止重复检测
    float m_detectionConfidence;
    QString m_detectionModel;
    int m_frameCounter;
    QVideoFrame m_latestFrame;

    // 私有方法
    QString saveCurrentFrame(const QVideoFrame& frame);  // 保留以兼容现有代码
    QString saveVideoFrameAsImage(const QVideoFrame& frame);  // 新增：备用方法
    void initializeDetectionProcess();
};

#endif // OPENCVTEST_H
