import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: urlBar
    height: Math.round(60 * scaleFactor)
    color: "#f8f9fa"
    border.color: "#000000"
    border.width: 2

    // Properties
    property real scaleFactor: 2
    property string currentUrl: ""
    property bool showSettingsPage: false
    property bool canGoBack: false
    property bool canGoForward: false
    property bool isBookmarked: false

    onCanGoBackChanged: {
    }

    onCanGoForwardChanged: {
    }

    // Signals
    signal urlSubmitted(string url)
    signal navigateBack()
    signal navigateForward()
    signal navigateHome()
    signal showSettings()
    signal toggleBookmark()
    signal refreshPage()
    signal showBookmarks()
    signal showUrlInput()

    function unloading() {
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(10 * scaleFactor)
        spacing: Math.round(10 * scaleFactor)

        // Navigation buttons
        Button {
            Layout.preferredWidth: 36 * scaleFactor
            Layout.preferredHeight: 36 * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            enabled: canGoBack
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            onClicked: navigateBack()
            contentItem: Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/arrow-left.svg"
                fillMode: Image.PreserveAspectFit
                opacity: canGoBack ? 1.0 : 0.3
            }
        }

        Button {
            Layout.preferredWidth: 36 * scaleFactor
            Layout.preferredHeight: 36 * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            padding: 8 * scaleFactor
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            onClicked: navigateForward()
            contentItem: Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/arrow-right.svg"
                fillMode: Image.PreserveAspectFit
                opacity: canGoForward ? 1.0 : 0.3
            }
        }

        Button {
            Layout.preferredWidth: 36 * scaleFactor
            Layout.preferredHeight: 36 * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            padding: 8 * scaleFactor
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            onClicked: navigateHome()
            contentItem: Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/home.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }
        }

        // URL input field (read-only, click to open modal)
        TextField {
            id: urlField
            Layout.fillWidth: true
            Layout.preferredHeight: 36 * scaleFactor
            leftPadding: 10 * scaleFactor
            text: currentUrl
            font.family: "Maple Mono"
            font.pixelSize: Math.round(14 * scaleFactor)
            readOnly: true
            selectByMouse: true
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            // Click to open URL input modal
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    showUrlInput()
                }
            }
        }

        // Bookmark button
        Button {
            Layout.preferredWidth: 36 * scaleFactor
            Layout.preferredHeight: 36 * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            padding: 8 * scaleFactor
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            onClicked: toggleBookmark()
            contentItem: Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: isBookmarked ? "qrc:/ui/bookmark-check.svg" : "qrc:/ui/bookmark.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }
        }

        // Bookmarks button
        Button {
            Layout.preferredWidth: 36 * scaleFactor
            Layout.preferredHeight: 36 * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            padding: 8 * scaleFactor
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            onClicked: showBookmarks()
            contentItem: Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/show-bookmarks.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }
        }

        // Settings button
        Button {
            Layout.preferredWidth: 36 * scaleFactor
            Layout.preferredHeight: 36 * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            padding: 8 * scaleFactor
            background: Rectangle {
                color: "#ffffff"
                border.color: "#000000"
                border.width: 2
                radius: 4
            }
            onClicked: showSettings()
            contentItem: Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/settings.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }
        }
    }
}