import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: inputDialog
    width: parent.width
    height: parent.height
    color: "transparent"
    visible: false
    z: 100

    // Properties
    property string inputUrl: ""
    property string inputPrompt: ""
    property bool isSensitive: false
    property real scaleFactor: 2

    // Signals
    signal close()
    signal inputSubmitted(string url, string input)
    signal inputCancelled(string url)

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
                text: inputPrompt
                font.family: "DejaVu Sans Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                color: "#000000"
                wrapMode: Text.WordWrap
            }

            TextField {
                id: inputField
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * scaleFactor
                leftPadding: 10 * scaleFactor
                font.family: "DejaVu Sans Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                selectByMouse: true
                echoMode: isSensitive ? TextInput.Password : TextInput.Normal
                background: Rectangle {
                    color: "#ffffff"
                    border.color: "#000000"
                    border.width: 2
                    radius: 6
                }
                onAccepted: {
                    inputSubmitted(inputUrl, inputField.text)
                    inputField.text = ""
                    // Release focus to dismiss virtual keyboard
                    inputField.focus = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * scaleFactor)

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * scaleFactor
                    text: "Cancel"
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 10 * scaleFactor
                    background: Rectangle {
                        color: "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                        radius: 6
                    }
                    onClicked: {
                        inputField.text = ""
                        inputCancelled(inputUrl)
                    }
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * scaleFactor
                    text: "Submit"
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 10 * scaleFactor
                    background: Rectangle {
                        color: "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                        radius: 6
                    }
                    onClicked: {
                        inputSubmitted(inputUrl, inputField.text)
                        inputField.text = ""
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
                inputDialog.visible = false
            }
        }
    }
}