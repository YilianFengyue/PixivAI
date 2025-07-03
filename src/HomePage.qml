import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import FluentUI 1.0
import Tools 1.0
import Qt.labs.platform 1.1
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
    //下载对话框
    FileDialog {
        id: saveDlg
        title: "保存壁纸到..."
        fileMode: FileDialog.SaveFile
        nameFilters: ["JPEG (*.jpg *.jpeg)", "PNG (*.png)", "所有文件 (*)"]

        onAccepted: {
            var path = file.toString()
            if (path.startsWith("file:///"))
                path = path.substring(8)

            var imageUrl = saveDlg.wallpaperUrl
            Downloader.download(imageUrl, path)
        }

        property string wallpaperUrl: ""
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


    Window {
        id: detailWindow
        width: 600
        height: 500
        title: qsTr("壁纸详情")
        modality: Qt.ApplicationModal

        property var wallpaperData: null

        Rectangle {
            anchors.fill: parent
            color: FluTheme.dark ? "#202020" : "#F5F5F5"

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
                    source: detailWindow.wallpaperData ? detailWindow.wallpaperData.path : ""

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "#E0E0E0"
                        border.width: 1
                        radius: 4
                    }
                }

                // 详细信息（简化版）
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "ID: " + (detailWindow.wallpaperData ? detailWindow.wallpaperData.id : "")
                        font.pixelSize: 12
                    }
                    Text {
                        text: "分辨率: " + (detailWindow.wallpaperData ? detailWindow.wallpaperData.resolution : "")
                        font.pixelSize: 12
                    }
                    Text {
                        text: "收藏: " + (detailWindow.wallpaperData ? detailWindow.wallpaperData.favorites : "0")
                        font.pixelSize: 12
                    }
                }

                // 按钮
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    FluFilledButton {
                        text: qsTr("下载原图")
                        onClicked: {
                            if (detailWindow.wallpaperData && detailWindow.wallpaperData.path) {
                                var filename = detailWindow.wallpaperData.id + "_" + detailWindow.wallpaperData.resolution + ".jpg"
                                saveDlg.currentFile = filename
                                saveDlg.wallpaperUrl = detailWindow.wallpaperData.path
                                saveDlg.open()
                            }
                        }
                    }
                    Connections {
                        target: Downloader
                        onSuccess: showSuccess("已保存: " + filePath)
                        onFailure: showError(reason)
                    }
                    FluButton {
                        text: qsTr("关闭")
                        onClicked: detailWindow.close()
                    }
                }
            }
        }
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
        detailWindow.wallpaperData = wallpaper
        detailWindow.show()
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
