import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: baseElement
    width: parent.width

    // Properties
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "DejaVu Sans Mono"
    property string text: ""
    property string url: ""
    property int modelIndex: -1
    property bool isPreformatted: false

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
            
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: url ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (url) {
                clicked(url)
            }
        }
    }
}