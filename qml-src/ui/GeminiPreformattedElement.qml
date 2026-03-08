import QtQuick 2.15
import QtQuick.Controls 2.15

GeminiBaseElement {
    id: preformattedElement

    implicitHeight: preformattedItem.contentHeight + (10 * scaleFactor)

    // Properties passed from ContentRenderer
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "DejaVu Sans Mono"
    property string text: ""
    property int modelIndex: -1

    // Note: clicked and close signals are inherited from GeminiBaseElement

    function unloading() {
    }

    Text {
        id: preformattedItem
        anchors.left: parent.left
        anchors.leftMargin: Math.round(padding * scaleFactor)
        width: parent.width - (Math.round(padding * scaleFactor) * 2)
        text: parent.text
        font.family: parent.fontFamily
        font.pixelSize: Math.round((textSize * 0.85) * scaleFactor)
        color: "#000000"
        wrapMode: Text.NoWrap
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
