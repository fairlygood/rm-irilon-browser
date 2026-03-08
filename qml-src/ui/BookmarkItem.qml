import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: bookmarkItem
    width: parent.width
    height: 50 * scaleFactor
    color: "#f9f9f9"
    border.color: "#000000"
    border.width: 2
    radius: 3 * scaleFactor
    anchors.left: parent.left
    anchors.leftMargin: 10 * scaleFactor
    anchors.right: parent.right
    anchors.rightMargin: 10 * scaleFactor

    property real scaleFactor: 2
    property string bookmarkTitle: ""
    property string bookmarkUrl: ""

    signal openClicked(string url)
    signal deleteClicked(string url)

    Row {
        anchors.fill: parent
        anchors.margins: 10 * scaleFactor
        spacing: 10 * scaleFactor

        Column {
            width: parent.width - 100 * scaleFactor
            height: parent.height
            spacing: 2 * scaleFactor

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: bookmarkTitle
                font.family: "DejaVu Sans Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                font.bold: true
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: bookmarkUrl
                font.family: "DejaVu Sans Mono"
                font.pixelSize: Math.round(12 * scaleFactor)
                color: "#666666"
            }
        }

        Rectangle {
            id: goButton
            width: 36 * scaleFactor
            height: 36 * scaleFactor
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/go.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                onClicked: openClicked(bookmarkUrl)
            }
        }

        Rectangle {
            id: deleteButton
            width: 36 * scaleFactor
            height: 36 * scaleFactor
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 16 * scaleFactor
                height: 16 * scaleFactor
                source: "qrc:/ui/trash.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                onClicked: deleteClicked(bookmarkUrl)
            }
        }
    }
}
