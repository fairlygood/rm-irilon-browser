import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: headingElement

    implicitHeight: headingItem.contentHeight + (10 * scaleFactor)

    property int headingLevel: 1

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
        id: headingItem
        anchors.left: parent.left
        anchors.leftMargin: Math.round(padding * scaleFactor)
        width: parent.width - (Math.round(padding * scaleFactor) * 2)
        text: parent.text
        font.family: parent.fontFamily
        font.pixelSize: Math.round((textSize + (4 - headingLevel) * 2) * scaleFactor)
        color: "#000000"
        wrapMode: Text.WordWrap

        onTextChanged: {
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (parent.url) {
                parent.clicked(parent.url)
            }
        }
    }
}
