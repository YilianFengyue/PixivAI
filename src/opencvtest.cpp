#include "opencvtest.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QCoreApplication>
#include <QFile>
#include <QIODevice>
#include <QProcessEnvironment>
#include <QCameraDevice>
#include <QMediaDevices>
#include <QVideoFrame>
#include <QImage>
#include <QPixmap>
#include <QMediaCaptureSession>
#include <QDateTime>
#include <QThread>
#include <QFileInfo>
#include <QImageCapture>  // 新增：用于图像捕获
#include <QUrl>
//文件复制
#include <QGuiApplication>
#include <QClipboard>

OpenCVTest::OpenCVTest(QObject *parent)
    // 摄像头组件
    : QObject(parent)
    , m_camera(nullptr)
    , m_videoSink(nullptr)
    , m_captureSession(nullptr)
    , m_imageCapture(nullptr)  // 新增
    , m_captureTimer(new QTimer(this))
    , m_frameWaitTimer(new QTimer(this))
    , m_cameraActive(false)
    , m_detectionConfidence(0.5f)
    , m_detectionModel("yolo")
    , m_frameCounter(0)
    , m_frameReady(false)
    , m_pendingDetection(false)  // 新增
{
    // 原有的分类功能连接保持不变
    connect(&m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this](int exitCode, QProcess::ExitStatus exitStatus){
                Q_UNUSED(exitStatus);
                QString aiResult;
                if (exitCode == 0) {
                    aiResult = QString::fromUtf8(m_process.readAllStandardOutput());
                } else {
                    QString errorOutput = QString::fromUtf8(m_process.readAllStandardError());
                    aiResult = QString("Python脚本执行失败: %1").arg(errorOutput);
                }
                QVariant preprocessResultVariant = m_process.property("preprocessResult");
                QString preprocessResult = preprocessResultVariant.toString();
                emit classificationFinished(QString("=== OpenCV + TensorFlow 识别结果 ===\n\n%1\n\n%2")
                                                .arg(preprocessResult).arg(aiResult));
            });

    // 目标检测进程连接
    connect(&m_detectionProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &OpenCVTest::onDetectionProcessFinished);
    // 增强版分类功能连接
    // 增强版分类功能连接 - 修正版
    connect(&m_enhancedProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this](int exitCode, QProcess::ExitStatus exitStatus){
                Q_UNUSED(exitStatus);
                QString aiResult = QString::fromUtf8(m_enhancedProcess.readAllStandardOutput());

                // 如果有标准输出，直接使用（忽略stderr的TensorFlow日志）
                if (!aiResult.isEmpty()) {
                    emit enhancedClassificationFinished(aiResult);
                } else {
                    // 只有在真正没有输出时才报告错误
                    QString errorOutput = QString::fromUtf8(m_enhancedProcess.readAllStandardError());
                    emit enhancedClassificationFinished(QString("AI分类无输出: %1").arg(errorOutput));
                }
            });
    // 帧等待定时器设置 - 缩短等待时间
    m_frameWaitTimer->setSingleShot(true);
    m_frameWaitTimer->setInterval(1000); // 等待1秒让摄像头稳定
    connect(m_frameWaitTimer, &QTimer::timeout, this, [this]() {
        qDebug() << "⏰ 摄像头预热完成";
        m_frameReady = true;
    });

    // 移除原来的定时器逻辑，改为按需捕获
    m_captureTimer->setSingleShot(true);
    m_captureTimer->setInterval(500); // 500ms后允许下次捕获
    connect(m_captureTimer, &QTimer::timeout, this, [this]() {
        m_pendingDetection = false;
        qDebug() << "📸 捕获冷却完成，可以进行下次捕获";
    });
}

OpenCVTest::~OpenCVTest()
{
    stopCamera();
}

// === 原有功能保持不变 ===
QString OpenCVTest::getOpenCVVersion() {
    return QString::fromStdString(cv::getVersionString());
}

bool OpenCVTest::testOpenCV() {
    cv::Mat img = cv::Mat::zeros(100, 100, CV_8UC3);
    return !img.empty();
}
//图片预处理
QString OpenCVTest::preprocessImage(const QString& imagePath) {
    try {
        QString actualPath = imagePath;
        if (imagePath.startsWith("qrc:/")) {
            QFile sourceFile(imagePath);
            if (sourceFile.open(QIODevice::ReadOnly)) {
                QString tempPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/temp_input.png";
                QFile tempFile(tempPath);
                if (tempFile.open(QIODevice::WriteOnly)) {
                    tempFile.write(sourceFile.readAll());
                    tempFile.close();
                    actualPath = tempPath;
                }
                sourceFile.close();
            } else {
                return "无法读取资源文件";
            }
        }
        cv::Mat image = cv::imread(actualPath.toStdString());
        if (image.empty()) {
            return QString("图片加载失败: %1").arg(actualPath);
        }
        cv::Mat resized;
        cv::resize(image, resized, cv::Size(224, 224));
        QString outputPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/preprocessed.jpg";
        cv::imwrite(outputPath.toStdString(), resized);
        return QString("预处理完成: %1x%2 -> 224x224\n保存至: %3")
            .arg(image.cols).arg(image.rows).arg(outputPath);
    } catch (const std::exception& e) {
        return QString("OpenCV处理错误: %1").arg(e.what());
    }
}
//图片分类
void OpenCVTest::classifyImage(const QString& imagePath) {
    QString preprocessResult = preprocessImage(imagePath);
    if (preprocessResult.contains("失败") || preprocessResult.contains("无法读取")) {
        emit classificationFinished(preprocessResult);
        return;
    }

    m_process.setProperty("preprocessResult", preprocessResult);
    QString pythonScript = QCoreApplication::applicationDirPath() + "/ai_classifier.py";
    QString processedImagePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/preprocessed.jpg";

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "UTF-8");
    m_process.setProcessEnvironment(env);
    m_process.setProgram("python");
    m_process.setArguments(QStringList() << pythonScript << processedImagePath);
    m_process.start();
}

// === 目标检测功能 ===
void OpenCVTest::detectObjects(const QString& imagePath) {
    qDebug() << "🎯 detectObjects 被调用，图片路径:" << imagePath;

    try {
        QString actualPath = imagePath;

        // 检查文件是否存在
        QFileInfo fileInfo(imagePath);
        if (!fileInfo.exists()) {
            qDebug() << "❌ 文件不存在:" << imagePath;
            emit detectionError(QString("文件不存在: %1").arg(imagePath));
            return;
        }
        qDebug() << "✅ 文件存在，大小:" << fileInfo.size() << "bytes";

        // 处理资源文件路径
        if (imagePath.startsWith("qrc:/")) {
            qDebug() << "🔄 处理资源文件路径";
            QFile sourceFile(imagePath);
            if (sourceFile.open(QIODevice::ReadOnly)) {
                QString tempPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/detection_input.png";
                QFile tempFile(tempPath);
                if (tempFile.open(QIODevice::WriteOnly)) {
                    tempFile.write(sourceFile.readAll());
                    tempFile.close();
                    actualPath = tempPath;
                    qDebug() << "✅ 资源文件已复制到:" << actualPath;
                }
                sourceFile.close();
            } else {
                qDebug() << "❌ 无法读取资源文件";
                emit detectionError("无法读取资源文件");
                return;
            }
        }

        qDebug() << "🖼️ 使用OpenCV加载图片:" << actualPath;
        // 使用OpenCV加载并预处理图片
        cv::Mat image = cv::imread(actualPath.toStdString());
        if (image.empty()) {
            qDebug() << "❌ OpenCV无法加载图片";
            emit detectionError(QString("无法加载图片: %1").arg(actualPath));
            return;
        }
        qDebug() << "✅ OpenCV成功加载图片，尺寸:" << image.cols << "x" << image.rows;

        // 保存预处理后的图片用于检测
        QString detectionImagePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/detection_frame.jpg";
        qDebug() << "💾 保存检测用图片到:" << detectionImagePath;

        if (!cv::imwrite(detectionImagePath.toStdString(), image)) {
            qDebug() << "❌ 保存检测用图片失败";
            emit detectionError("保存检测用图片失败");
            return;
        }
        qDebug() << "✅ 检测用图片保存成功";

        // 启动目标检测进程
        qDebug() << "🚀 启动目标检测进程";
        initializeDetectionProcess();

        QString pythonScript = QCoreApplication::applicationDirPath() + "/object_detector.py";
        qDebug() << "🐍 Python脚本路径:" << pythonScript;

        // 检查Python脚本是否存在
        if (!QFileInfo::exists(pythonScript)) {
            qDebug() << "❌ Python脚本不存在:" << pythonScript;
            emit detectionError("Python检测脚本不存在");
            return;
        }

        QStringList args;
        args << detectionImagePath << QString::number(m_detectionConfidence) << m_detectionModel;
        qDebug() << "📋 Python参数:" << args;

        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("PYTHONIOENCODING", "UTF-8");
        m_detectionProcess.setProcessEnvironment(env);
        m_detectionProcess.setProgram("python");
        m_detectionProcess.setArguments(QStringList() << pythonScript << args);

        qDebug() << "▶️ 启动Python进程";
        m_detectionProcess.start();

        if (!m_detectionProcess.waitForStarted(5000)) {
            qDebug() << "❌ Python进程启动失败:" << m_detectionProcess.errorString();
            emit detectionError("Python进程启动失败: " + m_detectionProcess.errorString());
            return;
        }
        qDebug() << "✅ Python进程启动成功";

    } catch (const std::exception& e) {
        qDebug() << "❌ 检测过程异常:" << e.what();
        emit detectionError(QString("检测过程错误: %1").arg(e.what()));
    }
}
//检测触发
void OpenCVTest::detectObjectsFromCamera() {
    qDebug() << "🔍 detectObjectsFromCamera 被调用";
    qDebug() << "   摄像头状态:" << m_cameraActive;
    qDebug() << "   帧就绪状态:" << m_frameReady;
    qDebug() << "   是否有待处理检测:" << m_pendingDetection;

    if (!m_cameraActive) {
        qDebug() << "❌ 摄像头未启动";
        emit detectionError("摄像头未启动");
        return;
    }

    if (!m_frameReady) {
        qDebug() << "⏳ 摄像头还未就绪，等待预热完成";
        emit detectionError("摄像头预热中，请稍候");
        return;
    }

    if (m_pendingDetection) {
        qDebug() << "⏳ 上次检测还在进行中，跳过此次请求";
        return;
    }

    qDebug() << "✅ 开始捕获帧进行检测";
    m_pendingDetection = true;
    captureFrame();
}

// === 摄像头相关功能 - 重构版 ===
void OpenCVTest::startCamera() {
    qDebug() << "📹 startCamera 被调用";

    if (m_cameraActive) {
        qDebug() << "⚠️ 摄像头已经启动";
        return;
    }

    // 获取默认摄像头设备
    const QList<QCameraDevice> cameras = QMediaDevices::videoInputs();
    qDebug() << "📱 找到" << cameras.size() << "个摄像头设备";

    if (cameras.isEmpty()) {
        qDebug() << "❌ 未找到可用摄像头";
        emit detectionError("未找到可用摄像头");
        return;
    }

    // 打印摄像头信息
    for (int i = 0; i < cameras.size(); ++i) {
        qDebug() << "📷 摄像头" << i << ":" << cameras[i].description();
    }

    // 重置状态
    m_frameReady = false;
    m_pendingDetection = false;
    m_latestFrame = QVideoFrame();

    // 创建组件
    qDebug() << "🔧 创建摄像头组件";
    m_camera = new QCamera(cameras.first(), this);
    m_videoSink = new QVideoSink(this);
    m_captureSession = new QMediaCaptureSession(this);
    m_imageCapture = new QImageCapture(this);  // 新增：用于捕获静态图像

    // 配置连接
    qDebug() << "🔗 配置组件连接";
    m_captureSession->setCamera(m_camera);
    m_captureSession->setVideoSink(m_videoSink);
    m_captureSession->setImageCapture(m_imageCapture);  // 新增

    // 关键修改：改进videoFrameChanged连接
    connect(m_videoSink, &QVideoSink::videoFrameChanged,
            this, [this](const QVideoFrame& frame) {
                // 在主线程中处理帧
                QMetaObject::invokeMethod(this, [this, frame]() {
                    onVideoFrameChanged(frame);
                }, Qt::QueuedConnection);
            });

    // 新增：连接图像捕获信号
    connect(m_imageCapture, &QImageCapture::imageCaptured,
            this, [this](int id, const QImage& image) {
                Q_UNUSED(id);
                qDebug() << "📸 QImageCapture 捕获成功，图像大小:" << image.size();
                onImageCaptured(image);
            });

    connect(m_imageCapture, &QImageCapture::errorOccurred,
            this, [this](int id, QImageCapture::Error error, const QString& errorString) {
                Q_UNUSED(id);
                Q_UNUSED(error);
                qDebug() << "❌ QImageCapture 错误:" << errorString;
            });

    // 摄像头错误处理
    connect(m_camera, &QCamera::errorOccurred,
            this, [this](QCamera::Error error, const QString& errorString) {
                Q_UNUSED(error);
                qDebug() << "❌ 摄像头错误:" << errorString;
                emit detectionError("摄像头错误: " + errorString);
            });

    qDebug() << "🚀 启动摄像头";
    m_camera->start();

    // 等待摄像头启动
    if (!m_camera->isActive()) {
        qDebug() << "⏳ 等待摄像头启动...";
        QTimer::singleShot(500, this, [this]() {
            if (m_camera && m_camera->isActive()) {
                qDebug() << "✅ 摄像头启动成功";
                m_cameraActive = true;
                emit cameraActiveChanged();
                emit captureSessionChanged();

                // 启动预热定时器
                qDebug() << "⏳ 启动摄像头预热定时器";
                m_frameWaitTimer->start();
            } else {
                qDebug() << "❌ 摄像头启动失败";
                emit detectionError("摄像头启动失败");
                stopCamera();
            }
        });
    } else {
        m_cameraActive = true;
        emit cameraActiveChanged();
        emit captureSessionChanged();
        m_frameWaitTimer->start();
    }

    qDebug() << "🎉 摄像头启动流程完成";
}

void OpenCVTest::stopCamera() {
    if (!m_cameraActive) {
        return;
    }

    qDebug() << "🛑 停止摄像头";

    m_frameWaitTimer->stop();
    m_captureTimer->stop();

    // 重置状态
    m_frameReady = false;
    m_pendingDetection = false;
    m_latestFrame = QVideoFrame();

    if (m_camera) {
        m_camera->stop();
        m_camera->deleteLater();
        m_camera = nullptr;
    }

    if (m_videoSink) {
        m_videoSink->deleteLater();
        m_videoSink = nullptr;
    }

    if (m_imageCapture) {
        m_imageCapture->deleteLater();
        m_imageCapture = nullptr;
    }

    if (m_captureSession) {
        m_captureSession->deleteLater();
        m_captureSession = nullptr;
    }

    m_cameraActive = false;
    emit cameraActiveChanged();
    emit captureSessionChanged();

    qDebug() << "✅ 摄像头已停止";
}

// 新增：处理视频帧变化
void OpenCVTest::onVideoFrameChanged(const QVideoFrame& frame) {
    if (!frame.isValid()) {
        return;
    }

    // 更新最新帧
    m_latestFrame = frame;

    if (!m_frameReady) {
        qDebug() << "✅ 收到第一个有效帧，格式:" << frame.pixelFormat() << "大小:" << frame.size();
        m_frameReady = true;
        m_frameWaitTimer->stop();
    }
}

// 新增：处理捕获的图像
void OpenCVTest::onImageCaptured(const QImage& image) {
    qDebug() << "📸 图像捕获成功，开始保存和检测";

    if (image.isNull()) {
        qDebug() << "❌ 捕获的图像为空";
        emit detectionError("捕获的图像为空");
        m_pendingDetection = false;
        return;
    }

    // 保存图像到临时文件
    QString framePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                        + QString("/camera_capture_%1.jpg").arg(QDateTime::currentMSecsSinceEpoch());

    if (image.save(framePath, "JPEG", 90)) {
        qDebug() << "✅ 图像保存成功:" << framePath;
        emit cameraFrameCaptured(framePath);

        // 开始检测
        qDebug() << "🚀 开始目标检测";
        detectObjects(framePath);
    } else {
        qDebug() << "❌ 图像保存失败";
        emit detectionError("图像保存失败");
        m_pendingDetection = false;
    }

    // 启动冷却定时器
    m_captureTimer->start();
}

// 修改后的 captureFrame 方法
void OpenCVTest::captureFrame() {
    qDebug() << "📸 captureFrame 被调用";

    if (!m_cameraActive) {
        qDebug() << "❌ 摄像头未启动";
        emit detectionError("摄像头未启动");
        return;
    }

    if (!m_frameReady) {
        qDebug() << "⏳ 摄像头还未准备好";
        emit detectionError("摄像头还未准备好");
        return;
    }

    if (!m_imageCapture) {
        qDebug() << "❌ QImageCapture 未初始化";
        emit detectionError("图像捕获器未初始化");
        return;
    }

    // 使用 QImageCapture 捕获静态图像
    qDebug() << "🎯 使用 QImageCapture 捕获图像";
    if (m_imageCapture->isReadyForCapture()) {
        m_imageCapture->capture();
        qDebug() << "✅ 捕获命令已发送";
    } else {
        qDebug() << "⏳ QImageCapture 还未准备好";

        // 备用方案：尝试从 videoSink 获取帧
        qDebug() << "🔄 尝试备用方案：从 VideoSink 获取帧";
        QVideoFrame currentFrame = m_latestFrame;

        if (currentFrame.isValid()) {
            qDebug() << "✅ 使用缓存帧作为备用";
            QString savedPath = saveVideoFrameAsImage(currentFrame);
            if (!savedPath.isEmpty()) {
                emit cameraFrameCaptured(savedPath);
                detectObjects(savedPath);
            } else {
                emit detectionError("保存视频帧失败");
                m_pendingDetection = false;
            }
        } else {
            qDebug() << "❌ 缓存帧也无效";
            emit detectionError("无法获取有效帧");
            m_pendingDetection = false;
        }

        m_captureTimer->start();
    }
}

// 新增：将视频帧保存为图像的备用方法
QString OpenCVTest::saveVideoFrameAsImage(const QVideoFrame& frame) {
    qDebug() << "💾 saveVideoFrameAsImage 被调用";

    if (!frame.isValid()) {
        qDebug() << "❌ 输入帧无效";
        return QString();
    }

    // 创建帧的副本以确保线程安全
    QVideoFrame frameCopy = frame;

    // 映射帧数据
    if (!frameCopy.map(QVideoFrame::ReadOnly)) {
        qDebug() << "❌ 无法映射视频帧数据";
        return QString();
    }

    qDebug() << "🖼️ 开始转换视频帧为图像";
    qDebug() << "   帧格式:" << frameCopy.pixelFormat();
    qDebug() << "   帧大小:" << frameCopy.size();

    // 转换视频帧为QImage
    QImage image = frameCopy.toImage();
    frameCopy.unmap();  // 记得取消映射

    if (image.isNull()) {
        qDebug() << "❌ 转换为QImage失败";
        return QString();
    }

    qDebug() << "✅ 成功转换为QImage";
    qDebug() << "   图像大小:" << image.size();
    qDebug() << "   图像格式:" << image.format();

    // 保存到临时文件
    QString framePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                        + QString("/video_frame_%1.jpg").arg(QDateTime::currentMSecsSinceEpoch());

    if (image.save(framePath, "JPEG", 90)) {
        qDebug() << "✅ 视频帧保存成功:" << framePath;
        return framePath;
    } else {
        qDebug() << "❌ 视频帧保存失败";
        return QString();
    }
}

// 保留原有的方法以兼容现有代码
QString OpenCVTest::saveCurrentFrame(const QVideoFrame& frame) {
    return saveVideoFrameAsImage(frame);
}

void OpenCVTest::onCameraFrameReady() {
    // 这个方法现在不再需要，因为我们改用了 QImageCapture
    // 保留空实现以兼容现有代码
}

void OpenCVTest::onDetectionProcessFinished(int exitCode, QProcess::ExitStatus exitStatus) {
    Q_UNUSED(exitStatus);

    QString detectionResult;
    if (exitCode == 0) {
        detectionResult = QString::fromUtf8(m_detectionProcess.readAllStandardOutput());
    } else {
        QString errorOutput = QString::fromUtf8(m_detectionProcess.readAllStandardError());
        detectionResult = QString("目标检测失败: %1").arg(errorOutput);
    }

    // 重置检测状态
    m_pendingDetection = false;

    emit objectDetectionFinished(detectionResult);
}

void OpenCVTest::initializeDetectionProcess() {
    // 确保检测进程已经结束
    if (m_detectionProcess.state() != QProcess::NotRunning) {
        m_detectionProcess.kill();
        m_detectionProcess.waitForFinished(1000);
    }
}

void OpenCVTest::classifyImageEnhanced(const QString& imagePath, const QString& mode) {
    QString actualPath = imagePath;

    // 处理qrc路径（复用现有逻辑）
    if (imagePath.startsWith("qrc:/")) {
        QFile sourceFile(imagePath);
        if (sourceFile.open(QIODevice::ReadOnly)) {
            QString tempPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/temp_enhanced_input.png";
            QFile tempFile(tempPath);
            if (tempFile.open(QIODevice::WriteOnly)) {
                tempFile.write(sourceFile.readAll());
                tempFile.close();
                actualPath = tempPath;
            }
            sourceFile.close();
        }
    }

    QString pythonScript = QCoreApplication::applicationDirPath() + "/enhanced_ai_classifier.py";

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "UTF-8");
    m_enhancedProcess.setProcessEnvironment(env);
    m_enhancedProcess.setProgram("python");
    m_enhancedProcess.setArguments(QStringList() << pythonScript << actualPath << mode);
    m_enhancedProcess.start();
}


