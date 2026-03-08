import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: blockquoteElement

    implicitHeight: blockquoteItem.contentHeight + (10 * scaleFactor)

    // Properties passed from ContentRenderer
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "DejaVu Sans Mono"
    property string text: ""
    property int modelIndex: -1

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
    }

    Text {
        id: blockquoteItem
        anchors.left: parent.left
        anchors.leftMargin: Math.round(padding * scaleFactor)
        width: parent.width - (Math.round(padding * scaleFactor) * 2)
        text: parent.text
        font.family: parent.fontFamily
        font.pixelSize: Math.round(textSize * scaleFactor)
        color: "#555555"
        wrapMode: Text.WordWrap
        font.italic: true

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
