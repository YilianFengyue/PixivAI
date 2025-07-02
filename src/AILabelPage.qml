import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenCVTest 1.0

// 1. 使用 FluScrollerPage 作为页面的根组件

FluScrollablePage {
    id: root
    property string recognitionResult: "" // <--- 添加这一行

    OpenCVTest {
        id: cvTest
    }
    RowLayout {

        width: parent.width
        spacing: 30


        Column {
            Layout.preferredWidth: parent.width * 0.6
            spacing: 20

            // 页面标题
            Row {
                spacing: 15
                Image {
                        width: 60
                        height: 60
                        source: "qrc:/Icons/IxAi.png"
                        Layout.alignment: Qt.AlignVCenter
                    }
                // FluText {
                //     text: qsTr("🏷️")
                //     font.pointSize: 32
                //     anchors.verticalCenter: parent.verticalCenter
                //     color: FluTheme.accentColor
                // }

                Column {
                    spacing: 5

                    FluText {
                        text: qsTr("AI 标签识别")
                        font: FluTextStyle.Title
                    }

                    FluText {
                        text: qsTr("智能识别图片内容，生成标签")
                        color: FluTheme.fontSecondaryColor
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: FluTheme.dividerColor
            }

            // AI处理区域
            Rectangle {
                width: parent.width
                height: 250
                color: FluTheme.itemHoverColor
                radius: 12
                border.width: 2
                border.color: FluTheme.dividerColor

                Column {
                    anchors.centerIn: parent
                    spacing: 15

                    FluText {
                        text: qsTr("🤖")
                        font.pointSize: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: FluTheme.accentColor
                    }

                    FluText {
                        text: qsTr("AI 图像识别区域")
                        anchors.horizontalCenter: parent.horizontalCenter
                        font: FluTextStyle.Body
                    }

                    FluText {
                        text: qsTr("支持物体检测、场景分析、文字识别")
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: FluTheme.fontSecondaryColor
                        font.pointSize: 10
                    }

                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        FluFilledButton {
                            text: qsTr("选择图片")
                            onClicked: {
                                showInfo(qsTr("选择图片功能待开发..."))
                            }
                        }

                        FluButton {
                            text: qsTr("使用摄像头")
                            onClicked: {
                                showInfo(qsTr("摄像头功能待开发..."))
                            }
                        }

                        FluLoadingButton {
                            id: btnStartRecognition
                            text: qsTr("AI识别演示")

                            onClicked: {
                                loading = true; // 进入加载状态
                                root.recognitionResult = "正在调用AI进行识别，请稍候...";
                                cvTest.classifyImage("C:\\Users\\123\\Desktop\\68189098_p0_master1200.jpg");
                            }
                        }
                        Connections {
                            target: cvTest
                            function onClassificationFinished(result) {
                                root.recognitionResult = result;
                                btnStartRecognition.loading = false; // 停止加载
                            }
                        }
                        FluButton {
                            text: qsTr("清空结果")
                            onClicked: {
                                root.recognitionResult = "" // <--- 添加这一行
                                showInfo(qsTr("结果已清空"))
                            }
                        }
                        FluButton {
                            text: "测试OpenCV"
                            onClicked: {
                                showInfo("OpenCV版本: " + cvTest.getOpenCVVersion())
                                showSuccess("OpenCV测试: " + (cvTest.testOpenCV() ? "成功" : "失败"))
                            }
                        }
                    }
                }
            }

            FluGroupBox {
                title: qsTr("识别模式")
                width: parent.width

                // 内部使用ColumnLayout来容纳GridLayout，可以更好地控制边距
                ColumnLayout {
                    anchors.fill: parent

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 15
                        rowSpacing: 8

                        // 为了实现互斥，我们需要给每个按钮一个唯一的ID
                        FluToggleButton {
                            id: btnObjectDetection
                            text: qsTr("🎯 物体检测")
                            checked: true // 默认选中第一个
                            Layout.fillWidth: true
                            onClicked: {
                                if (checked) {
                                    // 当此按钮被选中时，取消其他按钮的选中状态
                                    btnFaceRecognition.checked = false
                                    btnTextRecognition.checked = false
                                    btnSceneAnalysis.checked = false
                                } else {
                                    // 防止用户取消选中最后一个选项，确保至少有一个被选中
                                    checked = true
                                }
                            }
                        }




                        FluToggleButton {
                            id: btnFaceRecognition
                            Layout.fillWidth: true // 让按钮填满单元格宽度
                            onClicked: {
                                if (checked) {
                                    btnObjectDetection.checked = false
                                    btnTextRecognition.checked = false
                                    btnSceneAnalysis.checked = false
                                } else {
                                    checked = true
                                }
                            }

                            // 使用 RowLayout 来水平排列图标和文字
                            RowLayout {
                                anchors.centerIn: parent // 让布局在按钮内部居中
                                spacing: 8               // 图标和文字之间的间距

                                FluIcon {
                                    iconSource: FluentIcons.People
                                    font.pointSize: 16 // 调整一个适合按钮的图标大小
                                    // 这里我将颜色绑定到了按钮自身的选中状态 (checked)
                                    color: btnFaceRecognition.checked ? "white" : FluTheme.fontSecondaryColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                FluText {
                                    // 注意，我们把文字放到了独立的 FluText 组件中
                                    text: qsTr("人脸识别") // 移除了 emoji，因为我们有了图标
                                    color: btnFaceRecognition.checked ? "white" : FluTheme.fontSecondaryColor
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        FluToggleButton {
                            id: btnTextRecognition
                            text: qsTr("📝 文字识别")
                            Layout.fillWidth: true
                            onClicked: {
                                if (checked) {
                                    btnObjectDetection.checked = false
                                    btnFaceRecognition.checked = false
                                    btnSceneAnalysis.checked = false
                                } else {
                                    checked = true
                                }
                            }
                        }

                        FluToggleButton {
                            id: btnSceneAnalysis
                            text: qsTr("🏞️ 场景分析")
                            Layout.fillWidth: true
                            onClicked: {
                                if (checked) {
                                    btnObjectDetection.checked = false
                                    btnFaceRecognition.checked = false
                                    btnTextRecognition.checked = false
                                } else {
                                    checked = true
                                }
                            }
                        }
                    }
                }
            }

            // 处理按钮
            Row {
                spacing: 10

                FluFilledButton {
                    text: qsTr("开始识别")
                    onClicked: {
                        showSuccess(qsTr("AI识别功能待开发..."))
                    }
                }

                FluButton {
                    text: qsTr("清空结果")
                    onClicked: {
                        showInfo(qsTr("结果已清空"))
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
                text: qsTr("识别结果")
                font: FluTextStyle.Subtitle
            }
            FluMultilineTextBox {
                width: parent.width
                Layout.fillHeight: true // 让它填满剩余的高度
                readOnly: true
                wrapMode: TextEdit.Wrap
                text: root.recognitionResult // <--- 核心绑定！
                placeholderText: "点击左侧“AI识别演示”按钮开始..."
            }
            // 检测结果
            Rectangle {
                width: parent.width
                height: 150
                color: FluTheme.itemHoverColor
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    FluText {
                        text: qsTr("检测到的物体:")
                        font: FluTextStyle.BodyStrong
                    }

                    FluText { text: qsTr("• 🐱 猫咪 (95%)") }
                    FluText { text: qsTr("• 🪑 椅子 (87%)") }
                    FluText { text: qsTr("• 📚 书本 (82%)") }
                }
            }

            // 文字识别结果
            Rectangle {
                width: parent.width
                height: 100
                color: FluTheme.itemHoverColor
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    FluText {
                        text: qsTr("文字识别(OCR):")
                        font: FluTextStyle.BodyStrong
                    }

                    FluText {
                        text: qsTr("识别出的文字内容...")
                        color: FluTheme.fontSecondaryColor
                    }
                }
            }

            // 操作按钮
            Column {
                width: parent.width
                spacing: 8

                FluButton {
                    width: parent.width
                    text: qsTr("📋 复制结果")
                    onClicked: {
                        showSuccess(qsTr("结果已复制"))
                    }
                }

                FluButton {
                    width: parent.width
                    text: qsTr("💾 保存报告")
                    onClicked: {
                        showSuccess(qsTr("报告已保存"))
                    }
                }
            }
        }
    }
}


