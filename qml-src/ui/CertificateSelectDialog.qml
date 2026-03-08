import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: certificateSelectDialog
    width: parent.width
    height: parent.height
    color: "transparent"
    visible: false
    z: 100

    // Properties
    property string certSelectUrl: ""
    property var certificates: []
    property real scaleFactor: 2

    // Signals
    signal close()
    signal certificateSelected(string url, string certificateId)
    signal certificateCancelled(string url)

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
        width: Math.min(parent.width * 0.9, 500 * scaleFactor)
        height: 300 * scaleFactor
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
                text: "Select Certificate for " + certSelectUrl
                font.family: "DejaVu Sans Mono"
                font.pixelSize: Math.round(16 * scaleFactor)
                font.bold: true
                color: "#000000"
                wrapMode: Text.WordWrap
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    width: parent.width
                    spacing: Math.round(10 * scaleFactor)

                    Repeater {
                        model: certificates

                        Button {
                            width: parent.width
                            height: Math.round(60 * scaleFactor)
                            background: Rectangle {
                                color: parent.pressed ? "#e9ecef" : "#f8f9fa"
                                border.color: "#000000"
                                border.width: 2
                                radius: 4
                            }
                            onClicked: {
                                certificateSelected(certSelectUrl, modelData.fingerprint)
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: Math.round(10 * scaleFactor)
                                spacing: Math.round(5 * scaleFactor)

                                Text {
                                    width: parent.width
                                    text: modelData.subject
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: Math.round(14 * scaleFactor)
                                    color: "#000000"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: "Fingerprint: " + modelData.fingerprint
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: Math.round(12 * scaleFactor)
                                    color: "#6c757d"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
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
                        certificateCancelled(certSelectUrl)
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
                certificateSelectDialog.visible = false
            }
        }
    }
}