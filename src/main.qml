import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0

FluWindow {
    id: window
    width: 1200
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    title: qsTr("PixivAI - 多功能图片处理工具")
    //游览按钮
    FluTour{
            id: tour
            steps:[
                // 导览第一步: 指向 Logo
                {title:"应用信息", description: "这里是应用的Logo和名称。", target:()=>logoItem},
                // 导览第二步: 指向导航栏
                {title:"功能导航", description: "在这里可以切换不同的功能页面。", target:()=>functionButton},

            ]
        }
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧导航栏
        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: FluTheme.dark ? FluColors.Grey110 : FluColors.Grey20

            Column {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8

                // Logo和标题
                Item {
                    id: logoItem
                    width: parent.width
                    height: 80

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            width: 40
                            height: 40
                            source: "qrc:/pixiv.png"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        FluText {
                            text: qsTr("PixivAI")
                            anchors.horizontalCenter: parent.horizontalCenter
                            font: FluTextStyle.BodyStrong
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: FluTheme.dividerColor
                }

                // 导航按钮
                Repeater {

                    model: [
                        { text: qsTr("图片首页"),  icon: FluentIcons.AllApps,   component: "HomePage" },
                        { text: qsTr("图片详情"),  icon: FluentIcons.Picture,   component: "ImageDetailPage" },
                        { text: qsTr("以图搜源"), icon: FluentIcons.Search,    component: "ImageSearchPage" },
                        { text: qsTr("AI标签"),   icon: FluentIcons.Attach,    component: "AILabelPage" },
                        { text: qsTr("AI识物"),   icon: FluentIcons.Webcam,    component: "ObjectDetectionPage" }
                    ]

                    FluButton {
                        id: navBtn
                        width: parent.width
                        height: 50

                        // 当前是否被选中
                        property bool isSelected: stackView.currentIndex === index
                        onClicked: stackView.currentIndex = index

                        /* 背景高亮 */
                        background: Rectangle {
                            color:  navBtn.isSelected               ? "#0067b8" :
                                    (navBtn.hovered ? FluTheme.itemHoverColor : "transparent")
                            radius: 4
                        }

                        /* 重新定义按钮内部内容 */
                        contentItem: RowLayout {
                            anchors.fill: parent
                            Layout.leftMargin: 14      // ← 这里就是左边距
                            // rightPadding: 14
                            spacing: 12

                            /* 图标在左（如需在右边，交换两个元素即可） */
                            FluIcon {
                                iconSource: modelData.icon
                                color: navBtn.isSelected ? "white" : FluTheme.fontSecondaryColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            /* 文字 */
                            FluText {
                                text: modelData.text
                                color: navBtn.isSelected ? "white" : FluTheme.fontPrimaryColor
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
                Item {
                    width: 1
                    Layout.fillHeight: true
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: FluTheme.dividerColor
                }

                // 功能导览

                FluButton {
                    id:functionButton
                    width: parent.width
                    height: 40
                    text: qsTr("💡 功能导览")
                    onClicked: {
                        // 点击时启动导览
                        tour.open()
                    }
                }
                // 底部信息
                Column {
                    width: parent.width
                    spacing: 5

                    FluText {
                        text: qsTr("版本: v1.0.0")
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: FluTheme.fontSecondaryColor
                        font.pointSize: 10
                    }

                    FluText {
                        text: qsTr("FluentUI")
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: FluTheme.fontSecondaryColor
                        font.pointSize: 10
                    }
                }
            }
        }

        // 分割线
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: FluTheme.dividerColor
        }

        // 右侧内容区域
        StackLayout {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // 页面1: 图片首页
            HomePage {
                id: homePage
            }

            // 页面2: 图片详情
            ImageDetailPage {
                id: detailPage
            }

            // 页面3: 以图搜源
            ImageSearchPage {
                id: searchPage
            }

            // 页面4: AI标签
            AILabelPage {
                id: aiPage
            }
            // 页面5: AI识图
            ObjectDetectionPage {
                id: detectionPage
            }
        }
    }
}
