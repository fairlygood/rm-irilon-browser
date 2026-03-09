import QtQuick 2.15

Item {
    id: imageElement
    width: parent.width

    implicitHeight: contentHeight

    // Properties passed from ContentRenderer
    property real scaleFactor: 2.0
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "Maple Mono"
    property string imagePath: ""
    property string mimeType: ""
    property int modelIndex: -1

    // Calculated height based on content
    property real contentHeight: 0

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
    }

    // Image container with proper sizing
    Column {
        id: imageColumn
        width: parent.width
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(padding * scaleFactor)
        anchors.rightMargin: Math.round(padding * scaleFactor)

        // Image component
        Image {
            id: imageContent
            anchors.left: parent.left
            anchors.right: parent.right
            source: imagePath ? "file://" + imagePath : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit

            onStatusChanged: {
                if (status === Image.Ready) {
                    contentHeight = (imageContent.height > 0) ? imageContent.height : (width * (sourceSize.height / sourceSize.width))
                } else if (status === Image.Error) {
                    contentHeight = 50 * scaleFactor
                }
            }
        }

        // Loading text
        Text {
            text: "Loading image..."
            font.pixelSize: Math.round(14 * scaleFactor)
            font.family: "Maple Mono"
            color: "#666666"
        }
    }
}
