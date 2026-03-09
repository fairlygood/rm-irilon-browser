import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: linkElement

    implicitHeight: linkItem.contentHeight

    // Properties passed from ContentRenderer
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "Maple Mono"
    property string text: ""
    property string url: ""
    property int modelIndex: -1

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
    }

    Text {
        id: linkItem
        anchors.left: parent.left
        anchors.leftMargin: Math.round(padding * scaleFactor)
        width: parent.width - (Math.round(padding * scaleFactor) * 2)
        text: "→ " + parent.text
        font.family: parent.fontFamily
        font.pixelSize: Math.round(textSize * scaleFactor)
        color: "#0000ff"
        wrapMode: Text.WordWrap
        font.underline: false

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
