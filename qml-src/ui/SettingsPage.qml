import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsPage
    color: "#ffffff"

    // Properties
    property real scaleFactor: 2
    property string homepageUrl: ""
    property int padding: 60
    property int textSize: 18
    property string proxyUrl: ""
    property int proxyPort: 0
    property string currentTab: "general"  // Default tab
    property var certificates: []
    property var certificateAssociations: ({})

    onCertificatesChanged: populateCertificateList()

    onCertificateAssociationsChanged: populateDomainAssociationList()

    // Signals
    signal backClicked()
    signal generateCertificate(string commonName)
    signal deleteCertificate(string fingerprint)
    signal deleteAssociation(string domain)
    signal requestCertificateList()
    signal requestAssociationList()
    signal saveSettings(var settings)

    function unloading() {
            
    }

    
    // Update the UI fields with the provided settings
    function updateSettingsFields(settings) {
            
        if (settings.homepage !== undefined) {
            homepageUrl = settings.homepage
            homepageField.text = settings.homepage
        }
        if (settings.padding !== undefined) {
            padding = settings.padding
            paddingField.text = settings.padding.toString()
        }
        if (settings.textSize !== undefined) {
            textSize = settings.textSize
            textSizeField.text = settings.textSize.toString()
        }
        if (settings.proxyUrl !== undefined) {
            proxyUrl = settings.proxyUrl
            proxyUrlField.text = settings.proxyUrl
        }
        if (settings.proxyPort !== undefined) {
            proxyPort = settings.proxyPort
            proxyPortField.text = settings.proxyPort.toString()
        }
    }

    // Update certificates list
    function updateCertificates(certs) {
        certificates = certs
    }

    // Update certificate associations
    function updateAssociations(assocs) {
            
        certificateAssociations = assocs
    }

    // Populate certificate list UI
    function populateCertificateList() {
        // Clear existing items
        for (var i = certificateList.children.length - 1; i >= 0; i--) {
            certificateList.children[i].destroy()
        }

        if (certificates && certificates.length > 0) {
            var component = Qt.createComponent("qrc:/ui/CertificateItem.qml")
            for (var i = 0; i < certificates.length; i++) {
                var cert = certificates[i]
                if (component.status === Component.Ready) {
                    var item = component.createObject(certificateList, {
                        "scaleFactor": scaleFactor,
                        "subject": cert.subject || "Unknown",
                        "issuer": cert.issuer || "Unknown",
                        "notBefore": cert.notBefore || "Unknown",
                        "notAfter": cert.notAfter || "Unknown",
                        "fingerprint": cert.fingerprint || "Unknown"
                    })
                    if (item) {
                        item.deleteClicked.connect(function(fp) {
                            deleteCertificate(fp)
                        })
                    }
                } else if (component.status === Component.Error) {
                        
                }
            }
        } else {
            var qmlString = 'import QtQuick 2.15; Text { text: "No certificates found"; font.family: "Maple Mono"; font.pixelSize: Math.round(12 * ' + scaleFactor + '); color: "#666666" }'
            Qt.createQmlObject(qmlString, certificateList, "noCertificates")
        }
    }

    // Populate domain association list UI
    function populateDomainAssociationList() {
            
            
        // Clear existing items
        for (var i = domainAssociationList.children.length - 1; i >= 0; i--) {
            domainAssociationList.children[i].destroy()
        }

        var hasAssociations = false
        for (var domain in certificateAssociations) {
            if (certificateAssociations.hasOwnProperty(domain)) {
                hasAssociations = true
                    
                var certId = certificateAssociations[domain]
                var qmlString = 'import QtQuick 2.15; import QtQuick.Controls 2.15; Rectangle { width: parent.width; height: 40 * ' + scaleFactor + '; color: "#f9f9f9"; border.color: "#000000"; border.width: 2; Row { anchors.fill: parent; anchors.margins: 10 * ' + scaleFactor + '; spacing: 10 * ' + scaleFactor + '; Text { width: parent.width * 0.6; elide: Text.ElideRight; text: "' + domain + '"; font.family: "Maple Mono"; font.pixelSize: Math.round(12 * ' + scaleFactor + ') } Text { width: parent.width * 0.3; elide: Text.ElideRight; text: "' + certId.substring(0, 16) + '..."; font.family: "Maple Mono"; font.pixelSize: Math.round(12 * ' + scaleFactor + '); color: "#666666" } Button { width: 60 * ' + scaleFactor + '; height: 30 * ' + scaleFactor + '; text: "Delete"; font.pixelSize: Math.round(10 * ' + scaleFactor + '); onClicked: deleteAssociation("' + domain + '") } } }'
                Qt.createQmlObject(qmlString, domainAssociationList, "assoc_" + domain)
            }
        }

        if (!hasAssociations) {
            var qmlString = 'import QtQuick 2.15; Text { text: "No domain associations found"; font.family: "Maple Mono"; font.pixelSize: Math.round(12 * ' + scaleFactor + '); color: "#666666" }'
            Qt.createQmlObject(qmlString, domainAssociationList, "noAssociations")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: Math.round(60 * scaleFactor)
            color: "#f8f9fa"
            border.color: "#000000"
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: Math.round(10 * scaleFactor)
                spacing: Math.round(10 * scaleFactor)

                Button {
                    Layout.preferredWidth: 36 * scaleFactor
                    Layout.preferredHeight: 36 * scaleFactor
                    Layout.alignment: Qt.AlignVCenter
                    padding: 8 * scaleFactor
                    background: Rectangle {
                        color: "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                    }
                    onClicked: backClicked()
                    contentItem: Image {
                        anchors.centerIn: parent
                        width: 16 * scaleFactor
                        height: 16 * scaleFactor
                        source: "qrc:/ui/arrow-left.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.7
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Settings"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(16 * scaleFactor)
                    color: "#000000"
                    horizontalAlignment: Text.AlignHCenter
                }

                            }
        }

        // Tab bar
        Rectangle {
            Layout.fillWidth: true
            height: Math.round(36 * scaleFactor)
            color: "#f8f9fa"
            border.color: "#000000"
            border.width: 2

            Row {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                Button {
                    text: "General"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 0
                    leftPadding: 20 * scaleFactor
                    rightPadding: 20 * scaleFactor
                    implicitHeight: 36 * scaleFactor
                    background: Rectangle {
                        color: currentTab === "general" ? "#e0e0e0" : "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                    }
                    onClicked: currentTab = "general"
                }

                Button {
                    text: "Certificates"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 10 * scaleFactor
                    leftPadding: 20 * scaleFactor
                    rightPadding: 20 * scaleFactor
                    implicitHeight: 36 * scaleFactor
                    background: Rectangle {
                        color: currentTab === "certificates" ? "#e0e0e0" : "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                    }
                    onClicked: {
                            
                        currentTab = "certificates"
                            
                        requestCertificateList()
                            
                        requestAssociationList()
                            
                    }
                }

                Button {
                    text: "About"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 10 * scaleFactor
                    leftPadding: 20 * scaleFactor
                    rightPadding: 20 * scaleFactor
                    implicitHeight: 36 * scaleFactor
                    background: Rectangle {
                        color: currentTab === "about" ? "#e0e0e0" : "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                    }
                    onClicked: currentTab = "about"
                }
            }
        }

        // Settings content
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true

            Column {
                width: settingsPage.width
                spacing: 20 * scaleFactor
                leftPadding: 20 * scaleFactor
                rightPadding: 20 * scaleFactor
                // Padding at the top of the settings content area, below the tab bar
                Rectangle {
                    id: topPadding
                    width: parent.width
                    height: 40 * scaleFactor
                    color: "transparent"
                }
                // GENERAL TAB CONTENT
                Rectangle {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    height: childrenRect.height
                    visible: currentTab === "general"
                    color: "transparent"

                    Column {
                        width: parent.width
                        spacing: 20 * scaleFactor

                        // General Settings section
                        Text {
                            text: "General Settings"
                            font.family: "Maple Mono"
                            font.pixelSize: Math.round(16 * scaleFactor)
                            font.bold: true
                        }

                // Gap
                Rectangle {
                    width: parent.width
                    height: scaleFactor
                    color: "#000000"
                }

                // Padding setting
                Row {
                    width: parent.width
                    spacing: 10 * scaleFactor

                    Text {
                        text: "Padding:"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                        id: paddingField
                        width: 100 * scaleFactor
                        height: 36 * scaleFactor
                        leftPadding: 10 * scaleFactor
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        text: padding.toString()
                        selectByMouse: true
                        inputMethodHints: Qt.ImhDigitsOnly
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#000000"
                            border.width: 2
                        }
                        onFocusChanged: {
                            if (!focus) {
                                // Keyboard dismissed - release focus from all text fields
                                textSizeField.focus = false
                                homepageField.focus = false
                                proxyUrlField.focus = false
                                proxyPortField.focus = false
                                commonNameField.focus = false
                            }
                        }
                        onAccepted: {
                            // Release focus to dismiss virtual keyboard
                            paddingField.focus = false
                        }
                    }

                    Text {
                        text: "px"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Text size setting
                Row {
                    width: parent.width
                    spacing: 10 * scaleFactor

                    Text {
                        text: "Text Size:"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                        id: textSizeField
                        width: 100 * scaleFactor
                        height: 36 * scaleFactor
                        leftPadding: 10 * scaleFactor
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        text: textSize.toString()
                        selectByMouse: true
                        inputMethodHints: Qt.ImhDigitsOnly
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#000000"
                            border.width: 2
                        }
                        onFocusChanged: {
                            if (!focus) {
                                // Keyboard dismissed - release focus from all text fields
                                paddingField.focus = false
                                homepageField.focus = false
                                proxyUrlField.focus = false
                                proxyPortField.focus = false
                                commonNameField.focus = false
                            }
                        }
                        onAccepted: {
                            // Release focus to dismiss virtual keyboard
                            textSizeField.focus = false
                        }
                    }

                    Text {
                        text: "px"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Gap before Homepage
                Rectangle {
                    width: parent.width
                    height: scaleFactor
                    color: "#000000"
                }

                // Homepage section
                Text {
                    text: "Homepage"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(16 * scaleFactor)
                    font.bold: true
                }

                Row {
                    width: parent.width
                    spacing: 10 * scaleFactor

                    Text {
                        text: "Homepage:"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                        id: homepageField
                        width: parent.width - 190 * scaleFactor
                        height: 36 * scaleFactor
                        leftPadding: 10 * scaleFactor
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        text: homepageUrl
                        selectByMouse: true
                        placeholderText: "Enter homepage URL (gemini://...) or leave blank"
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#000000"
                            border.width: 2
                        }
                        onFocusChanged: {
                            if (!focus) {
                                // Keyboard dismissed - release focus from all text fields
                                paddingField.focus = false
                                textSizeField.focus = false
                                proxyUrlField.focus = false
                                proxyPortField.focus = false
                                commonNameField.focus = false
                            }
                        }
                        onAccepted: {
                            // Release focus to dismiss virtual keyboard
                            homepageField.focus = false
                        }
                    }
                }

                // Gap before Proxy Settings
                Rectangle {
                    width: parent.width
                    height: scaleFactor
                    color: "#000000"
                }

                // Proxy Settings section
                Text {
                    text: "Proxy Settings"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(16 * scaleFactor)
                    font.bold: true
                }

                // Warning text
                Text {
                    text: "Warning: The proxy owner may be able to see your traffic. Use only trusted proxies, or run your own!"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(12 * scaleFactor)
                    color: "#cc0000"
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Row {
                    width: parent.width
                    spacing: 10 * scaleFactor

                    Text {
                        text: "Proxy URL:"
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                        id: proxyUrlField
                        width: parent.width - 280 * scaleFactor
                        height: 36 * scaleFactor
                        leftPadding: 10 * scaleFactor
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        text: proxyUrl
                        selectByMouse: true
                        placeholderText: "e.g., stargate.gemi.dev"
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#000000"
                            border.width: 2
                        }
                        onFocusChanged: {
                            if (!focus) {
                                // Keyboard dismissed - release focus from all text fields
                                paddingField.focus = false
                                textSizeField.focus = false
                                homepageField.focus = false
                                proxyPortField.focus = false
                                commonNameField.focus = false
                            }
                        }
                        onAccepted: {
                            // Release focus to dismiss virtual keyboard
                            proxyUrlField.focus = false
                        }
                    }

                    TextField {
                        id: proxyPortField
                        width: 70 * scaleFactor
                        height: 36 * scaleFactor
                        leftPadding: 10 * scaleFactor
                        font.family: "Maple Mono"
                        font.pixelSize: Math.round(14 * scaleFactor)
                        text: proxyPort.toString()
                        selectByMouse: true
                        inputMethodHints: Qt.ImhDigitsOnly
                        placeholderText: "Port"
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#000000"
                            border.width: 2
                        }
                        onFocusChanged: {
                            if (!focus) {
                                // Keyboard dismissed - release focus from all text fields
                                paddingField.focus = false
                                textSizeField.focus = false
                                homepageField.focus = false
                                proxyUrlField.focus = false
                                commonNameField.focus = false
                            }
                        }
                        onAccepted: {
                            // Release focus to dismiss virtual keyboard
                            proxyPortField.focus = false
                        }
                    }
                }

                // Proxy example text
                Text {
                    text: "Example: stargate.gemi.dev port 1994"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(12 * scaleFactor)
                    color: "#666666"
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                // Save button
                Button {
                    id: saveButton
                    text: "Save Settings"
                    font.family: "Maple Mono"
                    font.pixelSize: Math.round(14 * scaleFactor)
                    padding: 10 * scaleFactor
                    leftPadding: 20 * scaleFactor
                    rightPadding: 20 * scaleFactor
                    implicitHeight: 36 * scaleFactor
                    background: Rectangle {
                        color: saveButton.pressed ? "#000000" : "#ffffff"
                        border.color: "#000000"
                        border.width: 2
                    }
                    contentItem: Text {
                        text: saveButton.text
                        font: saveButton.font
                        color: saveButton.pressed ? "#ffffff" : "#000000"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        // Collect current settings from the UI fields
                        var settings = {
                            "homepage": homepageField.text,
                            "padding": parseInt(paddingField.text) || 60,
                            "textSize": parseInt(textSizeField.text) || 18,
                            "proxyUrl": proxyUrlField.text,
                            "proxyPort": parseInt(proxyPortField.text) || 0
                        }
                        saveSettings(settings)
                        settingsSavedDialog.visible = true
                        hideTimer.restart()
                        // Release focus from all text fields to dismiss virtual keyboard
                        homepageField.focus = false
                        paddingField.focus = false
                        textSizeField.focus = false
                        proxyUrlField.focus = false
                        proxyPortField.focus = false
                    }
                }
                    }
                }

                // CERTIFICATES TAB CONTENT
                Rectangle {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    height: childrenRect.height
                    visible: currentTab === "certificates"
                    color: "transparent"

                    Column {
                        width: parent.width
                        spacing: 20 * scaleFactor

                        // Certificate generation section
                        Text {
                            text: "Certificates"
                            font.family: "Maple Mono"
                            font.pixelSize: Math.round(16 * scaleFactor)
                            font.bold: true
                        }

                        Row {
                            width: parent.width
                            spacing: 10 * scaleFactor

                            TextField {
                                id: commonNameField
                                width: parent.width - 220 * scaleFactor
                                height: 36 * scaleFactor
                                leftPadding: 10 * scaleFactor
                                font.family: "Maple Mono"
                                font.pixelSize: Math.round(14 * scaleFactor)
                                placeholderText: "Common Name (e.g., Your Name)"
                                selectByMouse: true
                                onFocusChanged: {
                                    if (!focus) {
                                        // Keyboard dismissed - release focus from all text fields
                                        paddingField.focus = false
                                        textSizeField.focus = false
                                        homepageField.focus = false
                                        proxyUrlField.focus = false
                                        proxyPortField.focus = false
                                    }
                                }
                                onAccepted: {
                                    if (commonNameField.text.trim() !== "") {
                                        generateCertificate(commonNameField.text.trim())
                                        commonNameField.text = ""
                                    }
                                    commonNameField.focus = false
                                }
                                background: Rectangle {
                                    color: "#ffffff"
                                    border.color: "#000000"
                                    border.width: 2
                                }
                            }

                            Button {
                                text: "Generate"
                                font.family: "Maple Mono"
                                font.pixelSize: Math.round(14 * scaleFactor)
                                padding: 10 * scaleFactor
                                leftPadding: 20 * scaleFactor
                                rightPadding: 20 * scaleFactor
                                implicitHeight: 36 * scaleFactor
                                background: Rectangle {
                                    color: "#ffffff"
                                    border.color: "#000000"
                                    border.width: 2
                                }
                                onClicked: {
                                    if (commonNameField.text.trim() !== "") {
                                        generateCertificate(commonNameField.text.trim())
                                        commonNameField.text = ""
                                    }
                                }
                            }
                        }

                        // Gap
                        Rectangle {
                            width: parent.width
                            height: scaleFactor
                            color: "#000000"
                        }

                        // Certificate list section
                        Text {
                            text: "Certificate List"
                            font.family: "Maple Mono"
                            font.pixelSize: Math.round(14 * scaleFactor)
                            font.bold: true
                        }

                        Column {
                            id: certificateList
                            width: parent.width
                            spacing: 5 * scaleFactor

                            Text {
                                text: "No certificates found"
                                font.family: "Maple Mono"
                                font.pixelSize: Math.round(12 * scaleFactor)
                                color: "#666666"
                            }
                        }

                        // Gap
                        Rectangle {
                            width: parent.width
                            height: scaleFactor
                            color: "#000000"
                        }

                        // Domain associations section
                        Text {
                            text: "Domain Associations"
                            font.family: "Maple Mono"
                            font.pixelSize: Math.round(14 * scaleFactor)
                            font.bold: true
                        }

                        Column {
                            id: domainAssociationList
                            width: parent.width
                            spacing: 5 * scaleFactor

                            Text {
                                text: "No domain associations found"
                                font.family: "Maple Mono"
                                font.pixelSize: Math.round(12 * scaleFactor)
                                color: "#666666"
                            }
                        }

                    }
                }

                // ABOUT TAB CONTENT
                Rectangle {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    height: childrenRect.height
                    visible: currentTab === "about"
                    color: "transparent"

                    Column {
                        width: parent.width
                        spacing: 20 * scaleFactor

                        Text {
                            text: "About Irilon"
                            font.family: "Maple Mono"
                            font.pixelSize: Math.round(16 * scaleFactor)
                            font.bold: true
                        }

                        Text {
                            text: "Version: 1.0.0\n\nA Gemini protocol browser for reMarkable tablets.\n\nBuilt with Qt/QML and Go.\n\nWith thanks to Asivery for Appload and XOVI, without which this would not be possible and also to the creativity and ingenuity of the whole modding community that extends the possibilities of these devices.\n\nInterface font is Maple, by Subframe7536.\n\nLicence: Irilon is licensed under the MIT License. Copyright (c) 2026 fairlygood.\nThird-party components: Qt (LGPL), Go (BSD-3-Clause), rm-appload (GPL-3.0), XOVI (LGPL-3.0), Maple Mono (SIL Open Font License 1.1)."
                            font.family: "Maple Mono"
                            font.pixelSize: Math.round(14 * scaleFactor)
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }
        }
    }

    // Settings Saved Confirmation Dialog
    Rectangle {
        id: settingsSavedDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 400 * scaleFactor)
        height: 120 * scaleFactor
        color: "#ffffff"
        border.color: "#000000"
        border.width: 2
        visible: false
        z: 1000

        Timer {
            id: hideTimer
            interval: 2000
            running: false
            repeat: false
            onTriggered: {
                settingsSavedDialog.visible = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(20 * scaleFactor)
            spacing: Math.round(15 * scaleFactor)

            Text {
                Layout.fillWidth: true
                text: "Settings Saved"
                font.family: "Maple Mono"
                font.pixelSize: Math.round(16 * scaleFactor)
                font.bold: true
                color: "#000000"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: "Your settings have been successfully saved."
                font.family: "Maple Mono"
                font.pixelSize: Math.round(14 * scaleFactor)
                color: "#000000"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
