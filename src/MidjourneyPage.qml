import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0

// 使用 FluScrollablePage 可以确保在内容过多时页面能够滚动
FluScrollablePage {
    id: root

    // --- 全局状态和配置 ---

    // API Token, 请替换为你自己的
    property string apiToken: "sk-ftFsTsD8xhyYaQ8RA804A22c53934a4e8681F041F0E146Ba"

    // 状态属性
    property bool isLoading: false
    property string taskId: ""
    property string imageUrl: "" // 用于显示最终生成的图片
    property string statusText: "等待开始..." // 用于在加载时显示状态
    property int pollCount: 0 // 轮询计数器

    // 用于轮询的计时器
    property var pollTimer: null

    // --- API 调用函数 ---

    // 1. 提交生成任务
    function submitTask() {
        if (isLoading) return;
        if (promptInput.text.trim() === "") {
            showError("提示词不能为空");
            return;
        }

        // 重置状态
        isLoading = true;
        imageUrl = "";
        taskId = "";
        pollCount = 0;
        statusText = "正在提交任务...";
        console.log("开始提交任务...");

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("提交请求完成，状态码:", xhr.status);
                console.log("响应内容:", xhr.responseText);

                if (xhr.status === 200 || xhr.status === 201) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        console.log("解析后的响应:", JSON.stringify(response));

                        // 根据你的Vue代码，假设返回的 result 是 taskId
                        if (response.result) {
                            taskId = response.result;
                            statusText = "任务提交成功，开始轮询...";
                            showSuccess("任务提交成功！ID: " + taskId);
                            console.log("任务ID:", taskId);
                            // 开始轮询
                            startPolling();
                        } else {
                            showError("提交失败: " + (response.description || "未返回任务ID"));
                            isLoading = false;
                            statusText = "提交失败";
                        }
                    } catch (e) {
                        console.error("解析提交结果失败:", e.message);
                        showError("解析提交结果失败: " + e.message);
                        isLoading = false;
                        statusText = "解析失败";
                    }
                } else {
                    console.error("提交任务网络请求失败，状态码：", xhr.status);
                    showError("提交任务网络请求失败，状态码：" + xhr.status);
                    isLoading = false;
                    statusText = "网络请求失败";
                }
            }
        };

        // 准备请求数据
        var params = {
            prompt: promptInput.text,
            botType: "MID_JOURNEY"
            // 你可以根据需要在这里添加 base64Array, notifyHook 等参数
        };

        console.log("发送请求参数:", JSON.stringify(params));
        xhr.open("POST", "https://api.gpt.ge/mj/submit/imagine", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + apiToken);
        xhr.send(JSON.stringify(params));
    }

    // 2. 开始轮询任务结果
    function startPolling() {
        if (!taskId) {
            console.error("无效的taskId");
            return;
        }

        console.log("开始轮询任务:", taskId);

        // 如果已存在计时器，先停止
        if (pollTimer) {
            pollTimer.stop();
            pollTimer.destroy();
        }

        // 创建一个新的计时器
        pollTimer = Qt.createQmlObject('import QtQuick 2.0; Timer {}', root);
        pollTimer.interval = 5000; // 每5秒查询一次
        pollTimer.repeat = true;
        pollTimer.triggered.connect(fetchTaskResult);
        pollTimer.start();
        statusText = "正在生成图片，请耐心等待...";

        // 立即执行一次查询
        fetchTaskResult();
    }

    // 3. 获取任务结果
    function fetchTaskResult() {
        pollCount++;
        console.log("第", pollCount, "次轮询，taskId:", taskId);

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("轮询请求完成，状态码:", xhr.status);
                console.log("轮询响应内容:", xhr.responseText);

                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        console.log("轮询解析后的响应:", JSON.stringify(response));

                        var progress = response.progress || "未知";
                        statusText = "状态: " + response.status + " | 进度: " + progress + " | 轮询次数: " + pollCount;

                        if (response.status === "SUCCESS") {
                            console.log("任务成功完成！");
                            if (pollTimer) {
                                pollTimer.stop();
                                pollTimer.destroy();
                                pollTimer = null;
                            }

                            if (response.imageUrl) {
                                imageUrl = response.imageUrl;
                                console.log("获取到图片URL:", imageUrl);
                                showSuccess("图片生成成功！");
                                statusText = "图片生成完成！";
                            } else {
                                console.error("成功响应但没有imageUrl");
                                showError("成功但未返回图片URL");
                                statusText = "未返回图片URL";
                            }
                            isLoading = false;

                        } else if (response.status === "FAILURE") {
                            console.error("任务失败:", response.failReason);
                            if (pollTimer) {
                                pollTimer.stop();
                                pollTimer.destroy();
                                pollTimer = null;
                            }
                            showError("生成失败: " + (response.failReason || "未知错误"));
                            isLoading = false;
                            statusText = "任务失败";

                        } else {
                            // 如果是 IN_PROGRESS、NOT_START 等状态，继续轮询
                            console.log("任务进行中，继续轮询...");
                            // 防止无限轮询，设置最大轮询次数
                            if (pollCount > 120) { // 最多轮询10分钟
                                if (pollTimer) {
                                    pollTimer.stop();
                                    pollTimer.destroy();
                                    pollTimer = null;
                                }
                                showError("轮询超时，请重试");
                                isLoading = false;
                                statusText = "轮询超时";
                            }
                        }
                    } catch (e) {
                        console.error("解析轮询结果失败:", e.message);
                        if (pollTimer) {
                            pollTimer.stop();
                            pollTimer.destroy();
                            pollTimer = null;
                        }
                        showError("解析轮询结果失败: " + e.message);
                        isLoading = false;
                        statusText = "解析失败";
                    }
                } else {
                    console.error("查询任务状态失败，状态码：", xhr.status);
                    if (pollTimer) {
                        pollTimer.stop();
                        pollTimer.destroy();
                        pollTimer = null;
                    }
                    showError("查询任务状态失败，状态码：" + xhr.status);
                    isLoading = false;
                    statusText = "查询失败";
                }
            }
        };

        xhr.open("GET", "https://api.gpt.ge/mj/task/" + taskId + "/fetch", true);
        xhr.setRequestHeader("Authorization", "Bearer " + apiToken);
        xhr.send();
    }

    // 停止轮询
    function stopPolling() {
        if (pollTimer) {
            pollTimer.stop();
            pollTimer.destroy();
            pollTimer = null;
        }
        isLoading = false;
        statusText = "已停止";
    }

    // --- 页面布局 ---
    padding: 20
    spacing: 20

    // 标题
    FluText {
        text: "AI 绘图 (MidJourney)"
        font: FluTextStyle.Title
        Layout.fillWidth: true
    }

    // 主内容区：左右分栏
    RowLayout {
        Layout.fillWidth: true
        // Layout.fillHeight: true
        Layout.preferredHeight: 680
        spacing: 20

        // --- 左侧：控制面板 ---
        Rectangle {
            id: controlPanel
            Layout.fillHeight: true
            Layout.preferredWidth: 400 // 左侧面板固定宽度
            Layout.maximumWidth: parent.width * 0.4
            color: FluTheme.cardBackgroundFillColorDefault
            radius: 8
            border.color: FluTheme.cardStrokeColorDefault

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                FluText {
                    text: "参数设置"
                    font: FluTextStyle.Subtitle
                }

                FluText {
                    text: "正向提示词 (Prompt)"
                    font: FluTextStyle.BodyStrong
                }

                FluMultilineTextBox {
                    id: promptInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    placeholderText: "例如：A cute cat, cinematic lighting, ultra realistic, 8k"
                    text: "a beautiful landscape with mountains and lakes, sunset, ultra realistic, 8k"
                }

                FluText {
                    text: "反向提示词 (Negative Prompt)"
                    font: FluTextStyle.BodyStrong
                }

                FluMultilineTextBox {
                    id: negativePromptInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    placeholderText: "例如：low quality, worst quality, bad hands, extra fingers"
                    text: "lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality"
                }

                // 状态显示
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: FluTheme.cardBackgroundFillColorSecondary
                    radius: 4
                    border.color: FluTheme.cardStrokeColorDefault

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        FluText {
                            text: "当前状态"
                            font: FluTextStyle.BodyStrong
                        }

                        FluText {
                            text: statusText
                            color: isLoading ? FluTheme.accentColor : FluTheme.fontPrimaryColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Item { Layout.fillHeight: true } // 弹簧，把按钮推到底部

                // 按钮组
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    FluFilledButton {
                        Layout.fillWidth: true
                        text: isLoading ? "生成中..." : "生成图片"
                        enabled: !isLoading
                        onClicked: submitTask()
                    }

                    FluButton {
                        Layout.fillWidth: true
                        text: "停止生成"
                        enabled: isLoading
                        onClicked: stopPolling()
                    }
                }
            }
        }

        // --- 右侧：图片预览区 ---
        Rectangle {
            id: imagePanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: FluTheme.cardBackgroundFillColorDefault
            radius: 8
            border.color: FluTheme.cardStrokeColorDefault
            clip: true // 裁剪子元素，防止溢出

            // 使用普通的Image组件而不是FluImage，因为FluImage可能不支持网络图片
            Image {
                id: generatedImage
                anchors.fill: parent
                anchors.margins: 10
                source: imageUrl
                fillMode: Image.PreserveAspectFit
                visible: !isLoading && imageUrl !== ""
                asynchronous: true // 异步加载
                cache: true // 启用缓存

                onStatusChanged: {
                    if (status === Image.Ready) {
                        console.log("图片加载成功:", source);
                    } else if (status === Image.Error) {
                        console.error("图片加载失败:", source);
                        showError("图片加载失败，请检查网络连接");
                    } else if (status === Image.Loading) {
                        console.log("正在加载图片...");
                    }
                }

                // 添加鼠标区域，支持点击查看大图
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (imageUrl !== "") {
                            Qt.openUrlExternally(imageUrl);
                        }
                    }
                    cursorShape: imageUrl !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            // 初始状态提示
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: !isLoading && imageUrl === ""

                FluIcon {
                    iconSource: FluentIcons.Picture
                    iconSize: 48
                    Layout.alignment: Qt.AlignHCenter
                    color: FluTheme.fontSecondaryColor
                }

                FluText {
                    text: "请在左侧输入提示词开始创作"
                    color: FluTheme.fontSecondaryColor
                    Layout.alignment: Qt.AlignHCenter
                }

                FluText {
                    text: "生成的图片将在这里显示"
                    color: FluTheme.fontTertiaryColor
                    font: FluTextStyle.Caption
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // 加载动画和状态
            Rectangle {
                anchors.fill: parent
                color: "#80000000" // 半透明遮罩
                visible: isLoading

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20

                    FluProgressRing {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    FluText {
                        text: statusText
                        color: "white"
                        font: FluTextStyle.BodyStrong
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Layout.maximumWidth: 300
                    }

                    // 轮询计数显示
                    FluText {
                        text: pollCount > 0 ? "轮询次数: " + pollCount : ""
                        color: "lightgray"
                        font: FluTextStyle.Caption
                        Layout.alignment: Qt.AlignHCenter
                        visible: pollCount > 0
                    }
                }
            }
        }
    }

    // 页面销毁时清理资源
    Component.onDestruction: {
        if (pollTimer) {
            pollTimer.stop();
            pollTimer.destroy();
        }
    }
}
