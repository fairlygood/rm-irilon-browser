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

    // Update the bookmarks list. Skipping no-op updates avoids rebuilding the
    // (still visible) list when the page is reopened with unchanged data.
    function updateBookmarks(list) {
        list = list || []
        if (JSON.stringify(list) === JSON.stringify(bookmarks)) {
            return
        }
        bookmarks = list
    }

    // Any change to `bookmarks` (from updateBookmarks or the property binding)
    // rebuilds the model; the Repeater keeps the rendered items in sync without
    // the destroy/create overlap that caused a momentary duplicate list.
    onBookmarksChanged: {
        bookmarkModel.clear()
        for (var i = 0; i < bookmarks.length; i++) {
            bookmarkModel.append({
                "title": bookmarks[i].title || "Untitled",
                "url": bookmarks[i].url || ""
            })
        }
    }

    ListModel {
        id: bookmarkModel
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

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No bookmarks yet"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(14 * bookmarksPage.scaleFactor)
                    color: "#666666"
                    topPadding: 40 * bookmarksPage.scaleFactor
                    visible: bookmarkModel.count === 0
                }

                Repeater {
                    model: bookmarkModel

                    delegate: BookmarkItem {
                        scaleFactor: bookmarksPage.scaleFactor
                        bookmarkTitle: title
                        bookmarkUrl: url

                        onOpenClicked: (u) => openBookmark(u)
                        onDeleteClicked: (u) => deleteBookmark(u)
                    }
                }
            }
        }
    }
}
