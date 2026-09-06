import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: headingElement

    implicitHeight: headingTopPad + headingItem.contentHeight + headingBottomPad

    property int headingLevel: 1

    // Properties passed from ContentRenderer
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "Maple Mono"
    property string text: ""
    property int modelIndex: -1

    // Vertical margins around a heading, in multiples of the body text size
    // (Lagrange gives headings notably more breathing room than paragraphs).
    function headingTopEm() {
        switch (headingLevel) {
        case 1: return 1.1
        case 2: return 0.8
        default: return 0.6
        }
    }
    function headingBottomEm() {
        switch (headingLevel) {
        case 1: return 0.45
        case 2: return 0.3
        default: return 0.2
        }
    }
    readonly property real headingTopPad: Math.round(headingTopEm() * textSize * scaleFactor)
    readonly property real headingBottomPad: Math.round(headingBottomEm() * textSize * scaleFactor)

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
    }

    Text {
        id: headingItem
        anchors.left: parent.left
        anchors.leftMargin: Math.round(padding * scaleFactor)
        anchors.top: parent.top
        anchors.topMargin: headingElement.headingTopPad
        width: parent.width - (Math.round(padding * scaleFactor) * 2)
        text: parent.text
        font.family: parent.fontFamily
        font.pixelSize: Math.round((textSize + (4 - headingLevel) * 2) * scaleFactor)
        font.bold: true
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
