import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import FluentUI 1.0

// Wallhaven壁纸浏览器主窗口
FluScrollablePage {
    id: wallhavenPage // 给根组件一个新的ID
    // 数据模型
    property string apiKey: "ngu8x5HHfVEspeRqjpPzlKSahsDCdeD0"
    property string currentQuery: "landscape"
    property int perPage: 24
    property int currentPage: 1
    property bool loading: false

    // 壁纸数据列表
    ListModel {
        id: wallpaperModel
    }

    // 主布局
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // 顶部搜索栏
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: qsTr("搜索词：")
                font.pixelSize: 14
            }

            FluTextBox {
                id: searchBox
                Layout.preferredWidth: 500
                // Layout.fillWidth: true
                placeholderText: qsTr("输入搜索关键词（如：arknights, anime, landscape）")
                text: currentQuery
                onAccepted: searchWallpapers()
            }

            FluText {
                text: qsTr("每页：")
                font.pixelSize: 14
            }

            FluSpinBox {
                id: perPageSpinBox
                from: 10
                to: 48
                value: perPage
                onValueChanged: perPage = value
            }

            FluFilledButton {
                text: qsTr("搜索")
                enabled: !loading
                onClicked: searchWallpapers()
            }
        }

        // 加载指示器
        RowLayout {
            Layout.fillWidth: true
            visible: loading

            FluProgressRing {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }

            FluText {
                text: qsTr("正在加载壁纸...")
                font.pixelSize: 14
            }
        }

        // 壁纸网格
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 600
            clip: true

            GridView {
                id: wallpaperGrid
                anchors.fill: parent
                model: wallpaperModel
                cellWidth: 280
                cellHeight: 200

                delegate: Rectangle {
                    width: wallpaperGrid.cellWidth - 10
                    height: wallpaperGrid.cellHeight - 10
                    radius: 8
                    color: FluTheme.dark ? "#2D2D30" : "#F3F3F3"
                    border.color: FluTheme.dark ? "#404040" : "#E0E0E0"
                    border.width: 1

                    // 鼠标悬停效果
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: parent.scale = 1.05
                        onExited: parent.scale = 1.0
                        onClicked: showWallpaperDetail(model)
                    }

                    // 缩略图
                    Image {
                        id: thumbnail
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        height: parent.height - 60
                        fillMode: Image.PreserveAspectCrop
                        source: model.thumbs ? model.thumbs.large : ""

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#E0E0E0"
                            border.width: 1
                            radius: 4
                        }

                        // 加载指示器
                        FluProgressRing {
                            anchors.centerIn: parent
                            visible: thumbnail.status === Image.Loading
                            width: 30
                            height: 30
                        }
                    }

                    // 信息栏
                    ColumnLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        spacing: 2

                        FluText {
                            text: model.resolution || ""
                            font.pixelSize: 12
                            color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            FluText {
                                text: "❤ " + (model.favorites || 0)
                                font.pixelSize: 11
                                color: "#FF6B6B"
                            }

                            FluText {
                                text: "👁 " + (model.views || 0)
                                font.pixelSize: 11
                                color: FluTheme.dark ? "#CCCCCC" : "#999999"
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // 动画效果
                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        // 底部分页控制
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            FluButton {
                text: qsTr("上一页")
                enabled: currentPage > 1 && !loading
                onClicked: {
                    currentPage--
                    searchWallpapers()
                }
            }

            FluText {
                text: qsTr("第 %1 页").arg(currentPage)
                font.pixelSize: 14
            }

            FluButton {
                text: qsTr("下一页")
                enabled: !loading
                onClicked: {
                    currentPage++
                    searchWallpapers()
                }
            }
        }
    }

    // 详情对话框
    FluContentDialog {
        id: detailDialog
        title: qsTr("壁纸详情")

        property var wallpaperData: null

        contentDelegate: Component {
            Item {
                width: 600
                height: 500

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    // 大图预览
                    Image {
                        id: fullImage
                        Layout.fillWidth: true
                        Layout.preferredHeight: 300
                        fillMode: Image.PreserveAspectFit
                        source: detailDialog.wallpaperData ? detailDialog.wallpaperData.path : ""

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#E0E0E0"
                            border.width: 1
                            radius: 4
                        }

                        FluProgressRing {
                            anchors.centerIn: parent
                            visible: fullImage.status === Image.Loading
                            width: 40
                            height: 40
                        }
                    }

                    // 详细信息
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 10

                            RowLayout {
                                FluText {
                                    text: "ID:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? detailDialog.wallpaperData.id : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                FluText {
                                    text: "分辨率:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? detailDialog.wallpaperData.resolution : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                FluText {
                                    text: "文件大小:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? formatFileSize(detailDialog.wallpaperData.file_size) : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                FluText {
                                    text: "收藏数:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? detailDialog.wallpaperData.favorites : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                FluText {
                                    text: "浏览数:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? detailDialog.wallpaperData.views : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                FluText {
                                    text: "创建时间:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? detailDialog.wallpaperData.created_at : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }

                            RowLayout {
                                FluText {
                                    text: "来源:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                    color: FluTheme.dark ? "#CCCCCC" : "#666666"
                                }
                                FluText {
                                    text: detailDialog.wallpaperData ? (detailDialog.wallpaperData.source || "无") : ""
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }

                            // 颜色标签
                            RowLayout {
                                FluText {
                                    text: "主要颜色:"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                }

                                RowLayout {
                                    Repeater {
                                        model: detailDialog.wallpaperData ? detailDialog.wallpaperData.colors : []
                                        Rectangle {
                                            width: 20
                                            height: 20
                                            color: modelData
                                            radius: 3
                                            border.color: "#CCCCCC"
                                            border.width: 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        positiveText: qsTr("下载原图")
        onPositiveClicked: {
            if (wallpaperData && wallpaperData.path) {
                Qt.openUrlExternally(wallpaperData.path)
            }
        }

        negativeText: qsTr("关闭")
        buttonFlags: FluContentDialogType.NegativeButton | FluContentDialogType.PositiveButton
    }

    // 搜索壁纸函数
    function searchWallpapers() {
        if (loading) return

        loading = true
        currentQuery = searchBox.text.trim() || "arknights"

        var xhr = new XMLHttpRequest()
        var url = "https://wallhaven.cc/api/v1/search?apikey=" + apiKey +
                  "&q=" + encodeURIComponent(currentQuery) +
                  "&categories=100&purity=100&page=" + currentPage +
                  "&per_page=" + perPage + "&sorting=favorites"

        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        if (currentPage === 1) {
                            wallpaperModel.clear()
                        }

                        for (var i = 0; i < response.data.length; i++) {
                            wallpaperModel.append(response.data[i])
                        }

                        if (response.data.length === 0) {
                            showInfo(qsTr("没有找到相关壁纸"))
                        }
                    } catch (e) {
                        showError(qsTr("解析数据失败：") + e.message)
                    }
                } else {
                    showError(qsTr("网络请求失败，状态码：") + xhr.status)
                }
            }
        }
        xhr.send()
    }

    // 显示壁纸详情
    function showWallpaperDetail(wallpaper) {
        detailDialog.wallpaperData = wallpaper
        detailDialog.open()
    }

    // 格式化文件大小
    function formatFileSize(bytes) {
        if (!bytes) return "未知"
        if (bytes < 1024) return bytes + " B"
        else if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        else if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + " MB"
        else return (bytes / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    // 窗口加载完成后自动搜索
    Component.onCompleted: {
        searchWallpapers()
    }
}
