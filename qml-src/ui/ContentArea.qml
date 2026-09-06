import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: contentArea
    color: "#ffffff"

    Component.onCompleted: {
    }

    // Properties
    property real scaleFactor: 2.0
    property int globalTextSize: 18
    property int globalPadding: 60
    property bool showSettingsPage: false
    property bool showBookmarksPage: false
    property string currentUrl: ""
    property string currentPageContent: "Welcome to the Gemini Browser!\n\nEnter a Gemini URL above to begin browsing."

    onCurrentPageContentChanged: {
    }

    onShowSettingsPageChanged: {
        // Notify parent of the change
        if (browserWindow && browserWindow.showSettingsPage !== showSettingsPage) {
            browserWindow.showSettingsPage = showSettingsPage
        }
    }

    onShowBookmarksPageChanged: {
        // Notify parent of the change
        if (browserWindow && browserWindow.showBookmarksPage !== showBookmarksPage) {
            browserWindow.showBookmarksPage = showBookmarksPage
        }
    }

    // Signals
    signal urlClicked(string url, var element)
    signal certificateGenerationRequested(string commonName)
    signal certificateDeletionRequested(string fingerprint)
    signal associationDeletionRequested(string domain)
    signal certificateListRequested()
    signal associationListRequested()
    signal saveSettingsRequested(var settings)
    signal deleteBookmarkRequested(string url)

    function unloading() {
    }

    function updateContent(content) {
        currentPageContent = content
        // Reset scroll position to top when new content is loaded
        mainContentScrollView.ScrollBar.vertical.position = 0.0
    }

    function appendInlineImage(mimeType, imagePath, insertAfterElement, imageUrl) {
        // Create inline content and call ContentRenderer's appendInlineImage
        var inlineContent = "inline/" + mimeType + "\n" + imagePath
        contentRenderer.appendInlineImage(inlineContent, insertAfterElement, imageUrl)
    }

    function updateSettingsPage(settings) {
            
        // Update local globalPadding and globalTextSize to affect content rendering
        if (settings.padding !== undefined) {
            globalPadding = settings.padding
        }
        if (settings.textSize !== undefined) {
            globalTextSize = settings.textSize
        }
        // Update SettingsPage properties and UI fields
        if (settingsPage) {
            settingsPage.homepageUrl = settings.homepage !== undefined ? settings.homepage : ""
            settingsPage.padding = settings.padding !== undefined ? settings.padding : 30
            settingsPage.textSize = settings.textSize !== undefined ? settings.textSize : 18
            settingsPage.proxyUrl = settings.proxyUrl !== undefined ? settings.proxyUrl : ""
            settingsPage.proxyPort = settings.proxyPort !== undefined ? settings.proxyPort : 0
            settingsPage.refreshMode = settings.refreshMode !== undefined ? settings.refreshMode : "quality"
            // Update the UI fields with the new settings
            settingsPage.updateSettingsFields(settings)
        }
    }

    function updateCertificates(certs) {
        if (settingsPage) {
            settingsPage.updateCertificates(certs)
        }
    }

    function updateCertificateAssociations(assocs) {
        if (settingsPage) {
            settingsPage.updateAssociations(assocs)
        }
    }

    function updateBookmarksPage(bookmarks) {
        if (bookmarksPage) {
            bookmarksPage.updateBookmarks(bookmarks)
        }
    }

    // Settings page (shown when showSettingsPage is true)
    SettingsPage {
        id: settingsPage
        anchors.fill: parent
        visible: showSettingsPage
        scaleFactor: parent.scaleFactor

        onBackClicked: browserWindow.showSettingsPage = false
        onSaveSettings: (settings) => {
            // Send settings to parent to forward to backend
            browserWindow.saveSettingsRequested(settings)
        }
        onGenerateCertificate: (commonName) => {
            certificateGenerationRequested(commonName)
        }
        onDeleteCertificate: (fingerprint) => {
            certificateDeletionRequested(fingerprint)
        }
        onDeleteAssociation: (domain) => {
            associationDeletionRequested(domain)
        }
        onRequestCertificateList: {
                
            certificateListRequested()
        }
        onRequestAssociationList: {
                
            associationListRequested()
        }
    }

    // Bookmarks page (shown when showBookmarksPage is true)
    BookmarksPage {
        id: bookmarksPage
        anchors.fill: parent
        visible: showBookmarksPage
        scaleFactor: parent.scaleFactor
        bookmarks: parent.parent.parent.bookmarks || []

        onBackClicked: browserWindow.showBookmarksPage = false
        onDeleteBookmark: (url) => {
            // Emit signal to parent to handle the backend communication
            deleteBookmarkRequested(url)
        }
        onOpenBookmark: (url) => {
            // Navigate to the bookmark URL
            browserWindow.currentUrl = url
            browserWindow.urlChanged(url)
            // Hide bookmarks page
            browserWindow.showBookmarksPage = false
        }
    }

    // Main content area (shown when neither bookmarks nor settings page is visible)
    ScrollView {
        id: mainContentScrollView
        anchors.fill: parent
        anchors.leftMargin: globalPadding * scaleFactor
        anchors.rightMargin: globalPadding * scaleFactor
        anchors.topMargin: globalPadding
        anchors.bottomMargin: globalPadding
        visible: !showSettingsPage && !showBookmarksPage
        clip: true

        // Enable touch scrolling
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ContentRenderer {
            id: contentRenderer
            width: mainContentScrollView.width
            content: contentArea.currentPageContent || "Welcome to the Gemini Browser!\n\nEnter a Gemini URL above to begin browsing."
            scaleFactor: contentArea.scaleFactor || 2.0
            textSize: contentArea.globalTextSize || 18
            onUrlClicked: (url, element) => contentArea.urlClicked(url, element)
        }
    }

    // Left tap area for scrolling up (back) - much smaller to avoid interfering with links
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 80  // Fixed width of 80 pixels
        visible: !showSettingsPage && !showBookmarksPage

        // Visual indicator for the tap zone
        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        onClicked: {
            // Move content up by roughly one page
            var currentPosition = mainContentScrollView.ScrollBar.vertical.position
            var pageSize = mainContentScrollView.ScrollBar.vertical.size
            var scrollStep = pageSize * 0.85  // Scroll by roughly one page (95% of visible area)
            var newPosition = currentPosition - scrollStep

            // Ensure we don't scroll beyond the beginning (position ranges from 0.0 to 1.0)
            newPosition = Math.max(newPosition, 0.0)

            mainContentScrollView.ScrollBar.vertical.position = newPosition
        }
    }

    // Right tap area for scrolling down (forward) - much smaller to avoid interfering with links
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 80  // Fixed width of 80 pixels
        visible: !showSettingsPage && !showBookmarksPage

        // Visual indicator for the tap zone
        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        onClicked: {
            // Move content down by roughly one page
            var currentPosition = mainContentScrollView.ScrollBar.vertical.position
            var pageSize = mainContentScrollView.ScrollBar.vertical.size
            var scrollStep = pageSize * 0.85  // Scroll by roughly one page (95% of visible area)
            var newPosition = currentPosition + scrollStep

            // Ensure we don't scroll beyond the end (position ranges from 0.0 to 1.0)
            newPosition = Math.min(newPosition, 1.0)

            mainContentScrollView.ScrollBar.vertical.position = newPosition
        }
    }
}