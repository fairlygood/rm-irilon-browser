import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: listElement

    // Properties passed from ContentRenderer
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30
    property string fontFamily: "DejaVu Sans Mono"
    property var items
    property string listType: "unordered"
    property int modelIndex: -1

    // Calculated height based on content
    property real contentHeight: 0

    // Signals
    signal clicked(string url)
    signal close()

    function unloading() {
    }

    // Update height when items change
    onItemsChanged: {
        updateHeight()
        // Force Repeater to refresh when items change
        var itemCount = listElement.items && listElement.items.length ? listElement.items.length : 0
        listRepeater.model = itemCount
    }

    Column {
        id: listColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(padding * scaleFactor)
        anchors.rightMargin: Math.round(padding * scaleFactor)
        spacing: Math.round(10 * scaleFactor)

        // Create list items dynamically
        Repeater {
            id: listRepeater
            model: 0
            delegate: GeminiListItemElement {
                width: listColumn.width
                text: listElement.items && listElement.items[index] ? listElement.items[index] : ""
                scaleFactor: listElement.scaleFactor
                textSize: listElement.textSize
                padding: listElement.padding
                fontFamily: listElement.fontFamily

                // Forward clicked signal to list element
                onClicked: (url) => listElement.clicked(url)
            }
        }
    }

    // Update implicit height based on content
    implicitHeight: listColumn.height + (padding * 2)

    function updateHeight() {
        contentHeight = listColumn.height
    }

    Component.onCompleted: {
        // Initialize repeater model on creation
        if (items && items.length > 0) {
            listRepeater.model = items.length
        }
    }
}
