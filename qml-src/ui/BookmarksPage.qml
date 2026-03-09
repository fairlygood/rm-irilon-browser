import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: bookmarksPage
    color: "#ffffff"

    // Properties
    property real scaleFactor: 2
    property var bookmarks: []

    // Signals
    signal backClicked()
    signal deleteBookmark(string url)
    signal openBookmark(string url)

    function unloading() {
    }

    // Update bookmarks list
    function updateBookmarks(list) {
        bookmarks = list || []
        populateBookmarksList()
    }

    // Populate the bookmarks list UI
    function populateBookmarksList() {
        // Clear existing items
        for (var i = bookmarksList.children.length - 1; i >= 0; i--) {
            bookmarksList.children[i].destroy()
        }

        if (bookmarks && bookmarks.length > 0) {
            var component = Qt.createComponent("qrc:/ui/BookmarkItem.qml")
            for (var i = 0; i < bookmarks.length; i++) {
                var bookmark = bookmarks[i]
                var title = bookmark.title || "Untitled"
                var url = bookmark.url || ""
                if (component.status === Component.Ready) {
                    var item = component.createObject(bookmarksList, {
                        "scaleFactor": scaleFactor,
                        "bookmarkTitle": title,
                        "bookmarkUrl": url
                    })
                    if (item) {
                        item.openClicked.connect(function(u) {
                            openBookmark(u)
                        })
                        item.deleteClicked.connect(function(u) {
                            deleteBookmark(u)
                        })
                    }
                } else if (component.status === Component.Error) {
                }
            }
        } else {
            var qmlString = 'import QtQuick 2.15; Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "No bookmarks yet"; font.family: "Maple Mono"; font.pixelSize: Math.round(14 * ' + scaleFactor + '); color: "#666666"; topPadding: 40 * ' + scaleFactor + ' }'
            Qt.createQmlObject(qmlString, bookmarksList, "noBookmarks")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: Math.round(60 * scaleFactor)
            color: "#f8f9fa"
            border.color: "#000000"
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: Math.round(10 * scaleFactor)
                spacing: Math.round(10 * scaleFactor)

                Button {
                    Layout.preferredWidth: 36 * scaleFactor
                    Layout.preferredHeight: 36 * scaleFactor
                    Layout.alignment: Qt.AlignVCenter
                    padding: 8 * scaleFactor
                    background: Rectangle {
                        color: "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                    }
                    onClicked: backClicked()
                    contentItem: Image {
                        anchors.centerIn: parent
                        width: 16 * scaleFactor
                        height: 16 * scaleFactor
                        source: "qrc:/ui/arrow-left.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.7
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Bookmarks"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(16 * scaleFactor)
                    color: "#000000"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Bookmarks list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                id: bookmarksList
                width: bookmarksPage.width
                spacing: 5 * scaleFactor
                leftPadding: 20 * scaleFactor
                rightPadding: 20 * scaleFactor
                topPadding: 20 * scaleFactor

                // Bookmarks will be populated dynamically
                Component.onCompleted: {
                    populateBookmarksList()
                }
            }
        }
    }
}