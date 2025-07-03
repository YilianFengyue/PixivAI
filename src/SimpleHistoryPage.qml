import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0

FluScrollablePage {
    id: root

    property var records: []

    Component.onCompleted: {
        loadRecords()
    }

    ColumnLayout {
        width: parent.width
        spacing: 20

        // 标题
        Row {
            spacing: 15

            FluIcon {
                iconSource: FluentIcons.History
                font.pointSize: 28
                color: FluTheme.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                FluText {
                    text: "检测历史"
                    font: FluTextStyle.Title
                }
                FluText {
                    text: "共 " + records.length + " 条记录"
                    color: FluTheme.fontSecondaryColor
                }
            }
        }

        // 操作按钮
        Row {
            spacing: 10

            FluButton {
                text: "🔄 刷新"
                onClicked: loadRecords()
            }

            FluButton {
                text: "🧪 测试保存"
                onClicked: testSave()
            }

            FluButton {
                text: "🗑️ 清空全部"
                onClicked: {
                    simpleDB.clearAll()
                    loadRecords()
                    showSuccess("已清空所有记录")
                }
            }
        }

        // 记录列表
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 500
            model: records
            spacing: 8
            clip: true

            delegate: Rectangle {
                width: parent.width
                height: 80
                color: FluTheme.itemHoverColor
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 15

                    // 类型图标
                    Rectangle {
                        width: 50
                        height: 50
                        color: modelData.type === "classification" ? "#4CAF50" : "#2196F3"
                        radius: 25

                        FluIcon {
                            anchors.centerIn: parent
                            iconSource: modelData.type === "classification" ?
                                FluentIcons.Tag : FluentIcons.Search
                            color: "white"
                        }
                    }

                    // 主要信息
                    Column {
                        width: parent.width - 200
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        FluText {
                            text: modelData.imageName || "未知文件"
                            font: FluTextStyle.BodyStrong
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        FluText {
                            text: modelData.typeText
                            color: FluTheme.fontSecondaryColor
                            font.pointSize: 10
                        }

                        Row {
                            spacing: 10
                            FluText {
                                text: "置信度: " + modelData.confidenceText
                                color: FluTheme.accentColor
                                font.pointSize: 10
                            }
                            FluText {
                                text: modelData.createdAt
                                color: FluTheme.fontSecondaryColor
                                font.pointSize: 10
                            }
                        }
                    }

                    // 删除按钮
                    FluButton {
                        text: "删除"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            simpleDB.deleteRecord(modelData.id)
                            loadRecords()
                            showSuccess("删除成功")
                        }
                    }
                }
            }

            // 空状态
            Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: "暂无记录"
                color: FluTheme.fontSecondaryColor
                font.pointSize: 16
            }
        }
    }

    // 加载记录
    function loadRecords() {
        console.log("📋 加载历史记录...")
        records = simpleDB.getAllRecords()
        console.log("✅ 加载了", records.length, "条记录")
    }

    // 测试保存
    function testSave() {
        console.log("🧪 测试保存记录...")

        var success = simpleDB.saveRecord(
            "C:/test_" + Date.now() + ".jpg",
            "object_detection",
            "测试检测结果：发现了一只猫",
            0.85
        )

        if (success) {
            showSuccess("测试保存成功")
            loadRecords() // 重新加载
        } else {
            showError("测试保存失败")
        }
    }
}
