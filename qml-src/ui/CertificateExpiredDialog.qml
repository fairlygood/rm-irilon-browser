import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: certificateExpiredDialog
    width: parent.width
    height: parent.height
    color: "transparent"
    visible: false
    z: 100

    // Properties
    property string expiredUrl: ""
    property real scaleFactor: 2

    // Signals
    signal close()
    signal certificateBypassed(string url)

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
        height: 200 * scaleFactor
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
                text: "Certificate for " + expiredUrl + " has expired. Do you want to bypass this certificate and continue?"
                font.family: "Maple Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                color: "#000000"
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * scaleFactor)

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * scaleFactor
                    text: "Cancel"
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
                        certificateExpiredDialog.visible = false
                    }
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * scaleFactor
                    text: "Bypass"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 10 * scaleFactor
                    background: Rectangle {
                        color: "#000000"
                        border.color: "#000000"
                        border.width: 2
                        radius: 6
                    }
                    contentItem: Text {
                        text: "Bypass"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        certificateBypassed(expiredUrl)
                        certificateExpiredDialog.visible = false
                    }
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
                certificateExpiredDialog.visible = false
            }
        }
    }
}