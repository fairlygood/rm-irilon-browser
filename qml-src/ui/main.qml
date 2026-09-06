import QtQuick 2.15
import QtQuick.Controls 2.15
import net.asivery.AppLoad 1.0

Rectangle {
    width: Screen.width
    height: Screen.height
    color: "#ffffff"

    // Application state properties
    property string currentUrl: ""
    property real scaleFactor: 2.0
    property int globalTextSize: 18
    property int globalPadding: 60
    property string homepageUrl: ""
    property string proxyUrl: ""   // Proxy used to fetch http(s) URLs ("" = none)
    property int proxyPort: 0
    property bool isBookmarked: false
    property bool showSettingsPage: false
    property bool showBookmarksPage: false
    property var bookmarks: []
    property var history: []
    property int historyIndex: -1

    onCurrentUrlChanged: {
        // Update isBookmarked status based on current URL
        var bookmarked = false;
        if (bookmarks && bookmarks.length > 0) {
            for (var i = 0; i < bookmarks.length; i++) {
                if (bookmarks[i].url === currentUrl) {
                    bookmarked = true;
                    break;
                }
            }
        }
        isBookmarked = bookmarked;
        browserWindow.isBookmarked = bookmarked;
    }

    onHistoryChanged: {
        if (JSON.stringify(browserWindow.history) !== JSON.stringify(history)) {
            browserWindow.history = history
        }
    }

    onHistoryIndexChanged: {
        if (browserWindow.historyIndex !== historyIndex) {
            browserWindow.historyIndex = historyIndex
        }
    }

    onBookmarksChanged: {
        // Update isBookmarked status based on current URL
        var bookmarked = false;
        if (bookmarks && bookmarks.length > 0) {
            for (var i = 0; i < bookmarks.length; i++) {
                if (bookmarks[i].url === currentUrl) {
                    bookmarked = true;
                    break;
                }
            }
        }
        isBookmarked = bookmarked;
        browserWindow.isBookmarked = bookmarked;
    }

    onShowSettingsPageChanged: {
        browserWindow.showSettingsPage = showSettingsPage
    }

    onShowBookmarksPageChanged: {
        browserWindow.showBookmarksPage = showBookmarksPage
    }

    signal close()

    function unloading() {
    }

    // Helper function to extract first heading from Gemini content
    function getFirstHeading(content) {
        if (!content) return "Untitled"
        var lines = content.split('\n')
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.startsWith('# ')) {
                return line.substring(2).trim()
            } else if (line.startsWith('## ')) {
                return line.substring(3).trim()
            } else if (line.startsWith('### ')) {
                return line.substring(4).trim()
            }
        }
        return "Untitled"
    }

    Component.onCompleted: {
        endpoint.sendMessage(701, "{}") // SETTINGS_GET
    }

    AppLoad {
        id: endpoint
        applicationID: "gemini-browser"

        onMessageReceived: (type, contents) => {
            try {
                if (type === 151) {  // INLINE_IMAGE_RESPONSE
                    // Handle inline image response - insert image at link position
                    var response = JSON.parse(contents)
                    if (response.success && response.isInline && response.imagePath) {
                        // Append inline image to current content (insert after the link that was clicked)
                        var inlineContent = "inline/" + (response.mimeType || "unknown") + "\n" + response.imagePath;
                        browserWindow.appendInlineImage(inlineContent, browserWindow.lastClickedElement, response.url)
                        // Clear the stored element
                        browserWindow.lastClickedElement = null
                    }
                } else if (type === 101) {  // GEMINI_RESPONSE
                    var response = JSON.parse(contents)
                    if (response.success) {
                        currentUrl = response.url

                        // Add homepage or loaded page to history if it's not already there
                        // This handles the case where pages are loaded directly (e.g., homepage)
                        if (history.length === 0 || history[history.length - 1] !== response.url) {
                            // Remove forward history if we're navigating to a new URL
                            if (historyIndex < history.length - 1 && historyIndex >= 0) {
                                history = history.slice(0, historyIndex + 1)
                            }
                            history.push(response.url)
                            historyIndex = history.length - 1
                        }

                        // Update content in ContentArea through BrowserWindow
                        // (note: image responses arrive separately as type 151)
                        browserWindow.currentUrl = response.url
                        browserWindow.updateContent(response.content || "No content available")
                        // The ContentRenderer in ContentArea will handle the content display
                    } else {
                        // Show error dialog with the error message
                        errorDialog.errorMessage = response.error || "Unknown error"
                        errorDialog.visible = true
                    }
                } else if (type === 301) {  // BOOKMARK_RESPONSE
                    var response = JSON.parse(contents)
                    if (response.success && response.bookmarks !== undefined) {
                        bookmarks = response.bookmarks
                        // Update the BookmarksPage if it's visible
                        browserWindow.updateBookmarksPage(response.bookmarks)
                    }
                } else if (type === 703) {  // SETTINGS_RESPONSE
                    try {
                        var response = JSON.parse(contents)
                        if (response.success && response.settings !== undefined) {
                                
                            // Update settings in main
                            homepageUrl = response.settings.homepage
                            globalTextSize = response.settings.textSize
                            globalPadding = response.settings.padding
                            // Ignore scaleFactor as it's a frontend-only property
                            // Update settings in BrowserWindow
                            browserWindow.homepageUrl = homepageUrl
                            browserWindow.globalTextSize = globalTextSize
                            browserWindow.globalPadding = globalPadding
                            // Keep a copy of proxy settings for http(s) gating
                            proxyUrl = response.settings.proxyUrl || ""
                            proxyPort = response.settings.proxyPort || 0
                            // Update settings in SettingsPage via ContentArea
                            browserWindow.updateSettingsPage(response.settings)
                                                        // Load homepage automatically if available (only on initial load)
                            if (homepageUrl && currentUrl === "") {
                                currentUrl = homepageUrl
                                browserWindow.currentUrl = homepageUrl
                                endpoint.sendMessage(1, homepageUrl) // GEMINI_REQUEST
                            }
                        }
                    } catch (e) {
                    }
                } else if (type === 401) {  // INPUT_REQUEST
                    var request = JSON.parse(contents)
                    inputDialog.inputUrl = request.url || ""
                    inputDialog.inputPrompt = request.prompt || "Enter input:"
                    inputDialog.isSensitive = request.sensitive || false
                    inputDialog.visible = true
                } else if (type === 605) {  // CERTIFICATE_RESPONSE
                    var response = JSON.parse(contents)
                    if (response.success) {
                        // Handle both undefined (not returned) and empty array cases
                        var certs = response.certificates
                        if (certs === undefined) {
                            certs = []
                        }
                        browserWindow.updateCertificates(certs)
                    }
                } else if (type === 606) {  // CERTIFICATE_SELECT
                    var request = JSON.parse(contents)
                    certificateSelectDialog.certSelectUrl = request.url || ""
                    certificateSelectDialog.certificates = request.certificates || []
                    certificateSelectDialog.visible = true
                } else if (type === 607) {  // CERTIFICATE_ASSOCIATION_UPDATE
                    var response = JSON.parse(contents)
                    if (response.success) {
                        var assocs = response.associations
                        if (assocs === undefined) {
                            assocs = {}
                        }
                        browserWindow.updateCertificateAssociations(assocs)
                    }
                    // Automatically reload the current page to use the newly associated certificate
                    if (currentUrl && currentUrl !== "") {
                        endpoint.sendMessage(1, currentUrl) // GEMINI_REQUEST
                    }
                } else if (type === 610) {  // CERTIFICATE_EXPIRED
                    var response = JSON.parse(contents)
                    certificateExpiredDialog.expiredUrl = (response && response.url) || currentUrl || ""
                    certificateExpiredDialog.visible = true
                }
            } catch (e) {
            }
        }
    }

    BrowserWindow {
        id: browserWindow
        anchors.fill: parent
        currentUrl: parent.currentUrl
        scaleFactor: parent.scaleFactor
        globalTextSize: parent.globalTextSize
        globalPadding: parent.globalPadding
        homepageUrl: parent.homepageUrl
        proxyUrl: parent.proxyUrl
        proxyPort: parent.proxyPort
        isBookmarked: parent.isBookmarked
        showSettingsPage: false
        history: parent.history
        historyIndex: parent.historyIndex

        Component.onCompleted: {
        }

        // Helper function to check if URL is an image resource
        function isImageUrl(url) {
            if (!url) return false;
            var lowerUrl = url.toLowerCase();
            var imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico'];
            for (var i = 0; i < imageExtensions.length; i++) {
                if (lowerUrl.endsWith(imageExtensions[i])) {
                    return true;
                }
            }
            return false;
        }

        onUrlChanged: (url) => {
            // Handle URL change
            currentUrl = url
            // Skip history for image URLs - they're not pages
            var isImage = isImageUrl(url);
            if (isImage) {
            } else {
                // Add to history if not already there (only for new URLs, not navigation)
                // Check if this URL change is due to navigation (URL already exists in history)
                var isNavigation = false;
                var navigationIndex = -1;
                for (var i = 0; i < history.length; i++) {
                    if (history[i] === url) {
                        isNavigation = true;
                        navigationIndex = i;
                        break;
                    }
                }

                if (isNavigation) {
                    // Update historyIndex to point to the navigated URL
                    historyIndex = navigationIndex;
                } else if (history.length === 0 || history[history.length - 1] !== url) {
                    // Remove forward history if we're navigating to a new URL
                    if (historyIndex < history.length - 1 && historyIndex >= 0) {
                        history = history.slice(0, historyIndex + 1)
                    }
                    history.push(url)
                    historyIndex = history.length - 1
                }
            }
            // Send message to backend to fetch the page
            endpoint.sendMessage(1, url) // GEMINI_REQUEST
        }

        onNavigateBack: {
            // Handle back navigation
            if (historyIndex > 0) {
                historyIndex--;
                var previousUrl = history[historyIndex];
                currentUrl = previousUrl;
                browserWindow.currentUrl = previousUrl;
                browserWindow.historyIndex = historyIndex;
                // Send message to backend to fetch the page
                endpoint.sendMessage(1, previousUrl) // GEMINI_REQUEST
            }
        }

        onNavigateForward: {
            // Handle forward navigation
            if (historyIndex < history.length - 1) {
                historyIndex++;
                var nextUrl = history[historyIndex];
                currentUrl = nextUrl;
                browserWindow.currentUrl = nextUrl;
                browserWindow.historyIndex = historyIndex;
                // Send message to backend to fetch the page
                endpoint.sendMessage(1, nextUrl) // GEMINI_REQUEST
            }
        }

        onNavigateHome: {
            // Handle home navigation
            if (homepageUrl) {
                // An http(s) homepage still needs a configured proxy
                if (!browserWindow.shouldNavigate(homepageUrl)) return
                currentUrl = homepageUrl;
                // Send message to backend to fetch the homepage
                endpoint.sendMessage(1, homepageUrl) // GEMINI_REQUEST
            } else {
                // Show homepage not set dialog
                homepageNotSetDialog.visible = true
            }
        }

        onShowSettings: {
            // Handle show settings
            showSettingsPage = true
            browserWindow.showSettingsPage = true
            // Request settings from backend
            endpoint.sendMessage(701, "{}") // SETTINGS_GET
        }

        onShowBookmarks: {
            // Handle show bookmarks
            showBookmarksPage = true
            browserWindow.showBookmarksPage = true
            // Request bookmark list from backend
            endpoint.sendMessage(203, "{}") // BOOKMARK_LIST
        }

        onSaveSettingsRequested: (settings) => {
            // Send settings to backend
            endpoint.sendMessage(702, JSON.stringify(settings)) // SETTINGS_SAVE
        }

        onToggleBookmark: {
            // Handle toggle bookmark
            if (currentUrl) {
                if (isBookmarked) {
                    // Remove bookmark
                    isBookmarked = false
                    endpoint.sendMessage(202, currentUrl) // BOOKMARK_REMOVE
                } else {
                    // Add bookmark
                    var title = getFirstHeading(browserWindow.currentPageContent)
                    var bookmarkData = {
                        "url": currentUrl,
                        "title": title
                    }
                    isBookmarked = true
                    endpoint.sendMessage(201, JSON.stringify(bookmarkData)) // BOOKMARK_ADD
                }
            }
        }

        onDeleteBookmarkRequested: (url) => {
            // Send message to backend to delete the bookmark
            endpoint.sendMessage(202, url) // BOOKMARK_REMOVE
        }

        onRefreshPage: {
            // Handle refresh page
            if (currentUrl) {
                // Send message to backend to fetch the current page again
                endpoint.sendMessage(1, currentUrl) // GEMINI_REQUEST
            }
        }

        onGenerateCertificateRequested: (commonName) => {
            var request = {
                "commonName": commonName
            }
            endpoint.sendMessage(604, JSON.stringify(request)) // CERTIFICATE_GENERATE
        }

        onDeleteCertificateRequested: (fingerprint) => {
            endpoint.sendMessage(603, fingerprint) // CERTIFICATE_REMOVE
            // Backend will send updated certificate list (605) and associations (607)
        }

        onDeleteAssociationRequested: (domain) => {
            endpoint.sendMessage(609, domain) // CERTIFICATE_DISASSOCIATE
            // Backend will send updated associations list (607)
        }

        onListCertificatesRequested: {
            endpoint.sendMessage(601, "{}") // CERTIFICATE_LIST
        }

        onListAssociationsRequested: {
            endpoint.sendMessage(608, "{}") // CERTIFICATE_LIST_ASSOCIATIONS
        }

        onHttpLinkBlocked: (url) => {
            // Explain that http(s) needs a configured proxy instead of navigating
            httpLinkDialog.visible = true
        }
    }

    // Certificate selection dialog
    CertificateSelectDialog {
        id: certificateSelectDialog
        scaleFactor: parent.scaleFactor

        onCertificateSelected: (url, certificateId) => {
            certificateSelectDialog.visible = false
            var response = {
                "url": url,
                "certificateId": certificateId
            }
            endpoint.sendMessage(607, JSON.stringify(response)) // CERTIFICATE_SELECT_RESPONSE
        }

        onCertificateCancelled: (url) => {
            certificateSelectDialog.visible = false
        }
    }

    // Input dialog
    InputDialog {
        id: inputDialog
        scaleFactor: parent.scaleFactor

        onInputSubmitted: (url, input) => {
            inputDialog.visible = false
            var response = {
                "url": url,
                "input": input
            }
            endpoint.sendMessage(402, JSON.stringify(response)) // INPUT_RESPONSE
        }

        onInputCancelled: (url) => {
            inputDialog.visible = false
            endpoint.sendMessage(403, url) // INPUT_CANCEL
        }
    }

    // HTTP Link dialog
    HttpLinkDialog {
        id: httpLinkDialog
        scaleFactor: parent.scaleFactor
        visible: false
    }

    // Certificate expired dialog
    CertificateExpiredDialog {
        id: certificateExpiredDialog
        scaleFactor: parent.scaleFactor
        visible: false

        onCertificateBypassed: (url) => {
            certificateExpiredDialog.visible = false
            // Tell the backend to bypass certificate validation for this host
            endpoint.sendMessage(611, url) // CERTIFICATE_BYPASS
            // Re-request the page so it loads with the bypassed certificate
            endpoint.sendMessage(1, url)   // GEMINI_REQUEST
        }
    }

    // Homepage not set dialog
    HomepageNotSetDialog {
        id: homepageNotSetDialog
        scaleFactor: parent.scaleFactor
        visible: false
    }

    // Error dialog
    ErrorDialog {
        id: errorDialog
        scaleFactor: parent.scaleFactor
        visible: false
    }
}