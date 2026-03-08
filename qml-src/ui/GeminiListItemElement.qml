import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: listItemElement

    implicitHeight: listItem.implicitHeight

    // Properties passed from ContentRenderer
    property string text: ""
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "DejaVu Sans Mono"
    property int modelIndex: -1

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
            
    }

    RowLayout {
        id: listItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(padding * scaleFactor)
        anchors.rightMargin: Math.round(padding * scaleFactor)
        spacing: Math.round(5 * listItemElement.scaleFactor)
        Layout.alignment: Qt.AlignTop

        Text {
            id: bulletText
            text: "•"
            font.family: listItemElement.fontFamily
            font.pixelSize: Math.round(listItemElement.textSize * listItemElement.scaleFactor)
            color: "#000000"
            Layout.alignment: Qt.AlignTop
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumHeight: 25 * listItemElement.scaleFactor
            Layout.alignment: Qt.AlignTop
            text: listItemElement.text
            font.family: listItemElement.fontFamily
            font.pixelSize: Math.round(listItemElement.textSize * listItemElement.scaleFactor)
            color: "#000000"
            wrapMode: Text.WordWrap
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

    Component.onCompleted: {
            
    }
}
