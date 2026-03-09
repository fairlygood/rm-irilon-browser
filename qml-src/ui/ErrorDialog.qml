import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: errorDialog
    width: parent.width
    height: parent.height
    color: "transparent"
    visible: false
    z: 100

    // Properties
    property real scaleFactor: 2
    property string errorMessage: ""

    // Signals
    signal close()

    function unloading() {
            
    }

    // Semi-transparent background
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    // Modal dialog centered
    Rectangle {
        id: dialogRect
        z: 1
        width: Math.min(parent.width * 0.8, 400 * scaleFactor)
        height: 180 * scaleFactor
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        color: "#ffffff"
        border.color: "#000000"
        border.width: 2
        radius: 8 * scaleFactor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(20 * scaleFactor)
            spacing: Math.round(15 * scaleFactor)

            Text {
                Layout.fillWidth: true
                text: "Connection Error"
                font.family: "Maple Mono"
                font.pixelSize: Math.round(16 * scaleFactor)
                font.bold: true
                color: "#cc0000"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: errorDialog.errorMessage
                font.family: "Maple Mono"
                font.pixelSize: Math.round(12 * scaleFactor)
                color: "#000000"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 36 * scaleFactor
                text: "OK"
                font.family: "Maple Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                padding: 10 * scaleFactor
                background: Rectangle {
                    color: "#ffffff"
                    border.color: "#000000"
                    border.width: 2
                    radius: 6
                }
                onClicked: {
                    errorDialog.visible = false
                }
            }
        }
    }

    // Click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            var clickX = mouseX
            var clickY = mouseY
            var dialogLeft = dialogRect.x
            var dialogRight = dialogRect.x + dialogRect.width
            var dialogTop = dialogRect.y
            var dialogBottom = dialogRect.y + dialogRect.height

            if (clickX < dialogLeft || clickX > dialogRight ||
                clickY < dialogTop || clickY > dialogBottom) {
                errorDialog.visible = false
            }
        }
    }
}
