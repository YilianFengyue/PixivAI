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
    property string statusText: "" // 用于在加载时显示状态

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
        statusText = "任务已提交，正在排队...";
        showInfo(statusText);

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 201) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        // 根据你的Vue代码，假设返回的 result 是 taskId
                        if (response.result) {
                            taskId = response.result;
                            showSuccess("任务提交成功！ID: " + taskId);
                            // 开始轮询
                            startPolling();
                        } else {
                            showError("提交失败: " + (response.description || "未返回任务ID"));
                            isLoading = false;
                        }
                    } catch (e) {
                        showError("解析提交结果失败: " + e.message);
                        isLoading = false;
                    }
                } else {
                    showError("提交任务网络请求失败，状态码：" + xhr.status);
                    isLoading = false;
                }
            }
        };

        // 准备请求数据
        var params = {
            prompt: promptInput.text,
            botType: "MID_JOURNEY"
            // 你可以根据需要在这里添加 base64, notifyHook 等参数
        };

        xhr.open("POST", "https://api.gpt.ge/mj/submit/imagine", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + apiToken);
        xhr.send(JSON.stringify(params));
    }

    // 2. 开始轮询任务结果
    function startPolling() {
        if (!taskId) return;

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
        statusText = "正在获取任务进度...";
    }

    // 3. 获取任务结果
    function fetchTaskResult() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        statusText = "状态: " + response.status + " (" + response.progress + ")";

                        if (response.status === "SUCCESS") {
                            pollTimer.stop();
                            imageUrl = response.imageUrl;
                            showSuccess("图片生成成功！");
                            isLoading = false;
                        } else if (response.status === "FAILURE") {
                            pollTimer.stop();
                            showError("生成失败: " + response.failReason);
                            isLoading = false;
                        }
                        // 如果是 IN_PROGRESS 或 NOT_START，则继续轮询
                    } catch (e) {
                        pollTimer.stop();
                        showError("解析轮询结果失败: " + e.message);
                        isLoading = false;
                    }
                } else {
                    pollTimer.stop();
                    showError("查询任务状态失败，状态码：" + xhr.status);
                    isLoading = false;
                }
            }
        };

        xhr.open("GET", "https://api.gpt.ge/mj/task/" + taskId + "/fetch", true);
        xhr.setRequestHeader("Authorization", "Bearer " + apiToken);
        xhr.send();
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
        Layout.fillHeight: true
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
                    text: "1girl, solo, long hair, looking at viewer, upper body, masterpiece, best quality"
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
                    text: "lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry"
                }

                Item { Layout.fillHeight: true } // 弹簧，把按钮推到底部

                FluFilledButton {
                    Layout.fillWidth: true
                    text: isLoading ? "生成中..." : "生成图片"
                    enabled: !isLoading
                    onClicked: submitTask()
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

            // 初始提示或最终图片
            FluImage {
                anchors.fill: parent
                anchors.margins: 10
                source: imageUrl
                fillMode: Image.PreserveAspectFit
                visible: !isLoading && imageUrl !== ""
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
            }


            // 加载动画
            Rectangle {
                anchors.fill: parent
                color: "#80000000" // 半透明遮罩
                visible: isLoading

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20

                    FluProgressRing {
                        // active: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    FluText {
                        text: statusText
                        color: "white"
                        font: FluTextStyle.BodyStrong
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
