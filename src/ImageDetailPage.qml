import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0

Item {
    id: root

    // --- 全局状态和函数 ---
    property string proxyUrl: "https://pixivic.lapu2023.workers.dev/"
    property bool isLoading: false
    property var illustData: null

    function searchIllust(id) {
        if(!id || id.trim() === ""){
            showError("请输入有效的作品ID");
            return;
        }
        isLoading = true;
        illustData = null;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isLoading = false;
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        if (response.illust) {
                            illustData = response.illust;
                            showSuccess("作品加载成功！");
                        } else {
                            showError("未找到该作品");
                        }
                    } catch (e) {
                        showError("数据解析错误：" + e.message);
                    }
                } else {
                    showError("网络请求失败，状态码：" + xhr.status);
                }
            }
        };
        var url = "https://api.obfs.dev/api/pixiv/illust?id=" + encodeURIComponent(id);
        xhr.open("GET", url, true);
        xhr.send();
    }

    function getProxyImageUrl(originalUrl) {
        if (!originalUrl) return "";
        return proxyUrl + originalUrl.replace("https://i.pximg.net/", "");
    }

    function formatDate(dateString) {
        if (!dateString) return "";
        var date = new Date(dateString);
        return date.toLocaleDateString() + " " + date.toLocaleTimeString();
    }

    // --- 主体内容 ---
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // 1. 顶部搜索区域
        Rectangle {
            Layout.fillWidth: true
            height: 100
            color: FluTheme.cardBackgroundFillColorDefault
            radius: 8
            border.color: FluTheme.cardStrokeColorDefault

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Image {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    source: "qrc:/pixiv.png"
                }
                FluText {
                    text: "Pixiv 图片详情"
                    font: FluTextStyle.TitleLarge
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true } // 弹簧，把搜索框推到右边
                FluTextBox {
                    id: idInput
                    Layout.preferredWidth: 300
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "输入作品ID, 如: 51678256"
                    onAccepted: searchButton.clicked()
                }
                FluFilledButton {
                    id: searchButton
                    Layout.alignment: Qt.AlignVCenter
                    text: isLoading ? "搜索中..." : "搜索"
                    enabled: !isLoading
                    onClicked: searchIllust(idInput.text)
                }
            }
        }

        // 2. 结果显示区域 (双栏布局的核心)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent" // 父容器透明
            visible: illustData !== null || isLoading

            FluProgressRing {
                anchors.centerIn: parent
                visible: isLoading
                // active: isLoading
            }

            // --- 双栏布局从这里开始 ---
            RowLayout {
                anchors.fill: parent
                spacing: 20
                visible: !isLoading && illustData !== null

                // --- 左侧主内容栏 ---
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width * 0.6 // 占据60%宽度
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.width*3 // 减去margins和spacing
                        spacing: 20

                        // 作品标题
                        FluText {
                            Layout.fillWidth: true
                            text: illustData ? illustData.title : ""
                            font: FluTextStyle.Title
                            wrapMode: Text.WordWrap
                        }

                        // 图片
                        FluImage {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(500, Math.max(300, illustData ? (parent.width * illustData.height / illustData.width) : 300))
                            source: illustData ? getProxyImageUrl(illustData.image_urls.large) : ""
                            fillMode: Image.PreserveAspectFit
                        }

                        // 统计信息
                        RowLayout {
                            spacing: 30
                            anchors.horizontalCenter: parent.horizontalCenter

                            Column {
                                spacing: 4
                                FluText {
                                    text: illustData ? illustData.total_view.toLocaleString() : "0"
                                    font: FluTextStyle.BodyStrong
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                FluText {
                                    text: "浏览量"
                                    color: FluTheme.fontSecondaryColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            Column {
                                spacing: 4
                                FluText {
                                    text: illustData ? illustData.total_bookmarks.toLocaleString() : "0"
                                    font: FluTextStyle.BodyStrong
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                FluText {
                                    text: "收藏数"
                                    color: FluTheme.fontSecondaryColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            Column {
                                spacing: 4
                                FluText {
                                    text: illustData ? illustData.total_comments.toLocaleString() : "0"
                                    font: FluTextStyle.BodyStrong
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                FluText {
                                    text: "评论数"
                                    color: FluTheme.fontSecondaryColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }

                // --- 右侧次要信息栏 ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width * 0.4 // 占据40%宽度
                    Layout.fillHeight: true
                    color: FluTheme.cardBackgroundFillColorDefault
                    radius: 8
                    border.color: FluTheme.cardStrokeColorDefault

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 15
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 20

                            // 作者信息
                            Rectangle {
                                Layout.fillWidth: true
                                height: 80
                                color: FluTheme.subtleFillColorTertiary
                                radius: 8

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.margins: 15
                                    spacing: 15

                                    FluImage {
                                        width: 50
                                        height: 50
                                        source: illustData && illustData.user ? getProxyImageUrl(illustData.user.profile_image_urls.medium) : ""
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        FluText {
                                            text: "作者: " + (illustData && illustData.user ? illustData.user.name : "")
                                            font: FluTextStyle.BodyStrong
                                        }
                                        FluText {
                                            text: "@" + (illustData && illustData.user ? illustData.user.account : "")
                                            color: FluTheme.fontSecondaryColor
                                        }
                                    }
                                }
                            }

                            // 标签
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                FluText {
                                    text: "标签"
                                    font: FluTextStyle.BodyStrong
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: illustData && illustData.tags ? illustData.tags : []

                                        delegate: Rectangle {
                                            width: tagText.width + 16
                                            height: 28
                                            color: FluTheme.accentFillColorSecondary
                                            radius: 14

                                            FluText {
                                                id: tagText
                                                anchors.centerIn: parent
                                                text: modelData.translated_name || modelData.name
                                                color: FluTheme.accentTextFillColorPrimary
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }
                            }

                            // 作品信息
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                FluText {
                                    text: "信息"
                                    font: FluTextStyle.BodyStrong
                                }

                                RowLayout {
                                    FluText { text: "ID: "; font.bold: true }
                                    FluText { text: illustData ? illustData.id : "" }
                                }
                                RowLayout {
                                    FluText { text: "类型: "; font.bold: true }
                                    FluText { text: illustData ? illustData.type : "" }
                                }
                                RowLayout {
                                    FluText { text: "尺寸: "; font.bold: true }
                                    FluText { text: illustData ? illustData.width + "×" + illustData.height : "" }
                                }
                                RowLayout {
                                    FluText { text: "工具: "; font.bold: true }
                                    FluText { text: illustData && illustData.tools ? illustData.tools.join(", ") : "N/A" }
                                }
                                RowLayout {
                                    FluText { text: "时间: "; font.bold: true }
                                    FluText { text: illustData ? formatDate(illustData.create_date) : "" }
                                }
                            }

                            // 操作按钮
                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 15

                                FluButton {
                                    text: "查看原图"
                                    onClicked: {
                                        if (illustData && illustData.meta_single_page.original_image_url) {
                                            Qt.openUrlExternally(getProxyImageUrl(illustData.meta_single_page.original_image_url))
                                        }
                                    }
                                }
                                FluButton {
                                    text: "复制ID"
                                    onClicked: {
                                        showSuccess("ID 已复制")
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
