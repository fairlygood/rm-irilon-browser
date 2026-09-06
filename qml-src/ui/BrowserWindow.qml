import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: browserWindow
    color: "#ffffff"

    // Properties
    property string currentUrl: ""
    property real scaleFactor: 2.0
    property int globalPadding: Math.round(60 * scaleFactor)
    property int globalTextSize: 18
    property string homepageUrl: ""
    property string proxyUrl: ""   // Proxy used to fetch http(s) URLs ("" = none)
    property int proxyPort: 0
    property bool isBookmarked: false
    property bool showSettingsPage: false
    property bool showBookmarksPage: false
    // History is owned by the root window (main.qml); only the computed
    // back/forward availability is needed down here for the URL bar buttons.
    property bool canGoBack: false
    property bool canGoForward: false
    property string currentPageContent: "Welcome to the Gemini Browser!\n\nEnter a Gemini URL above to begin browsing."
    property var lastClickedElement: null  // Store the link element that was clicked for inline image insertion

    // Returns true when a URL may be navigated to. HTTP(S) URLs are only
    // navigable when a proxy is configured; otherwise the http-link dialog is
    // shown and navigation is cancelled (so no history entry is made either).
    function shouldNavigate(url) {
        if (!url) return false
        var lower = url.toLowerCase()
        var isHttp = lower.indexOf("http://") === 0 || lower.indexOf("https://") === 0
        if (!isHttp) return true
        var hasProxy = proxyUrl && proxyUrl.length > 0 && proxyPort > 0
        if (!hasProxy) {
            httpLinkBlocked(url)
            return false
        }
        return true
    }

    // Function to resolve relative URLs
    function resolveUrl(url, currentUrl) {
        // Handle empty or null URLs
        if (!url || url === "") {
            return url;
        }

        // Handle protocol-relative URLs (starting with //)
        if (url.startsWith("//")) {
            // Extract the protocol from the current URL and prepend it
            var protocolMatch = currentUrl.match(/^([a-zA-Z]+:\/\/)/);
            if (protocolMatch) {
                var protocol = protocolMatch[1];
                return protocol + url.substring(2);
            } else {
                // Fallback: assume gemini protocol
                return "gemini://" + url.substring(2);
            }
        }

        // If it's already an absolute URL, return as-is
        if (url.startsWith("gemini://") || url.startsWith("http://") || url.startsWith("https://")) {
            return url;
        }

        // Parse the current URL
        var baseUrl = currentUrl.split(/[?#]/)[0];

        if (url.startsWith("/")) {
            // Absolute path - resolve from domain root
            var protocolEnd = baseUrl.indexOf("://");
            if (protocolEnd > 0) {
                var domainEnd = baseUrl.indexOf("/", protocolEnd + 3);
                if (domainEnd > 0) {
                    return baseUrl.substring(0, domainEnd) + url;
                } else {
                    return baseUrl + url;
                }
            } else {
                return baseUrl + url;
            }
        } else {
            // Relative path - resolve from current directory
            if (baseUrl.endsWith("/")) {
                return baseUrl + url;
            } else {
                var lastSlash = baseUrl.lastIndexOf("/");
                if (lastSlash > 8) {  // After the protocol part (e.g., after "gemini://domain/")
                    return baseUrl.substring(0, lastSlash + 1) + url;
                } else {
                    return baseUrl + "/" + url;
                }
            }
        }
    }

    onCurrentPageContentChanged: {
    }

    onCurrentUrlChanged: {
    }

    onShowSettingsPageChanged: {
        // Explicitly update the ContentArea
        contentArea.showSettingsPage = showSettingsPage
        // Propagate change back to parent (main.qml)
        if (parent && parent.showSettingsPage !== showSettingsPage) {
            parent.showSettingsPage = showSettingsPage
        }
    }

    onShowBookmarksPageChanged: {
        // Explicitly update the ContentArea
        contentArea.showBookmarksPage = showBookmarksPage
        // Propagate change back to parent (main.qml)
        if (parent && parent.showBookmarksPage !== showBookmarksPage) {
            parent.showBookmarksPage = showBookmarksPage
        }
    }

    
    // Signals
    signal close()
    signal urlChanged(string url)
    signal httpLinkBlocked(string url)
    signal navigateBack()
    signal navigateForward()
    signal navigateHome()
    signal showSettings()
    signal showBookmarks()
    signal toggleBookmark()
    signal refreshPage()
    signal generateCertificateRequested(string commonName)
    signal deleteCertificateRequested(string fingerprint)
    signal deleteAssociationRequested(string domain)
    signal listCertificatesRequested()
    signal listAssociationsRequested()
    signal saveSettingsRequested(var settings)
    signal deleteBookmarkRequested(string url)

    function unloading() {
    }

    function updateContent(content) {
        currentPageContent = content
        // Explicitly update the ContentArea's content
        contentArea.updateContent(content)
    }

    function appendInlineImage(inlineContent, insertAfterElement, imageUrl) {
        // Extract imagePath and mimeType from inline content
        var lines = inlineContent.split('\n')
        var mimeType = lines[0].substring(7) // Remove 'inline/'
        var imagePath = lines[1] || ""
        contentArea.appendInlineImage(mimeType, imagePath, insertAfterElement, imageUrl)
    }

    function updateSettingsPage(settings) {
        // Update SettingsPage via ContentArea
        contentArea.updateSettingsPage(settings)
    }

    function updateCertificates(certs) {
        contentArea.updateCertificates(certs)
    }

    function updateCertificateAssociations(assocs) {
        contentArea.updateCertificateAssociations(assocs)
    }

    function updateBookmarksPage(bookmarks) {
        contentArea.updateBookmarksPage(bookmarks)
    }

    // Font loaders
    FontLoader {
        id: monoFont
        source: "qrc:/fonts/MapleMono-Regular.ttf"
    }

    FontLoader {
        id: monoFontBold
        source: "qrc:/fonts/MapleMono-Bold.ttf"
    }

    // Main layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // URL bar and navigation controls
        URLBar {
            id: urlBar
            Layout.fillWidth: true
            visible: !browserWindow.showSettingsPage && !browserWindow.showBookmarksPage
            onVisibleChanged: {
                    
            }
            scaleFactor: parent.scaleFactor || 2.0
            currentUrl: browserWindow.currentUrl || ""
            showSettingsPage: browserWindow.showSettingsPage || false
            canGoBack: browserWindow.canGoBack
            canGoForward: browserWindow.canGoForward
            isBookmarked: browserWindow.isBookmarked || false

            onUrlSubmitted: (url) => {
                if (!browserWindow.shouldNavigate(url)) return
                browserWindow.currentUrl = url
                browserWindow.urlChanged(url)
            }

            onNavigateBack: browserWindow.navigateBack()
            onNavigateForward: browserWindow.navigateForward()
            onNavigateHome: browserWindow.navigateHome()
            onShowSettings: browserWindow.showSettings()
            onShowBookmarks: browserWindow.showBookmarks()
            onToggleBookmark: browserWindow.toggleBookmark()
            onRefreshPage: browserWindow.refreshPage()
        }

        // Add some padding between header and content
        Rectangle {
            Layout.fillWidth: true
            height: Math.round(10 * scaleFactor)
            color: "transparent"
            visible: !browserWindow.showSettingsPage && !browserWindow.showBookmarksPage
        }

        // Content area
        ContentArea {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            scaleFactor: parent.scaleFactor || 2.0
            globalTextSize: parent.globalTextSize || 18
            globalPadding: parent.globalPadding || 30
            showSettingsPage: parent.showSettingsPage || false
            currentUrl: parent.currentUrl || ""
            currentPageContent: parent.currentPageContent

            onShowSettingsPageChanged: {
                    
            }
                        onUrlClicked: (url, element) => {
                // Resolve relative URLs before navigating
                var resolvedUrl = browserWindow.resolveUrl(url, browserWindow.currentUrl);
                if (!browserWindow.shouldNavigate(resolvedUrl)) return
                // Store the clicked element for inline image insertion
                browserWindow.lastClickedElement = element;
                browserWindow.currentUrl = resolvedUrl;  // Update the current URL
                browserWindow.urlChanged(resolvedUrl);
            }
                        onCertificateGenerationRequested: (commonName) => {
                    
                generateCertificateRequested(commonName)
            }
            onCertificateDeletionRequested: (fingerprint) => {
                    
                deleteCertificateRequested(fingerprint)
            }
            onAssociationDeletionRequested: (domain) => {
                    
                deleteAssociationRequested(domain)
            }
            onDeleteBookmarkRequested: (url) => {
                    
                // Send to backend to delete the bookmark
                endpoint.sendMessage(202, url) // BOOKMARK_REMOVE
            }
            onCertificateListRequested: {
                    
                listCertificatesRequested()
            }
            onAssociationListRequested: {
                    
                listAssociationsRequested()
            }
            onSaveSettingsRequested: (settings) => {
                    
                // Send settings to backend
                endpoint.sendMessage(702, JSON.stringify(settings)) // SETTINGS_SAVE
            }
        }

        // Connect URLBar showUrlInput to modal
        Component.onCompleted: {
            urlBar.showUrlInput.connect(function() {
                    
                urlInputModal.show(browserWindow.currentUrl)
            })
        }
    }

    // URL Input Modal (outside ColumnLayout for proper overlay)
    URLInputModal {
        id: urlInputModal
        anchors.fill: parent
        scaleFactor: browserWindow.scaleFactor || 2.0

        onUrlSubmitted: (url) => {
            if (!browserWindow.shouldNavigate(url)) return
            browserWindow.currentUrl = url
            browserWindow.urlChanged(url)
        }
    }
}