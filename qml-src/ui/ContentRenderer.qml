import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: contentRenderer
    implicitHeight: contentColumn.height

    // Properties
    property string content: ""
    property real scaleFactor: 2
    property int textSize: 18
    property int padding: 30  // Default padding
    property string fontFamily: "DejaVu Sans Mono"

    // Component cache
    property var componentCache: ({})

    // Model to hold all content items
    ListModel {
        id: contentModel
    }

    // Column to hold all content elements
    Column {
        id: contentColumn
        width: parent.width
        spacing: Math.round((textSize * 0.3) * scaleFactor)

        // Repeater to render items from the model
        Repeater {
            id: contentRepeater
            model: contentModel

            delegate: Item {
                width: contentColumn.width
                implicitHeight: element ? element.implicitHeight : 0

                // Property to hold the created element
                property var element: null

                // Create the element when delegate is loaded
                Component.onCompleted: {
                    var delegateItem = this
                    // Access model data using model[index] syntax for ListModel
                    var idx = index
                    var modelType = contentModel.get(idx).type
                    var modelText = contentModel.get(idx).text || ""
                    var modelUrl = contentModel.get(idx).url || ""
                    var modelLevel = contentModel.get(idx).level || 1
                    var modelItems = contentModel.get(idx).items || []
                    var modelListType = contentModel.get(idx).listType || "unordered"
                    var modelImagePath = contentModel.get(idx).imagePath || ""
                    var modelMimeType = contentModel.get(idx).mimeType || ""

                    var elementComponent
                    switch (modelType) {
                        case 'text':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiTextElement.qml")
                            break
                        case 'heading':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiHeadingElement.qml")
                            break
                        case 'link':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiLinkElement.qml")
                            break
                        case 'preformatted':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiPreformattedElement.qml")
                            break
                        case 'blockquote':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiBlockquoteElement.qml")
                            break
                        case 'list':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiListElement.qml")
                            break
                        case 'image':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiImageElement.qml")
                            break
                        case 'inlineImage':
                            elementComponent = Qt.createComponent("qrc:/ui/GeminiInlineImage.qml")
                            break
                        default:
                            return
                    }

                    if (!elementComponent || elementComponent.status !== 1) {
                        return
                    }

                    var props = {
                        "width": contentColumn.width,
                        "scaleFactor": scaleFactor,
                        "textSize": textSize,
                        "padding": padding,
                        "fontFamily": fontFamily
                    }

                    if (modelType === 'text' || modelType === 'heading' || modelType === 'blockquote' || modelType === 'preformatted') {
                        props.text = modelText
                    }
                    if (modelType === 'heading') {
                        props.headingLevel = modelLevel
                    }
                    if (modelType === 'link') {
                        props.url = modelUrl
                        props.text = modelText
                    }
                    if (modelType === 'list') {
                        var parsedItems = modelItems ? JSON.parse(modelItems) : []
                        props.items = parsedItems
                        props.listType = modelListType
                    }
                    if (modelType === 'image') {
                        props.imagePath = modelImagePath
                        props.mimeType = modelMimeType
                    }
                    if (modelType === 'inlineImage') {
                        props.imageUrl = modelImagePath
                        props.mimeType = modelMimeType
                    }

                    element = elementComponent.createObject(delegateItem, props)
                    element.modelIndex = idx

                    if (element) {
                        element.clicked.connect(function(url) { contentRenderer.urlClicked(url, element) })
                    }
                }
            }
        }
    }

    // Signals
    signal urlClicked(string url, var clickedElement)
    signal close()

    function unloading() {
        contentModel.clear()
    }

    // Function to append an inline image to existing content
    // If insertAfterElement is provided, the image is inserted after that element
    // Otherwise, the image is appended to the end
    // imageUrl is the original Gemini URL (used for duplicate detection)
    function appendInlineImage(inlineContent, insertAfterElement, imageUrl) {
        var lines = inlineContent.split('\n')
        var firstLine = lines[0].trim()
        var mimeType = firstLine.substring(7) // Remove 'inline/' (7 chars)
        var imagePath = ""
        if (lines.length > 1) {
            imagePath = lines[1].trim()
        }

        // Check if an inline image with this imageUrl already exists to prevent duplicates
        // Use imageUrl (original URL) instead of imagePath (temp file) for detection
        for (var i = 0; i < contentModel.count; i++) {
            var item = contentModel.get(i)
            if (item && item.type === "inlineImage" && item.imageUrl === imageUrl) {
                return
            }
        }

        // Find the index of the element to insert after
        var insertIndex = contentModel.count
        if (insertAfterElement) {
            // First try to find using model index from element property
            if (insertAfterElement.modelIndex !== undefined && insertAfterElement.modelIndex >= 0) {
                insertIndex = insertAfterElement.modelIndex + 1
            } else {
                // Fallback: search for element in repeater items
                for (var i = 0; i < contentRepeater.items.length; i++) {
                    var item = contentRepeater.items[i]
                    if (item.element === insertAfterElement) {
                        insertIndex = i + 1
                        break
                    }
                }
            }
        }

        // Insert into model at correct position
        contentModel.insert(insertIndex, {
            "type": "inlineImage",
            "imagePath": imagePath,
            "imageUrl": imageUrl,
            "mimeType": mimeType
        })
    }

    // Function to clear all content
    function clearContent() {
        contentModel.clear()
    }

    // Function to parse and display Gemini content (replaces all content)
    function parseAndDisplayGeminiContent(content) {
        clearContent()

        if (!content) {
            content = "No content"
        }

        // Check if this is an image by looking at the first line for MIME type
        var lines = content.split('\n')
        if (lines.length > 0) {
            var firstLine = lines[0].trim()
            if (firstLine.startsWith('inline/image/')) {
                var imagePath = ""
                var mimeType = firstLine.substring(13) // Remove 'inline/image/'
                if (lines.length > 1) {
                    imagePath = lines[1].trim()
                }

                // Note: Duplicate check is only done in appendInlineImage (for clicked links)
                // Here we just add the inline image directly from page content

                contentModel.append({
                    "type": "inlineImage",
                    "imagePath": imagePath,
                    "imageUrl": imagePath,  // Use imagePath as URL for initial content
                    "mimeType": mimeType
                })
                return
            } else if (firstLine.startsWith('image/')) {
                var imagePath = ""
                var mimeType = firstLine
                if (lines.length > 1) {
                    imagePath = lines[1].trim()
                }
                contentModel.append({
                    "type": "image",
                    "imagePath": imagePath,
                    "mimeType": mimeType
                })
                return
            }
        }

        // Parse the content line by line
        var inPreformatted = false
        var preformattedContent = ""
        var listItems = []
        var listType = ""

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            // Handle preformatted text blocks
            if (inPreformatted) {
                if (line.startsWith('`')) {
                    inPreformatted = false
                    contentModel.append({
                        "type": "preformatted",
                        "text": preformattedContent
                    })
                    preformattedContent = ""
                } else {
                    preformattedContent += line + '\n'
                }
                continue
            }

            if (line.startsWith('`')) {
                inPreformatted = true
                continue
            }

            // Handle different line types
            if (line.startsWith('* ') || line.startsWith('- ')) {
                var listItemText = line.substring(2)
                listItems.push(listItemText)
                listType = "unordered"
            } else if (line.startsWith('> ')) {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                contentModel.append({
                    "type": "blockquote",
                    "text": line.substring(2)
                })
            } else if (line.startsWith('### ')) {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                contentModel.append({
                    "type": "heading",
                    "text": line.substring(4),
                    "level": 3
                })
            } else if (line.startsWith('## ')) {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                contentModel.append({
                    "type": "heading",
                    "text": line.substring(3),
                    "level": 2
                })
            } else if (line.startsWith('# ')) {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                contentModel.append({
                    "type": "heading",
                    "text": line.substring(2),
                    "level": 1
                })
            } else if (line.startsWith('=>')) {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                var linkParts = line.substring(2).trim().split(' ')
                var linkUrl = linkParts[0]
                var linkText = linkParts.slice(1).join(' ') || linkUrl
                contentModel.append({
                    "type": "link",
                    "text": linkText,
                    "url": linkUrl
                })
            } else if (line.trim() !== '') {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                contentModel.append({
                    "type": "text",
                    "text": line
                })
            } else {
                if (listItems.length > 0) {
                    renderListItems(listItems, listType)
                    listItems = []
                }
                contentModel.append({
                    "type": "text",
                    "text": ""
                })
            }
        }

        // Render any remaining list items
        if (listItems.length > 0) {
            renderListItems(listItems, listType)
        }
    }

    // Helper function to get or create components
    function getComponent(path) {
        if (componentCache[path]) {
            return componentCache[path]
        }

        var component = Qt.createComponent(path)
        if (component.status === 1 || component.status === 2) {
            componentCache[path] = component
            return component
        }

        return null
    }

    // Helper function to render list items
    function renderListItems(listItems, listType) {
        contentModel.append({
            "type": "list",
            "items": JSON.stringify(listItems),
            "listType": listType
        })
    }

    // Parse content when it changes
    onContentChanged: {
        try {
            parseAndDisplayGeminiContent(content)
        } catch (e) {
        }
    }
}
