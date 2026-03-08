import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: inlineImage
    width: parent.width

    // Properties passed from ContentRenderer
    property string imageUrl: ""
    property real scaleFactor: 2.0
    property int padding: 30
    property string mimeType: ""
    property string fontFamily: "DejaVu Sans Mono"
    property int textSize: 18
    property int modelIndex: -1

    // Calculated height based on content
    property real contentHeight: 0

    // Update implicitHeight based on contentHeight
    implicitHeight: contentHeight + (padding * 2)

    // Signals
    signal clicked()
    signal close()

    function unloading() {
    }

    // Image container
    Rectangle {
        id: imageContainer
        width: inlineImage.width - (padding * 2 * scaleFactor)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(padding * scaleFactor)
        anchors.rightMargin: Math.round(padding * scaleFactor)
        color: "#fafafa"
        border.width: 1
        border.color: "#eeeeee"
        visible: false

        // Image element
        Image {
            id: imageElement
            width: imageContainer.width - 10
            anchors.left: parent.left
            anchors.right: parent.right
            fillMode: Image.PreserveAspectFit
            source: imageUrl ? "file://" + imageUrl : ""
            asynchronous: true

            onStatusChanged: {
                if (status === Image.Error) {
                    contentHeight = 50 * scaleFactor
                    imageContainer.visible = false
                } else if (status === Image.Ready) {
                    // Calculate height based on aspect ratio
                    contentHeight = (imageElement.height > 0) ? imageElement.height : (imageContainer.width * (sourceSize.height / sourceSize.width))
                    imageContainer.visible = true
                }
            }
        }

        // Loading indicator
        Rectangle {
            anchors.fill: parent
            color: "#fafafa"
            visible: !imageContainer.visible

            Text {
                anchors.centerIn: parent
                text: "Loading image..."
                color: "#666666"
                font.pixelSize: Math.round(14 * scaleFactor)
                font.family: "DejaVu Sans Mono"
            }
        }
    }

    // Click handler
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (imageUrl) {
                clicked()
            }
        }
    }
}