import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: urlInputModal
    width: parent.width
    height: parent.height
    color: "transparent"
    visible: false
    z: 100

    // Properties
    property string currentUrl: ""
    property real scaleFactor: 2

    // Signals
    signal urlSubmitted(string url)
    signal closeModal()

    function show(url) {
        currentUrl = url
        inputField.text = url
        visible = true
        inputField.forceActiveFocus()
    }

    function hide() {
        visible = false
        inputField.focus = false
    }

    // Semi-transparent background (separate rect to avoid affecting dialog)
    Rectangle {
        anchors.fill: parent
        color: "#80000000"  // Black with 50% alpha
    }

    // Modal dialog centered
    Rectangle {
        id: dialogRect
        z: 1  // Above the background MouseArea
        width: parent.width * 0.9
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
                text: "Enter URL"
                font.family: "Maple Mono"
                font.pixelSize: Math.round(16 * scaleFactor)
                font.bold: true
                color: "#000000"
            }

            TextField {
                id: inputField
                Layout.fillWidth: true
                Layout.preferredHeight: 40 * scaleFactor
                leftPadding: 10 * scaleFactor
                rightPadding: 10 * scaleFactor
                text: currentUrl
                font.family: "Maple Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                selectByMouse: true
                background: Rectangle {
                    color: "#ffffff"
                    border.color: "#000000"
                    border.width: 2
                    radius: 6
                }
                onAccepted: {
                    urlSubmitted(inputField.text)
                    hide()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * scaleFactor)

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * scaleFactor
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
                        hide()
                        closeModal()
                    }
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * scaleFactor
                    text: "Go"
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
                        text: "Go"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        urlSubmitted(inputField.text)
                        hide()
                    }
                }
            }
        }
    }

    // Click outside to dismiss (only if clicking on background, not dialog)
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Check if click is outside the dialog bounds
            var clickX = mouseX
            var clickY = mouseY
            var dialogLeft = dialogRect.x
            var dialogRight = dialogRect.x + dialogRect.width
            var dialogTop = dialogRect.y
            var dialogBottom = dialogRect.y + dialogRect.height

            if (clickX < dialogLeft || clickX > dialogRight ||
                clickY < dialogTop || clickY > dialogBottom) {
                hide()
                closeModal()
            }
        }
    }
}