import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia 6.5
import OpenCVTest 1.0
import QtQuick.Dialogs

FluScrollablePage {
    id: root
    property string detectionResult: ""
    property bool isDetecting: false
    property var records: []
    // 添加文件选择对话框
    FileDialog {
        id: fileDialog
        title: "选择图片文件"
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.bmp *.tiff)", "所有文件 (*)"]
        fileMode: FileDialog.OpenFile

        onAccepted: {
            // 获取选中的文件路径
            var filePath = selectedFile.toString()
            // 移除 file:// 前缀（如果存在）
            if (filePath.startsWith("file:///")) {
                filePath = filePath.substring(8)
            } else if (filePath.startsWith("file://")) {
                filePath = filePath.substring(7)
            }

            // 显示选择的文件
            showInfo("已选择文件: " + filePath)

            // 开始检测
            btnDetect.loading = true
            root.isDetecting = true
            cvTest.detectObjects(filePath)
        }

        onRejected: {
            showInfo("已取消文件选择")
        }
    }

    OpenCVTest {
        id: cvTest

        // 原有信号处理 + 增强调试
        onObjectDetectionFinished: function(result) {
            console.log("✅ 检测完成:", result)
            root.detectionResult = result
            root.isDetecting = false
            btnDetect.loading = false
            btnCameraDetect.loading = false

            // 解析检测结果用于可视化
            parseDetectionResult(result)

            // 更新统计信息
            updateDetectionStats(result)
        }

        onDetectionError: function(error) {
            console.log("❌ 检测错误:", error)
            root.detectionResult = "❌ 检测错误: " + error
            root.isDetecting = false
            btnDetect.loading = false
            btnCameraDetect.loading = false

            // 显示用户友好的错误信息
            if (error.includes("摄像头还未准备好") || error.includes("预热中")) {
                showInfo("摄像头正在启动中，请稍候再试...")
            } else {
                showError(error)
            }
        }

        onCameraFrameCaptured: function(imagePath) {
            console.log("📸 摄像头帧已捕获:", imagePath)
            showInfo("已捕获摄像头帧")
            // 显示捕获的图片
            capturedImage.source = "file:///" + imagePath
            capturedImageContainer.visible = true
        }

        onCameraActiveChanged: {
            console.log("📹 摄像头状态变化:", cvTest.cameraActive)
            btnCameraToggle.checked = cvTest.cameraActive

            // 如果摄像头关闭，停止连续检测并隐藏捕获的图片
            if (!cvTest.cameraActive) {
                chkContinuousDetection.checked = false
                continuousDetectionTimer.stop()
                capturedImageContainer.visible = false
            }
        }


        // 新增：监听captureSession变化的调试信息
        onCaptureSessionChanged: {
            console.log("🔄 CaptureSession状态变化")
        }
    }

    // 添加连续检测定时器
    Timer {
        id: continuousDetectionTimer
        interval: 2000
        repeat: true
        running: false

        onTriggered: {
            if (cvTest.cameraActive && chkContinuousDetection.checked && !root.isDetecting) {
                console.log("🔄 自动检测触发")
                root.isDetecting = true
                cvTest.detectObjectsFromCamera()
            }
        }
    }

    RowLayout {
        width: parent.width
        spacing: 30

        // 左侧控制区域
        Column {
            Layout.preferredWidth: parent.width * 0.6
            spacing: 20

            // 页面标题
            Row {
                spacing: 15

                FluIcon {
                    iconSource: FluentIcons.Search
                    font.pointSize: 32
                    color: FluTheme.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 5

                    FluText {
                        text: qsTr("🎯 目标检测")
                        font: FluTextStyle.Title
                    }

                    FluText {
                        text: qsTr("实时检测图像中的物体，支持多种检测模型")
                        color: FluTheme.fontSecondaryColor
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: FluTheme.dividerColor
            }

            // 修复后的摄像头预览区域
            Rectangle {
                id: previewContainer
                width: parent.width
                height: 250
                color: FluTheme.itemHoverColor
                radius: 12
                border.width: 2
                border.color: cvTest.cameraActive ? FluTheme.accentColor : FluTheme.dividerColor

                // 视频预览组件 - 修复版
                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: cvTest.cameraActive
                    fillMode: VideoOutput.PreserveAspectFit

                    // 修复：确保正确连接到capture session
                    Connections {
                        target: cvTest
                        function onCaptureSessionChanged() {
                            console.log("CaptureSession changed, connecting to VideoOutput")
                            if (cvTest.captureSession) {
                                // 确保连接成功
                                cvTest.captureSession.videoOutput = videoOutput
                                console.log("VideoOutput connected to captureSession")
                            } else {
                                console.log("CaptureSession is null")
                            }
                        }
                    }

                    // 添加更详细的状态监控
                    Component.onCompleted: {
                        console.log("VideoOutput component completed")
                        // 初始连接尝试
                        if (cvTest.captureSession) {
                            cvTest.captureSession.videoOutput = videoOutput
                            console.log("✅ 初始连接成功")
                        }
                    }

                    // LIVE指示器
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        width: statusText.width + 16
                        height: statusText.height + 8
                        color: FluTheme.accentColor
                        radius: 4
                        opacity: 0.8
                        visible: cvTest.cameraActive

                        FluText {
                            id: statusText
                            anchors.centerIn: parent
                            text: "🔴 LIVE"
                            color: "white"
                            font.pointSize: 10
                            font.bold: true
                        }
                    }

                    // 添加检测状态指示器
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: detectStatusText.width + 16
                        height: detectStatusText.height + 8
                        color: root.isDetecting ? "orange" : "green"
                        radius: 4
                        opacity: 0.8
                        visible: cvTest.cameraActive

                        FluText {
                            id: detectStatusText
                            anchors.centerIn: parent
                            text: root.isDetecting ? "🔍 检测中" : "✅ 就绪"
                            color: "white"
                            font.pointSize: 9
                            font.bold: true
                        }
                    }

                    // 添加连续检测指示器
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 8
                        width: continuousText.width + 16
                        height: continuousText.height + 8
                        color: chkContinuousDetection.checked ? "red" : "gray"
                        radius: 4
                        opacity: 0.7
                        visible: cvTest.cameraActive && chkContinuousDetection.checked

                        FluText {
                            id: continuousText
                            anchors.centerIn: parent
                            text: "🔄 连续"
                            color: "white"
                            font.pointSize: 9
                            font.bold: true
                        }
                    }
                }

                // 占位符内容（当摄像头未启动时显示）
                Column {
                    anchors.centerIn: parent
                    spacing: 15
                    visible: !cvTest.cameraActive

                    FluIcon {
                        iconSource: FluentIcons.Camera
                        font.pointSize: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: FluTheme.fontSecondaryColor
                    }

                    FluText {
                        text: qsTr("📷 摄像头预览区域")
                        anchors.horizontalCenter: parent.horizontalCenter
                        font: FluTextStyle.Body
                    }

                    FluText {
                        text: qsTr("点击下方按钮启动摄像头")
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: FluTheme.fontSecondaryColor
                        font.pointSize: 10
                    }
                }

                // 控制按钮区域 - 增强版
                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 15

                    FluToggleButton {
                        id: btnCameraToggle
                        text: cvTest.cameraActive ? qsTr("停止摄像头") : qsTr("启动摄像头")
                        checked: cvTest.cameraActive  // 直接绑定到cameraActive状态
                        onClicked: {
                            if (cvTest.cameraActive) {
                                console.log("🛑 停止摄像头")
                                cvTest.stopCamera()
                            } else {
                                console.log("🚀 启动摄像头")
                                cvTest.startCamera()
                            }
                        }
                    }

                    FluLoadingButton {
                        id: btnCameraDetect
                        text: qsTr("实时检测")
                        enabled: cvTest.cameraActive && !root.isDetecting
                        onClicked: {
                            console.log("🔍 开始摄像头检测")
                            console.log("   摄像头状态:", cvTest.cameraActive)
                            console.log("   当前检测状态:", root.isDetecting)

                            loading = true
                            root.isDetecting = true
                            cvTest.detectObjectsFromCamera()
                        }
                    }

                    FluButton {
                        text: qsTr("捕获帧")
                        enabled: cvTest.cameraActive
                        onClicked: {
                            console.log("🧪 手动捕获帧")
                            cvTest.captureFrame()
                        }
                    }

                    FluFilledButton {
                        text: qsTr("选择图片")
                        onClicked: {
                            fileDialog.open()
                        }
                    }
                }
            }

            // 新增：捕获图片显示区域
            Rectangle {
                id: capturedImageContainer
                width: parent.width
                height: 200
                visible: false
                color: FluTheme.itemHoverColor
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Row {
                        width: parent.width

                        FluText {
                            text: qsTr("📸 捕获的图片")
                            font: FluTextStyle.BodyStrong
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: parent.width - saveFrameBtn.width - closeBtn.width - 40 }

                        FluButton {
                            id: saveFrameBtn
                            text: qsTr("保存")
                            onClicked: {
                                showSuccess("图片已保存")
                            }
                        }

                        FluButton {
                            id: closeBtn
                            text: qsTr("关闭")
                            onClicked: {
                                capturedImageContainer.visible = false
                            }
                        }
                    }

                    Image {
                        id: capturedImage
                        width: parent.width
                        height: 150
                        fillMode: Image.PreserveAspectFit

                        // 添加检测结果标注覆盖层
                        Canvas {
                            id: detectionCanvas
                            anchors.fill: parent
                            property var detectionBoxes: []

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                if (detectionBoxes.length === 0) return

                                // 绘制检测框
                                ctx.strokeStyle = "#FF6B6B"
                                ctx.lineWidth = 2
                                ctx.font = "12px Arial"
                                ctx.fillStyle = "#FF6B6B"

                                for (var i = 0; i < detectionBoxes.length; i++) {
                                    var box = detectionBoxes[i]

                                    // 计算缩放比例
                                    var scaleX = width / (capturedImage.sourceSize.width || 1)
                                    var scaleY = height / (capturedImage.sourceSize.height || 1)

                                    var x = box.x * scaleX
                                    var y = box.y * scaleY
                                    var w = box.width * scaleX
                                    var h = box.height * scaleY

                                    // 绘制边界框
                                    ctx.strokeRect(x, y, w, h)

                                    // 绘制标签背景
                                    var label = box.class + " " + (box.confidence * 100).toFixed(0) + "%"
                                    var textWidth = ctx.measureText(label).width
                                    ctx.fillRect(x, y - 20, textWidth + 8, 20)

                                    // 绘制标签文字
                                    ctx.fillStyle = "white"
                                    ctx.fillText(label, x + 4, y - 6)
                                    ctx.fillStyle = "#FF6B6B"
                                }
                            }

                            function updateDetectionBoxes(boxes) {
                                detectionBoxes = boxes
                                requestPaint()
                            }
                        }
                    }
                }
            }

            // 新增：实时检测控制区域
            FluGroupBox {
                title: qsTr("实时检测控制")
                width: parent.width

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Row {
                        spacing: 10
                        Layout.fillWidth: true

                        FluCheckBox {
                            id: chkContinuousDetection
                            text: qsTr("连续检测")
                            enabled: cvTest.cameraActive
                            onCheckedChanged: {
                                if (checked && cvTest.cameraActive) {
                                    console.log("🔄 启动连续检测")
                                    continuousDetectionTimer.start()
                                } else {
                                    console.log("⏹️ 停止连续检测")
                                    continuousDetectionTimer.stop()
                                }
                            }
                        }

                        FluText {
                            text: qsTr("检测间隔:")
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        FluSlider {
                            id: detectionIntervalSlider
                            from: 1000
                            to: 5000
                            value: 2000
                            stepSize: 500
                            Layout.fillWidth: true

                            onValueChanged: {
                                intervalText.text = (value / 1000).toFixed(1) + "s"
                                continuousDetectionTimer.interval = value
                            }
                        }

                        FluText {
                            id: intervalText
                            text: "2.0s"
                            anchors.verticalCenter: parent.verticalCenter
                            color: FluTheme.accentColor
                        }
                    }

                    Row {
                        spacing: 10

                        FluButton {
                            text: qsTr("保存当前帧")
                            enabled: cvTest.cameraActive
                            onClicked: {
                                cvTest.captureFrame()
                                showSuccess("帧已保存")
                            }
                        }

                        FluButton {
                            text: qsTr("开始录制")
                            enabled: cvTest.cameraActive
                            onClicked: {
                                showInfo("录制功能待实现")
                            }
                        }
                    }
                }
            }

            FluGroupBox {
                title: "💾 保存检测结果"
                width: parent.width

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Row {
                        spacing: 10

                        FluButton {
                            text: "保存当前结果"
                            enabled: root.detectionResult !== ""
                            onClicked: {
                                // 提取置信度
                                var confidence = extractConfidenceFromResult(root.detectionResult)

                                // 保存到数据库
                                var success = simpleDB.saveRecord(
                                    "检测图片",  // 简化路径
                                    "object_detection",
                                    root.detectionResult,
                                    confidence
                                )

                                if (success) {
                                    showSuccess("检测结果已保存")
                                } else {
                                    showError("保存失败")
                                }
                            }
                        }


                        FluButton {
                            text: "🔄 查询总数"
                            onClicked: {
                                var recs = simpleDB.getAllRecords()
                                showInfo("当前共 " + recs.length + " 条历史")
                            }
                        }
                        FluButton {
                            text: "测试数据库"
                            onClicked: {
                                // 保存
                                var success = simpleDB.saveRecord(
                                    "test.jpg",
                                    "object_detection",
                                    "发现了一只猫",
                                    0.95
                                )
                                showInfo("保存: " + (success ? "成功" : "失败"))

                                // 查询
                                var records = simpleDB.getAllRecords()
                                showInfo("记录数: " + records.length)
                            }
                        }
                    }


                }
            }
            // 检测参数设置
            FluGroupBox {
                title: qsTr("检测参数")
                width: parent.width

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15

                    // 模型选择
                    Row {
                        spacing: 10
                        Layout.fillWidth: true

                        FluText {
                            text: qsTr("检测模型:")
                            anchors.verticalCenter: parent.verticalCenter
                            font: FluTextStyle.BodyStrong
                        }

                        FluRadioButton {
                            id: radioYolo
                            text: "YOLO"
                            checked: true
                            onClicked: {
                                if (checked) {
                                    radioSSD.checked = false
                                    radioMobileNet.checked = false
                                    cvTest.setDetectionModel("yolo")
                                }
                            }
                        }


                    }

                    // 置信度设置
                    Row {
                        spacing: 10
                        Layout.fillWidth: true

                        FluText {
                            text: qsTr("置信度阈值:")
                            anchors.verticalCenter: parent.verticalCenter
                            font: FluTextStyle.BodyStrong
                        }

                        FluSlider {
                            id: confidenceSlider
                            from: 0.1
                            to: 0.9
                            value: 0.5
                            stepSize: 0.1
                            Layout.fillWidth: true

                            onValueChanged: {
                                cvTest.setDetectionConfidence(value)
                                confidenceText.text = (value * 100).toFixed(0) + "%"
                            }
                        }

                        FluText {
                            id: confidenceText
                            text: "50%"
                            anchors.verticalCenter: parent.verticalCenter
                            font: FluTextStyle.Body
                            color: FluTheme.accentColor
                        }
                    }

                    // 检测选项
                    GridLayout {
                        columns: 2
                        columnSpacing: 15
                        rowSpacing: 8
                        Layout.fillWidth: true

                        FluCheckBox {
                            id: chkShowBoundingBox
                            text: qsTr("显示边界框")
                            checked: true
                        }

                        FluCheckBox {
                            id: chkShowConfidence
                            text: qsTr("显示置信度")
                            checked: true
                        }

                        FluCheckBox {
                            id: chkSaveResults
                            text: qsTr("自动保存结果")
                            checked: false
                        }

                        FluCheckBox {
                            id: chkRealTimeDetection
                            text: qsTr("检测后自动捕获")
                            checked: false
                            enabled: cvTest.cameraActive
                        }
                    }
                }
            }

            // 控制按钮
            Row {
                spacing: 10

                FluLoadingButton {
                    id: btnDetect
                    text: qsTr("开始检测")
                    onClicked: {
                        loading = true
                        root.isDetecting = true
                        // 使用测试图片路径
                        cvTest.detectObjects("C:\\Users\\123\\Desktop\\dog.jpg")
                    }
                }

                FluButton {
                    text: qsTr("清空结果")
                    onClicked: {
                        root.detectionResult = ""
                        capturedImageContainer.visible = false
                        showInfo(qsTr("检测结果已清空"))
                    }
                }
            }

            // 检测状态指示
            Rectangle {
                width: parent.width
                height: 60
                color: root.isDetecting ? FluTheme.accentColor.lighter() : FluTheme.itemHoverColor
                radius: 8
                border.width: 1
                border.color: root.isDetecting ? FluTheme.accentColor : FluTheme.dividerColor

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    FluProgressRing {
                        visible: root.isDetecting
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    FluIcon {
                        iconSource: root.isDetecting ? FluentIcons.Sync : FluentIcons.CheckMark
                        color: root.isDetecting ? FluTheme.accentColor : FluTheme.fontSecondaryColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    FluText {
                        text: root.isDetecting ? qsTr("正在检测中...") : qsTr("检测就绪")
                        font: FluTextStyle.BodyStrong
                        color: root.isDetecting ? FluTheme.accentColor : FluTheme.fontPrimaryColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 右侧结果区域
        Column {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            FluText {
                text: qsTr("检测结果")
                font: FluTextStyle.Subtitle
            }

            // 主结果显示区域
            FluMultilineTextBox {
                width: parent.width
                height: 500
                readOnly: true
                wrapMode: TextEdit.Wrap
                text: root.detectionResult
                placeholderText: "点击左侧开始检测按钮开始目标检测..."
                selectByMouse: true
            }

            // 检测统计 - 动态更新版
            Rectangle {
                width: parent.width
                height: 120
                color: FluTheme.itemHoverColor
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    FluText {
                        text: qsTr("检测统计:")
                        font: FluTextStyle.BodyStrong
                    }

                    Row {
                        spacing: 20

                        Column {
                            FluText {
                                text: qsTr("检测到的物体")
                                color: FluTheme.fontSecondaryColor
                                font.pointSize: 10
                            }
                            FluText {
                                id: objectCountText
                                text: "0"
                                font: FluTextStyle.BodyStrong
                                color: FluTheme.accentColor
                            }
                        }

                        Column {
                            FluText {
                                text: qsTr("平均置信度")
                                color: FluTheme.fontSecondaryColor
                                font.pointSize: 10
                            }
                            FluText {
                                id: avgConfidenceText
                                text: "0%"
                                font: FluTextStyle.BodyStrong
                                color: FluTheme.accentColor
                            }
                        }

                        Column {
                            FluText {
                                text: qsTr("处理时间")
                                color: FluTheme.fontSecondaryColor
                                font.pointSize: 10
                            }
                            FluText {
                                id: processingTimeText
                                text: "0s"
                                font: FluTextStyle.BodyStrong
                                color: FluTheme.accentColor
                            }
                        }
                    }
                }
            }


        }
    }

    // 添加解析检测结果的函数
    function parseDetectionResult(result) {
        try {
            console.log("📊 开始解析检测结果")
            var boxes = []

            // 解析检测结果文本，提取边界框信息
            var lines = result.split('\n')
            var currentBox = {}

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()

                if (line.includes('🎯')) {
                    // 新的检测对象
                    if (currentBox.class) {
                        boxes.push(currentBox)
                    }
                    currentBox = {}
                    var parts = line.split('🎯')
                    if (parts.length > 1) {
                        currentBox.class = parts[1].trim()
                    }
                } else if (line.includes('置信度:')) {
                    var conf = line.match(/(\d+\.?\d*)%/)
                    if (conf) {
                        currentBox.confidence = parseFloat(conf[1]) / 100
                    }
                } else if (line.includes('位置:')) {
                    var pos = line.match(/\((\d+),\s*(\d+)\)/)
                    if (pos) {
                        currentBox.x = parseInt(pos[1])
                        currentBox.y = parseInt(pos[2])
                    }
                } else if (line.includes('大小:')) {
                    var size = line.match(/(\d+)\s*x\s*(\d+)/)
                    if (size) {
                        currentBox.width = parseInt(size[1])
                        currentBox.height = parseInt(size[2])
                    }
                }
            }

            if (currentBox.class) {
                boxes.push(currentBox)
            }

            console.log("📦 解析到的检测框:", JSON.stringify(boxes))

            // 更新画布上的检测框
            if (capturedImageContainer.visible) {
                detectionCanvas.updateDetectionBoxes(boxes)
            }

        } catch (error) {
            console.log("❌ 解析检测结果出错:", error)
        }
    }

    // 添加更新统计信息的函数
    function updateDetectionStats(result) {
        try {
            var objectCount = 0
            var totalConfidence = 0
            var processingTime = "0s"

            // 解析对象数量
            var objectMatches = result.match(/检测到 (\d+) 个目标/)
            if (objectMatches) {
                objectCount = parseInt(objectMatches[1])
            }

            // 解析处理时间
            var timeMatches = result.match(/处理时间: ([\d.]+)秒/)
            if (timeMatches) {
                processingTime = timeMatches[1] + "s"
            }

            // 解析置信度
            var confidenceMatches = result.match(/置信度: ([\d.]+)%/g)
            if (confidenceMatches && confidenceMatches.length > 0) {
                for (var i = 0; i < confidenceMatches.length; i++) {
                    var conf = confidenceMatches[i].match(/([\d.]+)%/)
                    if (conf) {
                        totalConfidence += parseFloat(conf[1])
                    }
                }
                var avgConfidence = Math.round(totalConfidence / confidenceMatches.length)
            } else {
                var avgConfidence = 0
            }

            // 更新UI
            objectCountText.text = objectCount.toString()
            avgConfidenceText.text = avgConfidence + "%"
            processingTimeText.text = processingTime

            console.log("📈 统计信息更新:", objectCount, avgConfidence + "%", processingTime)

        } catch (error) {
            console.log("❌ 更新统计信息出错:", error)
        }
    }
    // 提取置信度的函数（添加到页面底部）
    function extractConfidenceFromResult(result) {
        // 简单的置信度提取
        var match = result.match(/置信度:\s*(\d+\.?\d*)%/)
        if (match) {
            return parseFloat(match[1]) / 100.0
        }

        // 如果没找到，尝试提取平均值
        var matches = result.match(/置信度:\s*(\d+\.?\d*)%/g)
        if (matches && matches.length > 0) {
            var total = 0
            for (var i = 0; i < matches.length; i++) {
                var conf = matches[i].match(/(\d+\.?\d*)%/)
                if (conf) {
                    total += parseFloat(conf[1])
                }
            }
            return (total / matches.length) / 100.0
        }

        return 0.0
    }

}
