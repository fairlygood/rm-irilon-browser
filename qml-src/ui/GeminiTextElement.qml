import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: textElement

    implicitHeight: textItem.contentHeight

    // Properties passed from ContentRenderer
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "Maple Mono"
    property string text: ""
    property int modelIndex: -1

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
    }

    Text {
        id: textItem
        anchors.left: parent.left
        anchors.leftMargin: Math.round(padding * scaleFactor)
        width: parent.width - (Math.round(padding * scaleFactor) * 2)
        text: parent.text
        font.family: parent.fontFamily
        font.pixelSize: Math.round(textSize * scaleFactor)
        color: "#000000"
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText

        onTextChanged: {
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: {
            if (parent.url) {
                parent.clicked(parent.url)
            }
        }
    }
}
