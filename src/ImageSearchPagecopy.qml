import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import FluentUI 1.0
import ImageSearch 1.0

Item {
    id: root

    // 存储选中的文件信息
    property string selectedFilePath: ""
    property string selectedFileName: ""
    property real selectedFileSize: 0

    // 搜索结果数据
    property bool searching: false
    property var searchResult: null
    property string errorMessage: ""

    ImageSearcher {
        id: imageSearcher

        onSearchCompleted: function(result) {
            searching = false
            searchResult = result
            showSuccess(qsTr("搜索完成！相似度: ") + result.similarity + "%")
        }

        onSearchFailed: function(error) {
            searching = false
            errorMessage = error
        }

        onSearchProgress: function(status) {
            console.log("搜索进度:", status)
        }
    }

    // 主滚动视图
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        contentWidth: availableWidth
        contentHeight: 1500  // 临时设置固定高度，确保能滚动
        // ScrollBar.vertical.policy:ScrollBar.AlwaysOn
        ColumnLayout {
            id: contentColumn // 1. 给 ColumnLayout 一个 id
            width: parent.width
            spacing: 20


            // 标题
            FluText {
                text: qsTr("以图搜图 - 文件上传测试")
                font.pixelSize: 24
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // 上传区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                color: FluTheme.dark ? "#2D2D30" : "#F8F9FA"
                border.color: selectedFilePath ? "#0078D4" : (FluTheme.dark ? "#404040" : "#E1E1E1")
                border.width: 2
                radius: 8

                // 虚线边框效果（当拖拽时）
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "transparent"
                    border.color: parent.border.color
                    border.width: 1
                    radius: 6
                    opacity: 0.5
                    visible: !selectedFilePath
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 15

                    // 上传图标
                    FluText {
                        text: selectedFilePath ? "✅" : "📁"
                        font.pixelSize: 48
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // 提示文字
                    FluText {
                        text: selectedFilePath ? qsTr("文件已选择") : qsTr("点击选择图片文件")
                        font.pixelSize: 16
                        color: selectedFilePath ? "#0078D4" : (FluTheme.dark ? "#CCCCCC" : "#666666")
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // 支持格式提示
                    FluText {
                        text: qsTr("支持: JPG, PNG, GIF, BMP")
                        font.pixelSize: 12
                        color: FluTheme.dark ? "#999999" : "#888888"
                        Layout.alignment: Qt.AlignHCenter
                        visible: !selectedFilePath
                    }
                }

                // 点击区域
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fileDialog.open()
                }
            }

            // 选择文件按钮
            FluFilledButton {
                text: qsTr("选择图片文件")
                Layout.alignment: Qt.AlignHCenter
                onClicked: fileDialog.open()
            }

            // 文件信息显示区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: FluTheme.dark ? "#1E1E1E" : "#FFFFFF"
                border.color: FluTheme.dark ? "#404040" : "#E1E1E1"
                border.width: 1
                radius: 8
                visible: selectedFilePath !== ""

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    FluText {
                        text: qsTr("文件信息")
                        font.pixelSize: 16
                        font.bold: true
                    }

                    RowLayout {
                        FluText {
                            text: qsTr("文件名:")
                            font.pixelSize: 14
                            color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            Layout.preferredWidth: 80
                        }
                        FluText {
                            text: selectedFileName
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }

                    RowLayout {
                        FluText {
                            text: qsTr("文件路径:")
                            font.pixelSize: 14
                            color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            Layout.preferredWidth: 80
                        }
                        FluText {
                            text: selectedFilePath
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            wrapMode: Text.Wrap
                        }
                    }

                    RowLayout {
                        FluText {
                            text: qsTr("文件大小:")
                            font.pixelSize: 14
                            color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            Layout.preferredWidth: 80
                        }
                        FluText {
                            text: formatFileSize(selectedFileSize)
                            font.pixelSize: 14
                        }
                    }
            }
        }

        // 图片预览区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(400, selectedFilePath ? 350 : 0)
            color: FluTheme.dark ? "#1E1E1E" : "#FFFFFF"
            border.color: FluTheme.dark ? "#404040" : "#E1E1E1"
            border.width: 1
            radius: 8
            visible: selectedFilePath !== ""

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                FluText {
                    text: qsTr("图片预览")
                    font.pixelSize: 16
                    font.bold: true
                }

                // 图片预览
                Image {
                    id: previewImage
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    source: selectedFilePath ? "file:///" + selectedFilePath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true

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
                        visible: previewImage.status === Image.Loading
                        width: 40
                        height: 40
                    }

                    // 加载失败提示
                    FluText {
                        anchors.centerIn: parent
                        text: qsTr("图片加载失败")
                        visible: previewImage.status === Image.Error
                        color: "#FF6B6B"
                    }
                }
            }
        }

        // 操作按钮区域
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            Layout.bottomMargin: 30
            spacing: 15
            visible: selectedFilePath !== ""

            FluButton {
                text: qsTr("重新选择")
                onClicked: fileDialog.open()
            }

            FluButton {
                text: qsTr("清除文件")
                onClicked: clearFile()
            }

            FluFilledButton {
                text: searching ? qsTr("搜索中...") : qsTr("开始以图搜图")
                enabled: !searching
                onClicked: {
                    if (selectedFilePath) {
                        startImageSearch()
                    }
                }
            }
        }

        // 搜索进度指示器
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            visible: searching

            FluProgressRing {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }

            FluText {
                text: qsTr("正在搜索相似图片...")
                font.pixelSize: 14
            }
        }

        // 错误信息显示
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#FFEBEE"
            border.color: "#F44336"
            border.width: 1
            radius: 8
            visible: errorMessage !== ""

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                FluText {
                    text: "❌"
                    font.pixelSize: 16
                }

                FluText {
                    text: errorMessage
                    font.pixelSize: 14
                    color: "#D32F2F"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                FluButton {
                    text: qsTr("关闭")
                    onClicked: errorMessage = ""
                }
            }
        }

        // 搜索结果显示区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: searchResult ? 500 : 0
            color: FluTheme.dark ? "#1E1E1E" : "#FFFFFF"
            border.color: FluTheme.dark ? "#404040" : "#E1E1E1"
            border.width: 1
            radius: 8
            visible: searchResult !== null

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                // 搜索结果标题
                RowLayout {
                    Layout.fillWidth: true

                    FluText {
                        text: qsTr("🎯 找到最相似的图片")
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 24
                        color: "#4CAF50"
                        radius: 12

                        FluText {
                            anchors.centerIn: parent
                            text: searchResult ? searchResult.similarity + "%" : "0%"
                            font.pixelSize: 12
                            color: "white"
                            font.bold: true
                        }
                    }
                }

                // 图片和信息水平布局
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    // 搜索结果图片
                    Rectangle {
                        Layout.preferredWidth: 400
                        Layout.preferredHeight: 300
                        Layout.fillWidth: true
                        color: "transparent"
                        border.color: "#E0E0E0"
                        border.width: 1
                        radius: 8

                        Flickable {
                            id: imageFlickable
                            anchors.fill: parent
                            anchors.margins: 2
                            clip: true

                            Image {
                                id: resultImage
                                source: searchResult ? parsePixivImageUrl(searchResult.imageUrl) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            contentWidth: resultImage.width * resultImage.scale
                            contentHeight: resultImage.height * resultImage.scale

                            // 鼠标滚轮缩放
                            MouseArea {
                                anchors.fill: parent
                                onWheel: {
                                    var delta = wheel.angleDelta.y / 120;
                                    if (delta > 0) {
                                        resultImage.scale = Math.min(resultImage.scale * 1.1, 3.0);
                                    } else {
                                        resultImage.scale = Math.max(resultImage.scale / 1.1, 0.5);
                                    }
                                }
                            }

                            // 滚动条
                            ScrollBar.vertical: ScrollBar { interactive: true }
                            ScrollBar.horizontal: ScrollBar { interactive: true }

                            FluProgressRing {
                                anchors.centerIn: parent
                                visible: resultImage.status === Image.Loading
                                width: 30
                                height: 30
                            }

                            FluText {
                                anchors.centerIn: parent
                                text: qsTr("图片加载失败")
                                visible: resultImage.status === Image.Error
                                color: "#FF6B6B"
                            }
                        }
                    }

                    // 详细信息
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 250
                        spacing: 12

                        RowLayout {
                            FluText {
                                text: qsTr("作品标题:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.title : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            FluText {
                                text: qsTr("作者:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.author : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            FluText {
                                text: qsTr("Pixiv ID:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.pixivId : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            FluText {
                                text: qsTr("相似度:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.similarity + "%" : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            FluText {
                                text: qsTr("分辨率:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.resolution : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            FluText {
                                text: qsTr("收藏数:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.bookmarks : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            FluText {
                                text: qsTr("浏览数:")
                                font.pixelSize: 12
                                Layout.preferredWidth: 70
                                color: FluTheme.dark ? "#CCCCCC" : "#666666"
                            }
                            FluText {
                                text: searchResult ? searchResult.views : qsTr("未知")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        // 操作按钮
                        RowLayout {
                            Layout.topMargin: 10
                            spacing: 10

                            FluButton {
                                text: qsTr("访问Pixiv")
                                onClicked: {
                                    if (searchResult && searchResult.pixivId) {
                                        Qt.openUrlExternally("https://www.pixiv.net/artworks/" + searchResult.pixivId)
                                    }
                                }
                            }

                            FluButton {
                                text: qsTr("下载原图")
                                onClicked: {
                                    if (searchResult && searchResult.originalUrl) {
                                        Qt.openUrlExternally(parsePixivImageUrl(searchResult.originalUrl))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }

    // 文件选择对话框
    FileDialog {
        id: fileDialog
        title: qsTr("选择图片文件")
        folder: "file:///C:/Users"
        nameFilters: [
            "图片文件 (*.jpg *.jpeg *.png *.gif *.bmp)",
            "所有文件 (*)"
        ]

        onAccepted: {
            var filePath = fileDialog.file.toString()
            if (filePath.startsWith("file:///")) {
                filePath = filePath.substring(8)
            } else if (filePath.startsWith("file://")) {
                filePath = filePath.substring(7)
            }

            selectedFilePath = filePath
            selectedFileName = filePath.split('/').pop().split('\\').pop()
            selectedFileSize = Math.random() * 5000000

            showSuccess(qsTr("文件选择成功: ") + selectedFileName)
        }

        onRejected: {
            showInfo(qsTr("已取消文件选择"))
        }
    }

    // 清除文件函数
    function clearFile() {
        selectedFilePath = ""
        selectedFileName = ""
        selectedFileSize = 0
        searchResult = null
        errorMessage = ""
        showInfo(qsTr("已清除选择的文件"))
    }

    // 格式化文件大小
    function formatFileSize(bytes) {
        if (bytes === 0) return "0 B"
        if (bytes < 1024) return bytes.toFixed(0) + " B"
        else if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        else if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + " MB"
        else return (bytes / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    // 开始图像搜索
    function startImageSearch() {
        if (!selectedFilePath) {
            errorMessage = qsTr("请先选择一个图片文件")
            return
        }

        searching = true
        errorMessage = ""
        searchResult = null

        // 调用C++后端进行真实的图像搜索
        imageSearcher.searchImage(selectedFilePath)
    }

    // 解析Pixiv图片URL，解决防盗链问题
    function parsePixivImageUrl(url) {
        if (!url) return ""
        return url.replace("i.pximg.net", "pixivic.lapu2023.workers.dev")
    }

    // 格式化数字
    function formatNumber(num) {
        if (!num) return "0"
        if (num < 1000) return num.toString()
        else if (num < 1000000) return (num / 1000).toFixed(1) + "K"
        else return (num / 1000000).toFixed(1) + "M"
    }
}
