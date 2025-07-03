import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenCVTest 1.0
import QtQuick.Dialogs
// 1. 使用 FluScrollerPage 作为页面的根组件

FluScrollablePage {
    id: root
    property string recognitionResult: "" // <--- 添加这一行
    property string selectedImagePath: ""
    property string imagePreviewSource: ""
    OpenCVTest {
        id: cvTest
    }
    // 文件选择对话框
    FileDialog {
        id: fileDialog
        title: "选择图片文件"
        nameFilters: ["图片文件 (*.png *.jpg *.jpeg *.bmp *.gif)"]
        onAccepted: {
            root.selectedImagePath = selectedFile.toString()
            root.imagePreviewSource = selectedFile.toString()
            showSuccess("图片选择成功: " + selectedFile.toString().split('/').pop())
        }
    }

    // 新增连接
    Connections {
        target: cvTest
        function onEnhancedClassificationFinished(result) {
            root.recognitionResult = result
            btnStartEnhancedRecognition.loading = false
        }
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
                height: 350  // 增加高度以容纳预览
                color: FluTheme.itemHoverColor
                radius: 12
                border.width: 2
                border.color: FluTheme.dividerColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15

                    // 图片预览区域
                    Rectangle {
                        width: parent.width
                        height: 200
                        color: FluTheme.backgroundColor
                        radius: 8
                        border.width: 1
                        border.color: FluTheme.dividerColor

                        Image {
                            id: imagePreview
                            anchors.centerIn: parent
                            width: parent.width - 20
                            height: parent.height - 20
                            fillMode: Image.PreserveAspectFit
                            source: root.imagePreviewSource
                            visible: root.imagePreviewSource !== ""

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 2
                                border.color: FluTheme.accentColor
                                radius: 4
                                visible: parent.visible
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            visible: root.imagePreviewSource === ""

                            FluText {
                                text: qsTr("📷")
                                font.pointSize: 36
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: FluTheme.fontTertiaryColor
                            }

                            FluText {
                                text: qsTr("点击选择图片进行AI识别")
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: FluTheme.fontTertiaryColor
                            }
                        }
                    }

                    // 操作按钮
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        FluFilledButton {
                            text: qsTr("选择图片")
                            onClicked: fileDialog.open()
                        }

                        FluLoadingButton {
                            id: btnStartEnhancedRecognition
                            text: qsTr("开始AI识别")
                            enabled: root.selectedImagePath !== ""

                            onClicked: {
                                if (root.selectedImagePath === "") {
                                    showWarning("请先选择图片")
                                    return
                                }

                                loading = true
                                root.recognitionResult = "正在进行AI识别，请稍候..."

                                // 根据选择的模式调用不同的识别方法
                                let mode = btnAnimeClassification.checked ? "anime" : "original"
                                cvTest.classifyImageEnhanced(root.selectedImagePath, mode)
                            }
                        }

                        FluButton {
                            text: qsTr("清空结果")
                            onClicked: {
                                root.recognitionResult = ""
                                showInfo("结果已清空")
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

                        FluToggleButton {
                            id: btnOriginalClassification
                            text: qsTr("🤖 通用识别")
                            checked: true // 默认选中
                            Layout.fillWidth: true
                            onClicked: {
                                if (checked) {
                                    btnAnimeClassification.checked = false
                                } else {
                                    checked = true
                                }
                            }
                        }

                        FluToggleButton {
                            id: btnAnimeClassification
                            text: qsTr("🎨 二次元识别")
                            Layout.fillWidth: true
                            onClicked: {
                                if (checked) {
                                    btnOriginalClassification.checked = false
                                } else {
                                    checked = true
                                }
                            }
                        }
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




        }
    }
}


