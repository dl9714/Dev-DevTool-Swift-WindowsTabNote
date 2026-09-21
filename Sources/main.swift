import AppKit
import UniformTypeIdentifiers

private let appDisplayName = "윈도우탭노트"
private let appEnglishName = "WindowsTabNote"
private let appDisplayVersion = "2026.09.21.034"

private enum TabTitleBuilder {
    static let fallback = "제목 없음"
    private static let sentenceEndings: Set<Character> = [".", "!", "?", "。", "！", "？"]
    private static let scanLimit = 1_024
    private static let generatedTitleLimit = 160

    static func title(from text: String) -> String {
        let prefix = String(text.prefix(scanLimit))
        guard let firstContent = prefix.firstIndex(where: { !$0.isWhitespace }) else {
            return fallback
        }

        var end = prefix.endIndex
        var index = firstContent
        while index < prefix.endIndex {
            let character = prefix[index]
            if character == "\n" || character == "\r" {
                end = index
                break
            }
            if sentenceEndings.contains(character) {
                let next = prefix.index(after: index)
                if next == prefix.endIndex || prefix[next].isWhitespace {
                    end = next
                    break
                }
            }
            index = prefix.index(after: index)
        }

        let sentence = prefix[firstContent..<end]
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !sentence.isEmpty else { return fallback }
        guard sentence.count > generatedTitleLimit else { return sentence }
        return String(sentence.prefix(generatedTitleLimit)) + "…"
    }
}

private struct AppPalette {
    let chrome: NSColor
    let commandBar: NSColor
    let editor: NSColor
    let status: NSColor
    let selectedTab: NSColor
    let hover: NSColor
    let pressed: NSColor
    let border: NSColor
    let text: NSColor
    let secondaryText: NSColor
    let accent: NSColor
    let closeHover: NSColor

    static let dark = AppPalette(
        chrome: NSColor(calibratedRed: 0.105, green: 0.112, blue: 0.125, alpha: 1),
        commandBar: NSColor(calibratedRed: 0.135, green: 0.143, blue: 0.157, alpha: 1),
        editor: NSColor(calibratedRed: 0.118, green: 0.122, blue: 0.133, alpha: 1),
        status: NSColor(calibratedRed: 0.125, green: 0.130, blue: 0.142, alpha: 1),
        selectedTab: NSColor(calibratedRed: 0.175, green: 0.184, blue: 0.200, alpha: 1),
        hover: NSColor(calibratedRed: 0.215, green: 0.225, blue: 0.245, alpha: 1),
        pressed: NSColor(calibratedRed: 0.260, green: 0.270, blue: 0.295, alpha: 1),
        border: NSColor(calibratedRed: 0.285, green: 0.295, blue: 0.318, alpha: 1),
        text: NSColor(calibratedWhite: 0.925, alpha: 1),
        secondaryText: NSColor(calibratedWhite: 0.670, alpha: 1),
        accent: NSColor(calibratedRed: 0.376, green: 0.804, blue: 1.000, alpha: 1),
        closeHover: NSColor(calibratedRed: 0.770, green: 0.170, blue: 0.110, alpha: 1)
    )

    static let softLight = AppPalette(
        chrome: NSColor(calibratedRed: 0.906, green: 0.918, blue: 0.933, alpha: 1),
        commandBar: NSColor(calibratedRed: 0.941, green: 0.945, blue: 0.949, alpha: 1),
        editor: NSColor(calibratedRed: 0.957, green: 0.953, blue: 0.937, alpha: 1),
        status: NSColor(calibratedRed: 0.922, green: 0.922, blue: 0.910, alpha: 1),
        selectedTab: NSColor(calibratedRed: 0.973, green: 0.969, blue: 0.953, alpha: 1),
        hover: NSColor(calibratedRed: 0.867, green: 0.886, blue: 0.906, alpha: 1),
        pressed: NSColor(calibratedRed: 0.804, green: 0.835, blue: 0.867, alpha: 1),
        border: NSColor(calibratedRed: 0.776, green: 0.796, blue: 0.820, alpha: 1),
        text: NSColor(calibratedRed: 0.125, green: 0.137, blue: 0.153, alpha: 1),
        secondaryText: NSColor(calibratedRed: 0.333, green: 0.353, blue: 0.380, alpha: 1),
        accent: NSColor(calibratedRed: 0.000, green: 0.470, blue: 0.840, alpha: 1),
        closeHover: NSColor(calibratedRed: 0.910, green: 0.140, blue: 0.160, alpha: 1)
    )
}

private enum ThemeMode: String {
    case dark
    case softLight

    private static let defaultsKey = "preferredTheme"
    static var current: ThemeMode = {
        guard let stored = UserDefaults.standard.string(forKey: defaultsKey),
              let theme = ThemeMode(rawValue: stored) else { return .dark }
        return theme
    }()

    var palette: AppPalette {
        switch self {
        case .dark: return .dark
        case .softLight: return .softLight
        }
    }

    var appearanceName: NSAppearance.Name {
        switch self {
        case .dark: return .darkAqua
        case .softLight: return .aqua
        }
    }

    static func select(_ theme: ThemeMode) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: defaultsKey)
    }
}

private enum WindowsPalette {
    private static var palette: AppPalette { ThemeMode.current.palette }
    static var chrome: NSColor { palette.chrome }
    static var commandBar: NSColor { palette.commandBar }
    static var editor: NSColor { palette.editor }
    static var status: NSColor { palette.status }
    static var selectedTab: NSColor { palette.selectedTab }
    static var hover: NSColor { palette.hover }
    static var pressed: NSColor { palette.pressed }
    static var border: NSColor { palette.border }
    static var text: NSColor { palette.text }
    static var secondaryText: NSColor { palette.secondaryText }
    static var accent: NSColor { palette.accent }
    static var closeHover: NSColor { palette.closeHover }
}

private final class WindowsChromeView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

private final class HoverButton: NSButton {
    var normalBackgroundColor = NSColor.clear
    var hoverBackgroundColor = WindowsPalette.hover
    var hoverContentTintColor: NSColor?
    private var normalContentTintColor: NSColor?
    private var trackingAreaReference: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

    private func configureAppearance() {
        isBordered = false
        bezelStyle = .inline
        wantsLayer = true
        layer?.cornerRadius = 4
        normalContentTintColor = contentTintColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        normalContentTintColor = contentTintColor
        layer?.backgroundColor = hoverBackgroundColor.cgColor
        if let hoverContentTintColor {
            contentTintColor = hoverContentTintColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = normalBackgroundColor.cgColor
        if let normalContentTintColor {
            contentTintColor = normalContentTintColor
        }
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private enum LineEnding: String, Codable {
    case crlf
    case lf
    case cr

    static func detect(in text: String) -> LineEnding {
        if text.contains("\r\n") { return .crlf }
        if text.contains("\r") { return .cr }
        return .lf
    }

    var displayName: String {
        switch self {
        case .crlf: return "Windows (CRLF)"
        case .lf: return "Unix (LF)"
        case .cr: return "Macintosh (CR)"
        }
    }

    func normalizedForEditing(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    func serialized(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        switch self {
        case .crlf: return normalized.replacingOccurrences(of: "\n", with: "\r\n")
        case .lf: return normalized
        case .cr: return normalized.replacingOccurrences(of: "\n", with: "\r")
        }
    }
}

private struct SessionTabState: Codable {
    let urlPath: String?
    let text: String?
    let customTitle: String?
    let encodingRawValue: UInt
    let lineEnding: LineEnding
    let isDirty: Bool
    let selectionLocation: Int
    let selectionLength: Int
}

private struct AppSessionState: Codable {
    let version: Int
    let tabs: [SessionTabState]
    let activeTabIndex: Int
    let wordWrapEnabled: Bool
    let editorFontSize: Double
    let windowFrame: String?
}

private enum SessionStore {
    private static var directoryURL: URL {
        if let overridePath = ProcessInfo.processInfo.environment["WINDOWSTABNOTE_SESSION_DIRECTORY"],
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport.appendingPathComponent(appEnglishName, isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("Session.json", isDirectory: false)
    }

    static func load() -> AppSessionState? {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(AppSessionState.self, from: data),
              state.version == 1,
              !state.tabs.isEmpty else { return nil }
        return state
    }

    static func save(_ state: AppSessionState) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

private final class WindowsTextView: NSTextView {
    private var boundaryAnchor: Int?
    private var boundaryCaret: Int?
    private var isMovingBoundary = false

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        if !isMovingBoundary {
            boundaryAnchor = nil
            boundaryCaret = nil
        }
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
    }

    override func mouseDown(with event: NSEvent) {
        boundaryAnchor = nil
        boundaryCaret = nil
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Ignore the function flag: dedicated Home/End and Fn+arrows both set it.
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard (event.keyCode == 115 || event.keyCode == 119),
              modifiers.intersection([.command, .option]).isEmpty,
              !hasMarkedText() else {
            boundaryAnchor = nil
            boundaryCaret = nil
            super.keyDown(with: event)
            return
        }

        let home = event.keyCode == 115
        let document = modifiers.contains(.control)
        let selecting = modifiers.contains(.shift)
        let selection = selectedRange()
        let caret = boundaryCaret ?? (selectionAffinity == .upstream ? selection.location : NSMaxRange(selection))
        let anchor = boundaryAnchor ?? (selectionAffinity == .upstream ? NSMaxRange(selection) : selection.location)
        isMovingBoundary = true
        defer { isMovingBoundary = false }
        setSelectedRange(NSRange(location: caret, length: 0), affinity: selectionAffinity, stillSelecting: false)
        switch (home, document) {
        case (true, false): moveToLeftEndOfLine(nil)
        case (false, false): moveToRightEndOfLine(nil)
        case (true, true): moveToBeginningOfDocument(nil)
        case (false, true): moveToEndOfDocument(nil)
        }
        let destination = selectedRange().location
        if selecting {
            // AppKit's alternating Shift+Home/End resets the anchor. Windows keeps it.
            boundaryAnchor = anchor
            boundaryCaret = destination
            setSelectedRange(NSRange(location: min(anchor, destination), length: abs(destination - anchor)),
                             affinity: destination < anchor ? .upstream : .downstream, stillSelecting: false)
        } else {
            boundaryAnchor = nil
            boundaryCaret = nil
        }
        scrollRangeToVisible(NSRange(location: destination, length: 0))
    }
}

private final class DocumentTab {
    let id = UUID()
    var url: URL?
    var encoding: String.Encoding
    var lineEnding: LineEnding
    var isDirty = false
    var isLoading = false
    var customTitle: String?
    private(set) var draftTitle: String
    let containerView = NSView()
    let scrollView = NSScrollView()
    let textView = WindowsTextView(frame: .zero)

    init(text: String = "", url: URL? = nil, encoding: String.Encoding = .utf8) {
        self.url = url
        self.encoding = encoding
        self.lineEnding = text.isEmpty ? .crlf : LineEnding.detect(in: text)
        self.draftTitle = TabTitleBuilder.title(from: text)

        containerView.autoresizingMask = [.width, .height]
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.backgroundColor = WindowsPalette.editor
        textView.textColor = WindowsPalette.text
        textView.insertionPointColor = WindowsPalette.text
        textView.string = lineEnding.normalizedForEditing(text)

        scrollView.documentView = textView
        scrollView.frame = containerView.bounds
        containerView.addSubview(scrollView)
    }

    var displayTitle: String {
        customTitle ?? url?.lastPathComponent ?? draftTitle
    }

    var tabTitle: String {
        isDirty ? "\(displayTitle) •" : displayTitle
    }

    @discardableResult
    func updateDraftTitle(from text: String) -> Bool {
        guard url == nil else { return false }
        let nextTitle = TabTitleBuilder.title(from: text)
        guard nextTitle != draftTitle else { return false }
        draftTitle = nextTitle
        return true
    }
}

private struct TabStripLayout {
    static let spacing: CGFloat = 4
    let viewportWidth: CGFloat
    let tabWidth: CGFloat
    let contentWidth: CGFloat
    let showsOverflow: Bool

    init(windowWidth: CGFloat, count: Int, heldTabWidth: CGFloat? = nil, heldViewportWidth: CGFloat? = nil) {
        let count = max(1, count)
        let gaps = CGFloat(count - 1) * Self.spacing + 10
        let minimumTabWidth: CGFloat = 80
        let maximumTabWidth: CGFloat = 240
        let available = max(60, windowWidth - 232)
        showsOverflow = CGFloat(count) * minimumTabWidth + gaps > available
        let maximumViewport = max(60, available - (showsOverflow ? 32 : 0))
        let naturalWidth = CGFloat(count) * maximumTabWidth + gaps
        viewportWidth = min(maximumViewport, heldViewportWidth ?? naturalWidth)
        let fittedWidth = (viewportWidth - gaps) / CGFloat(count)
        tabWidth = max(minimumTabWidth, min(heldTabWidth ?? maximumTabWidth, fittedWidth))
        contentWidth = max(viewportWidth, CGFloat(count) * tabWidth + gaps)
    }

    func frame(at index: Int) -> NSRect {
        NSRect(x: 5 + CGFloat(index) * (tabWidth + Self.spacing), y: 1, width: tabWidth, height: 36)
    }

    func index(at centerX: CGFloat, count: Int) -> Int {
        min(max(0, count - 1), max(0, Int(floor((centerX - 5) / (tabWidth + Self.spacing)))))
    }
}

private final class TabScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        guard let documentView, documentView.bounds.width > contentSize.width else { return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        let distance = delta * (event.hasPreciseScrollingDeltas ? 1 : 20)
        let x = min(max(0, contentView.bounds.minX - distance), documentView.bounds.width - contentSize.width)
        contentView.scroll(to: NSPoint(x: x, y: 0))
        reflectScrolledClipView(contentView)
    }
}

private final class TabTitleButton: NSButton {
    var dragBegan: ((NSPoint) -> Void)?
    var dragMoved: ((NSPoint) -> Void)?
    var dragEnded: (() -> Void)?
    var middleClicked: (() -> Void)?
    private var mouseOrigin: NSPoint?
    private var dragging = false

    override func mouseDown(with event: NSEvent) {
        mouseOrigin = event.locationInWindow
        dragging = false
        isHighlighted = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseOrigin else { return }
        if !dragging, hypot(event.locationInWindow.x - mouseOrigin.x, event.locationInWindow.y - mouseOrigin.y) >= 5 {
            dragging = true
            isHighlighted = false
            dragBegan?(mouseOrigin)
        }
        if dragging { dragMoved?(event.locationInWindow) }
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseOrigin != nil else { return }
        mouseOrigin = nil
        isHighlighted = false
        if dragging {
            dragging = false
            dragEnded?()
        } else if bounds.contains(convert(event.locationInWindow, from: nil)) {
            performClick(nil)
        }
    }

    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 { middleClicked?() } else { super.otherMouseUp(with: event) }
    }
}

private protocol TabButtonDelegate: AnyObject {
    func selectTab(id: UUID)
    func closeTab(id: UUID)
    func beginRenamingTab(id: UUID)
    func renameTab(id: UUID, title: String)
    func beginDraggingTab(id: UUID, at point: NSPoint)
    func dragTab(id: UUID, to point: NSPoint)
    func endDraggingTab(id: UUID)
}

private final class TabRenameEditor: NSViewController, NSTextFieldDelegate {
    let nameField = NSTextField()
    let confirmButton = NSButton(title: "변경", target: nil, action: nil)
    var onFinish: ((Bool) -> Void)?
    private let initialTitle: String
    let preferredWidth: CGFloat

    static func width(for windowWidth: CGFloat) -> CGFloat {
        min(420, max(300, windowWidth - 24))
    }

    init(title: String, width: CGFloat = 420) {
        initialTitle = title
        preferredWidth = width
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: preferredWidth, height: 138))
        let heading = NSTextField(labelWithString: "탭 이름 변경")
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        heading.textColor = WindowsPalette.text
        let hint = NSTextField(labelWithString: "Enter로 변경 · Esc로 취소")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = WindowsPalette.secondaryText

        nameField.stringValue = initialTitle
        nameField.font = .systemFont(ofSize: 15)
        nameField.textColor = WindowsPalette.text
        nameField.backgroundColor = WindowsPalette.editor
        nameField.isEditable = true
        nameField.isSelectable = true
        nameField.isBezeled = true
        nameField.bezelStyle = .roundedBezel
        nameField.usesSingleLineMode = true
        nameField.cell?.isScrollable = true
        nameField.delegate = self
        nameField.setAccessibilityLabel("탭 이름")
        nameField.placeholderString = "탭 이름을 입력하세요"

        confirmButton.target = self
        confirmButton.action = #selector(confirmName(_:))
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "취소", target: self, action: #selector(cancelName(_:)))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        for control in [heading, nameField, hint, cancelButton, confirmButton] {
            control.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(control)
        }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            heading.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameField.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10),
            nameField.heightAnchor.constraint(equalToConstant: 32),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            confirmButton.widthAnchor.constraint(equalToConstant: 64),
            cancelButton.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: confirmButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 64),
            hint.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            hint.centerYAnchor.constraint(equalTo: confirmButton.centerYAnchor)
        ])
        updateValidation()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        nameField.selectText(nil)
    }

    var editedTitle: String { nameField.currentEditor()?.string ?? nameField.stringValue }

    private func updateValidation() {
        confirmButton.isEnabled = !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func controlTextDidChange(_ notification: Notification) {
        updateValidation()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            confirmName(nil)
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            cancelName(nil)
            return true
        }
        return false
    }

    @objc private func confirmName(_ sender: Any?) {
        updateValidation()
        guard confirmButton.isEnabled else { NSSound.beep(); return }
        onFinish?(true)
    }

    @objc private func cancelName(_ sender: Any?) {
        onFinish?(false)
    }
}

private final class TabButtonView: NSView, NSPopoverDelegate {
    let tabID: UUID
    weak var delegate: TabButtonDelegate?

    private let titleButton = TabTitleButton()
    private let closeButton = NSButton()
    private var renamePopover: NSPopover?
    private var renameEditor: TabRenameEditor?
    private(set) var isRenaming = false

    init(tabID: UUID, delegate: TabButtonDelegate) {
        self.tabID = tabID
        self.delegate = delegate
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6

        titleButton.isBordered = false
        titleButton.bezelStyle = .inline
        titleButton.alignment = .left
        titleButton.font = .systemFont(ofSize: 12.5, weight: .regular)
        titleButton.lineBreakMode = .byTruncatingTail
        titleButton.target = self
        titleButton.action = #selector(selectPressed)
        titleButton.translatesAutoresizingMaskIntoConstraints = false
        titleButton.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        titleButton.dragBegan = { [weak self] point in
            guard let self else { return }
            self.delegate?.beginDraggingTab(id: self.tabID, at: point)
        }
        titleButton.dragMoved = { [weak self] point in
            guard let self else { return }
            self.delegate?.dragTab(id: self.tabID, to: point)
        }
        titleButton.dragEnded = { [weak self] in
            guard let self else { return }
            self.delegate?.endDraggingTab(id: self.tabID)
        }
        titleButton.middleClicked = { [weak self] in self?.closePressed() }

        closeButton.title = ""
        closeButton.image = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "탭 닫기"
        )?.withSymbolConfiguration(.init(pointSize: 9, weight: .medium))
        closeButton.imagePosition = .imageOnly
        closeButton.toolTip = "탭 닫기 (⌘W / Ctrl+W)"
        closeButton.isBordered = false
        closeButton.bezelStyle = .inline
        closeButton.contentTintColor = WindowsPalette.secondaryText
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -3),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, selected: Bool, toolTip: String?) {
        titleButton.title = title
        let clickHint = selected ? "다시 클릭: 이름 변경" : "클릭: 탭 선택"
        titleButton.toolTip = "\(toolTip ?? title)\n\(clickHint) · 드래그: 순서 변경 · 가운데 클릭: 닫기"
        titleButton.contentTintColor = selected ? WindowsPalette.text : WindowsPalette.secondaryText
        closeButton.contentTintColor = selected ? WindowsPalette.text : WindowsPalette.secondaryText
        layer?.backgroundColor = selected ? WindowsPalette.selectedTab.cgColor : NSColor.clear.cgColor
        layer?.borderColor = selected ? WindowsPalette.border.cgColor : NSColor.clear.cgColor
        layer?.borderWidth = selected ? 0.75 : 0
    }

    @objc private func selectPressed() {
        delegate?.beginRenamingTab(id: tabID)
    }

    func beginRenaming(title: String) {
        guard !isRenaming, let window else { return }
        let width = TabRenameEditor.width(for: window.contentView?.bounds.width ?? 444)
        let editor = TabRenameEditor(title: title, width: width)
        let popover = NSPopover()
        popover.contentViewController = editor
        popover.contentSize = NSSize(width: width, height: 138)
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = window.effectiveAppearance
        popover.delegate = self
        editor.onFinish = { [weak self] commit in
            guard let self else { return }
            self.finishRenaming(commit: commit)
            self.delegate?.selectTab(id: self.tabID)
        }
        renameEditor = editor
        renamePopover = popover
        isRenaming = true
        // Anchor to the visible part, even when the strip is scrolled at an edge.
        let anchor = bounds.intersection(visibleRect)
        popover.show(relativeTo: anchor.isEmpty ? bounds : anchor, of: self, preferredEdge: .minY)
    }

    func finishRenaming(commit: Bool) {
        finishRenaming(commit: commit, closePopover: true)
    }

    private func finishRenaming(commit: Bool, closePopover: Bool) {
        guard isRenaming else { return }
        let title = renameEditor?.editedTitle ?? titleButton.title
        let popover = renamePopover
        isRenaming = false
        renameEditor?.onFinish = nil
        renameEditor = nil
        renamePopover = nil
        popover?.delegate = nil
        if commit { delegate?.renameTab(id: tabID, title: title) }
        if closePopover { popover?.close() }
    }

    func popoverWillClose(_ notification: Notification) {
        // Clicking outside saves the edit, as the inline editor did.
        finishRenaming(commit: true, closePopover: false)
    }

    @objc private func closePressed() {
        finishRenaming(commit: true)
        delegate?.closeTab(id: tabID)
    }
}

private final class MainWindowController: NSWindowController,
                                          NSWindowDelegate,
                                          NSTextViewDelegate,
                                          TabButtonDelegate,
                                          NSMenuItemValidation {
    private var documents: [DocumentTab] = []
    private var activeDocumentID: UUID?
    private var wordWrapEnabled = true
    private var editorFontSize: CGFloat = 14
    private var terminationWasApproved = false
    private var documentByTextView: [ObjectIdentifier: DocumentTab] = [:]
    private var restoredSelectionByDocumentID: [UUID: NSRange] = [:]
    private var tabButtonsByID: [UUID: TabButtonView] = [:]
    private var draggingTabID: UUID?
    private var dragOffsetX: CGFloat = 0
    private var dragPoint: NSPoint?
    private var dragScrollTimer: Timer?
    private var rapidCloseStripWidth: CGFloat?
    private var rapidCloseTabWidth: CGFloat?
    private var keyboardMonitor: Any?
    private var mouseMonitor: Any?
    private var sessionSaveWorkItem: DispatchWorkItem?
    private let sessionWriteQueue = DispatchQueue(
        label: "local.codex.windowstabnote.session",
        qos: .utility
    )
    private var statusUpdateGeneration = 0
    private var statusCharacterBuffer = [unichar](repeating: 0, count: 8_192)

    private let rootView = NSView()
    private let tabBar = WindowsChromeView()
    private let tabScrollView = TabScrollView()
    private let tabDocumentView = FlippedView()
    private let appIconView = NSImageView()
    private let tabOverflowButton = HoverButton()
    private let addTabButton = HoverButton()
    private let minimizeButton = HoverButton()
    private let maximizeButton = HoverButton()
    private let windowCloseButton = HoverButton()
    private let commandBar = NSView()
    private let menuStack = NSStackView()
    private let formattingStack = NSStackView()
    private let settingsButton = HoverButton()
    private let chromeDivider = NSView()
    private let editorHost = NSView()
    private let statusBar = NSView()
    private let statusDivider = NSView()
    private let cursorStatusLabel = NSTextField(labelWithString: "1행 1열")
    private let documentStatusLabel = NSTextField(labelWithString: "UTF-8   |   100%")
    private var tabScrollWidthConstraint: NSLayoutConstraint?
    private var tabOverflowWidthConstraint: NSLayoutConstraint?
    private var formattingLeadingConstraint: NSLayoutConstraint?
    private var formattingTrailingConstraint: NSLayoutConstraint?

    private var activeDocument: DocumentTab? {
        guard let activeDocumentID else { return nil }
        return documents.first { $0.id == activeDocumentID }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = appDisplayName
        window.minSize = NSSize(width: 340, height: 220)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.appearance = NSAppearance(named: ThemeMode.current.appearanceName)
        window.backgroundColor = WindowsPalette.chrome
        window.tabbingMode = .disallowed
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()

        super.init(window: window)
        window.delegate = self

        configureInterface()
        window.contentMinSize = NSSize(width: 340, height: 220)
        window.minSize = NSSize(width: 340, height: 220)
        configureMainMenu()
        installKeyboardShortcuts()
        if !restoreSession() {
            createNewTab()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        dragScrollTimer?.invalidate()
        sessionSaveWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }

    private func configureInterface() {
        guard let window else { return }
        window.contentView = rootView
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = WindowsPalette.editor.cgColor
        rootView.appearance = NSAppearance(named: ThemeMode.current.appearanceName)

        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = WindowsPalette.chrome.cgColor
        tabBar.translatesAutoresizingMaskIntoConstraints = false

        tabScrollView.documentView = tabDocumentView
        tabScrollView.drawsBackground = false
        tabScrollView.borderType = .noBorder
        tabScrollView.hasHorizontalScroller = false
        tabScrollView.scrollerStyle = .overlay
        tabScrollView.autohidesScrollers = true
        tabScrollView.automaticallyAdjustsContentInsets = false
        tabScrollView.contentInsets = NSEdgeInsets()
        tabScrollView.horizontalScrollElasticity = .none
        tabScrollView.translatesAutoresizingMaskIntoConstraints = false


        appIconView.image = NSApp.applicationIconImage
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false

        tabOverflowButton.title = ""
        tabOverflowButton.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: "모든 탭"
        )?.withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        tabOverflowButton.imagePosition = .imageOnly
        tabOverflowButton.contentTintColor = WindowsPalette.text
        tabOverflowButton.toolTip = "모든 탭"
        tabOverflowButton.target = self
        tabOverflowButton.action = #selector(showTabOverflowMenu(_:))
        tabOverflowButton.translatesAutoresizingMaskIntoConstraints = false
        tabOverflowButton.isHidden = true

        addTabButton.title = ""
        addTabButton.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "새 탭"
        )?.withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        addTabButton.imagePosition = .imageOnly
        addTabButton.contentTintColor = WindowsPalette.text
        addTabButton.toolTip = "새 탭 (⌘T)"
        addTabButton.target = self
        addTabButton.action = #selector(newTabAction(_:))
        addTabButton.translatesAutoresizingMaskIntoConstraints = false

        configureWindowButton(minimizeButton, symbol: "minus", action: #selector(minimizeWindowAction(_:)))
        configureWindowButton(maximizeButton, symbol: "square", action: #selector(maximizeWindowAction(_:)))
        configureWindowButton(windowCloseButton, symbol: "xmark", action: #selector(closeWindowAction(_:)), isClose: true)

        commandBar.wantsLayer = true
        commandBar.layer?.backgroundColor = WindowsPalette.commandBar.cgColor
        commandBar.translatesAutoresizingMaskIntoConstraints = false

        menuStack.orientation = .horizontal
        menuStack.alignment = .centerY
        menuStack.distribution = .fill
        menuStack.spacing = 0
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuStack.addArrangedSubview(makeMenuButton(title: "파일", action: #selector(showFileMenu(_:))))
        menuStack.addArrangedSubview(makeMenuButton(title: "편집", action: #selector(showEditMenu(_:))))
        menuStack.addArrangedSubview(makeMenuButton(title: "보기", action: #selector(showViewMenu(_:))))

        formattingStack.orientation = .horizontal
        formattingStack.alignment = .centerY
        formattingStack.distribution = .fill
        formattingStack.spacing = 2
        formattingStack.translatesAutoresizingMaskIntoConstraints = false
        formattingStack.addArrangedSubview(makeToolbarButton(text: "H1", toolTip: "제목", action: #selector(insertHeadingAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "list.bullet", toolTip: "글머리 기호 목록", action: #selector(insertListAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "bold", toolTip: "굵게", action: #selector(insertBoldAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "italic", toolTip: "기울임", action: #selector(insertItalicAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "strikethrough", toolTip: "취소선", action: #selector(insertStrikethroughAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "link", toolTip: "링크", action: #selector(insertLinkAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "photo", toolTip: "이미지 마크다운", action: #selector(insertImageAction(_:))))
        formattingStack.addArrangedSubview(makeToolbarButton(symbol: "tablecells", toolTip: "표 삽입", action: #selector(insertTableAction(_:))))

        settingsButton.title = ""
        settingsButton.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "설정"
        )?.withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        settingsButton.imagePosition = .imageOnly
        settingsButton.contentTintColor = WindowsPalette.text
        settingsButton.toolTip = "설정"
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsMenu(_:))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        chromeDivider.wantsLayer = true
        chromeDivider.layer?.backgroundColor = WindowsPalette.border.cgColor
        chromeDivider.translatesAutoresizingMaskIntoConstraints = false

        editorHost.translatesAutoresizingMaskIntoConstraints = false
        editorHost.wantsLayer = true
        editorHost.layer?.backgroundColor = WindowsPalette.editor.cgColor

        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = WindowsPalette.status.cgColor
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusDivider.wantsLayer = true
        statusDivider.layer?.backgroundColor = WindowsPalette.border.cgColor
        statusDivider.translatesAutoresizingMaskIntoConstraints = false

        cursorStatusLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        cursorStatusLabel.textColor = WindowsPalette.secondaryText
        cursorStatusLabel.alignment = .right
        cursorStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        documentStatusLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        documentStatusLabel.textColor = WindowsPalette.secondaryText
        documentStatusLabel.alignment = .right
        documentStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(tabBar)
        rootView.addSubview(commandBar)
        rootView.addSubview(editorHost)
        rootView.addSubview(statusBar)
        tabBar.addSubview(appIconView)
        tabBar.addSubview(tabScrollView)
        tabBar.addSubview(tabOverflowButton)
        tabBar.addSubview(addTabButton)
        tabBar.addSubview(minimizeButton)
        tabBar.addSubview(maximizeButton)
        tabBar.addSubview(windowCloseButton)
        commandBar.addSubview(menuStack)
        commandBar.addSubview(formattingStack)
        commandBar.addSubview(settingsButton)
        commandBar.addSubview(chromeDivider)
        statusBar.addSubview(statusDivider)
        statusBar.addSubview(cursorStatusLabel)
        statusBar.addSubview(documentStatusLabel)

        tabScrollWidthConstraint = tabScrollView.widthAnchor.constraint(equalToConstant: 248)
        // A required current width becomes AppKit's live-resize minimum.
        tabScrollWidthConstraint?.priority = .defaultLow
        tabScrollWidthConstraint?.isActive = true
        tabOverflowWidthConstraint = tabOverflowButton.widthAnchor.constraint(equalToConstant: 0)
        tabOverflowWidthConstraint?.isActive = true

        let formattingLeading = formattingStack.leadingAnchor.constraint(
            greaterThanOrEqualTo: menuStack.trailingAnchor,
            constant: 34
        )
        let formattingTrailing = formattingStack.trailingAnchor.constraint(
            lessThanOrEqualTo: settingsButton.leadingAnchor,
            constant: -20
        )
        formattingLeading.priority = NSLayoutConstraint.Priority(1)
        formattingTrailing.priority = NSLayoutConstraint.Priority(1)
        formattingLeadingConstraint = formattingLeading
        formattingTrailingConstraint = formattingTrailing

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: rootView.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 47),

            appIconView.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 13),
            appIconView.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor, constant: 1),
            appIconView.widthAnchor.constraint(equalToConstant: 20),
            appIconView.heightAnchor.constraint(equalToConstant: 20),

            tabScrollView.leadingAnchor.constraint(equalTo: appIconView.trailingAnchor, constant: 10),
            tabScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            tabScrollView.topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 7),
            tabScrollView.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: -2),

            tabOverflowButton.leadingAnchor.constraint(equalTo: tabScrollView.trailingAnchor, constant: 3),
            tabOverflowButton.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor, constant: 1),
            tabOverflowButton.heightAnchor.constraint(equalToConstant: 34),

            addTabButton.leadingAnchor.constraint(equalTo: tabOverflowButton.trailingAnchor, constant: 2),
            addTabButton.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor, constant: 1),
            addTabButton.widthAnchor.constraint(equalToConstant: 36),
            addTabButton.heightAnchor.constraint(equalToConstant: 34),
            addTabButton.trailingAnchor.constraint(lessThanOrEqualTo: minimizeButton.leadingAnchor, constant: -10),

            windowCloseButton.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            windowCloseButton.topAnchor.constraint(equalTo: tabBar.topAnchor),
            windowCloseButton.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            windowCloseButton.widthAnchor.constraint(equalToConstant: 46),
            maximizeButton.trailingAnchor.constraint(equalTo: windowCloseButton.leadingAnchor),
            maximizeButton.topAnchor.constraint(equalTo: tabBar.topAnchor),
            maximizeButton.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            maximizeButton.widthAnchor.constraint(equalToConstant: 46),
            minimizeButton.trailingAnchor.constraint(equalTo: maximizeButton.leadingAnchor),
            minimizeButton.topAnchor.constraint(equalTo: tabBar.topAnchor),
            minimizeButton.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            minimizeButton.widthAnchor.constraint(equalToConstant: 46),

            commandBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            commandBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            commandBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            commandBar.heightAnchor.constraint(equalToConstant: 41),

            menuStack.leadingAnchor.constraint(equalTo: commandBar.leadingAnchor, constant: 13),
            menuStack.centerYAnchor.constraint(equalTo: commandBar.centerYAnchor),
            formattingStack.centerXAnchor.constraint(equalTo: commandBar.centerXAnchor),
            formattingStack.centerYAnchor.constraint(equalTo: commandBar.centerYAnchor),
            formattingLeading,
            formattingTrailing,
            settingsButton.trailingAnchor.constraint(equalTo: commandBar.trailingAnchor, constant: -12),
            settingsButton.centerYAnchor.constraint(equalTo: commandBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 34),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            chromeDivider.leadingAnchor.constraint(equalTo: commandBar.leadingAnchor),
            chromeDivider.trailingAnchor.constraint(equalTo: commandBar.trailingAnchor),
            chromeDivider.bottomAnchor.constraint(equalTo: commandBar.bottomAnchor),
            chromeDivider.heightAnchor.constraint(equalToConstant: 0.75),

            editorHost.topAnchor.constraint(equalTo: commandBar.bottomAnchor),
            editorHost.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            editorHost.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            editorHost.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 27),

            statusDivider.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor),
            statusDivider.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor),
            statusDivider.topAnchor.constraint(equalTo: statusBar.topAnchor),
            statusDivider.heightAnchor.constraint(equalToConstant: 0.75),

            cursorStatusLabel.trailingAnchor.constraint(equalTo: documentStatusLabel.leadingAnchor, constant: -18),
            cursorStatusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            documentStatusLabel.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -14),
            documentStatusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
        updateResponsiveLayout()
    }

    private func configureWindowButton(_ button: HoverButton,
                                       symbol: String,
                                       action: Selector,
                                       isClose: Bool = false) {
        button.title = ""
        button.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        button.imagePosition = .imageOnly
        button.contentTintColor = WindowsPalette.text
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer?.cornerRadius = 0
        let label = isClose ? "닫기" : (symbol == "minus" ? "최소화" : "최대화")
        button.setAccessibilityLabel(label)
        button.toolTip = label
        if isClose {
            button.hoverBackgroundColor = WindowsPalette.closeHover
            button.hoverContentTintColor = .white
        }
    }

    private func makeMenuButton(title: String, action: Selector) -> HoverButton {
        let button = HoverButton()
        button.title = title
        button.font = .systemFont(ofSize: 13, weight: .regular)
        button.contentTintColor = WindowsPalette.text
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 52).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    private func makeToolbarButton(symbol: String? = nil,
                                   text: String? = nil,
                                   toolTip: String,
                                   action: Selector) -> HoverButton {
        let button = HoverButton()
        if let symbol {
            button.image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: toolTip
            )?.withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.title = text ?? ""
            button.font = .systemFont(ofSize: 15, weight: .regular)
        }
        button.contentTintColor = WindowsPalette.text
        button.toolTip = toolTip
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: appDisplayName)
        appMenuItem.submenu = appMenu
        addMenuItem(appMenu, title: "윈도우탭노트에 관하여", action: #selector(showAbout(_:)), target: self)
        appMenu.addItem(.separator())
        addMenuItem(appMenu, title: "윈도우탭노트 종료", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "파일")
        fileMenuItem.submenu = fileMenu
        addMenuItem(fileMenu, title: "새 탭", action: #selector(newTabAction(_:)), key: "t", target: self)
        addMenuItem(fileMenu, title: "새 메모", action: #selector(newTabAction(_:)), key: "n", target: self)
        addMenuItem(fileMenu, title: "열기…", action: #selector(openAction(_:)), key: "o", target: self)
        fileMenu.addItem(.separator())
        addMenuItem(fileMenu, title: "저장", action: #selector(saveAction(_:)), key: "s", target: self)
        addMenuItem(fileMenu, title: "다른 이름으로 저장…", action: #selector(saveAsAction(_:)), key: "s", modifiers: [.command, .shift], target: self)
        fileMenu.addItem(.separator())
        addMenuItem(fileMenu, title: "탭 닫기", action: #selector(closeTabAction(_:)), key: "w", target: self)
        addMenuItem(fileMenu, title: "창 닫기", action: #selector(performCloseWindow(_:)), key: "w", modifiers: [.command, .shift], target: self)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "편집")
        editMenuItem.submenu = editMenu
        addMenuItem(editMenu, title: "실행 취소", action: Selector(("undo:")), key: "z")
        addMenuItem(editMenu, title: "다시 실행", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift])
        editMenu.addItem(.separator())
        addMenuItem(editMenu, title: "오려두기", action: #selector(NSText.cut(_:)), key: "x")
        addMenuItem(editMenu, title: "복사", action: #selector(NSText.copy(_:)), key: "c")
        addMenuItem(editMenu, title: "붙여넣기", action: #selector(NSText.paste(_:)), key: "v")
        addMenuItem(editMenu, title: "모두 선택", action: #selector(NSText.selectAll(_:)), key: "a")
        editMenu.addItem(.separator())

        let findItem = NSMenuItem(title: "찾기", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "찾기")
        findItem.submenu = findMenu
        editMenu.addItem(findItem)
        addFindMenuItem(findMenu, title: "찾기…", action: .showFindPanel, key: "f")
        addTextFinderMenuItem(findMenu, title: "찾기 및 바꾸기…", actionTag: 12, key: "f", modifiers: [.command, .option])
        addFindMenuItem(findMenu, title: "다음 찾기", action: .next, key: "g")
        addFindMenuItem(findMenu, title: "이전 찾기", action: .previous, key: "g", modifiers: [.command, .shift])
        addFindMenuItem(findMenu, title: "선택 부분을 찾기에 사용", action: .setFindString, key: "e")
        addMenuItem(editMenu, title: "줄로 이동…", action: #selector(goToLineAction(_:)), key: "l", target: self)

        let formatMenuItem = NSMenuItem()
        mainMenu.addItem(formatMenuItem)
        let formatMenu = NSMenu(title: "서식")
        formatMenuItem.submenu = formatMenu
        let wrapItem = addMenuItem(formatMenu, title: "자동 줄 바꿈", action: #selector(toggleWordWrapAction(_:)), target: self)
        wrapItem.state = .on

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "보기")
        viewMenuItem.submenu = viewMenu
        addMenuItem(viewMenu, title: "확대", action: #selector(zoomInAction(_:)), key: "+", target: self)
        addMenuItem(viewMenu, title: "축소", action: #selector(zoomOutAction(_:)), key: "-", target: self)
        addMenuItem(viewMenu, title: "원래 크기", action: #selector(resetZoomAction(_:)), key: "0", target: self)
        viewMenu.addItem(.separator())
        addThemeMenuItems(to: viewMenu)
        viewMenu.addItem(.separator())
        addMenuItem(viewMenu, title: "전체 화면 시작/종료", action: #selector(NSWindow.toggleFullScreen(_:)), key: "f", modifiers: [.command, .control])

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "윈도우")
        windowMenuItem.submenu = windowMenu
        addMenuItem(windowMenu, title: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), key: "m")
        addMenuItem(windowMenu, title: "확대/축소", action: #selector(NSWindow.performZoom(_:)))
        NSApp.windowsMenu = windowMenu
    }

    @discardableResult
    private func addMenuItem(_ menu: NSMenu,
                             title: String,
                             action: Selector?,
                             key: String = "",
                             modifiers: NSEvent.ModifierFlags = [.command],
                             target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        menu.addItem(item)
        return item
    }

    private func addFindMenuItem(_ menu: NSMenu,
                                 title: String,
                                 action: NSFindPanelAction,
                                 key: String,
                                 modifiers: NSEvent.ModifierFlags = [.command]) {
        let item = NSMenuItem(title: title, action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.tag = Int(action.rawValue)
        menu.addItem(item)
    }

    private func addTextFinderMenuItem(_ menu: NSMenu,
                                       title: String,
                                       actionTag: Int,
                                       key: String,
                                       modifiers: NSEvent.ModifierFlags = [.command]) {
        let item = NSMenuItem(title: title, action: #selector(NSTextView.performTextFinderAction(_:)), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.tag = actionTag
        menu.addItem(item)
    }

    private func addThemeMenuItems(to menu: NSMenu) {
        let dark = addMenuItem(menu, title: "다크 모드", action: #selector(setDarkThemeAction(_:)), target: self)
        dark.state = ThemeMode.current == .dark ? .on : .off
        let light = addMenuItem(
            menu,
            title: "라이트 모드 (눈부심 완화)",
            action: #selector(setSoftLightThemeAction(_:)),
            target: self
        )
        light.state = ThemeMode.current == .softLight ? .on : .off
    }

    private func presentPopupMenu(_ menu: NSMenu, from sender: NSButton) {
        menu.appearance = NSAppearance(named: ThemeMode.current.appearanceName)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
    }

    @objc private func showTabOverflowMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "모든 탭")
        for document in documents {
            let item = NSMenuItem(
                title: document.tabTitle,
                action: #selector(selectTabFromOverflowMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = document.id.uuidString
            item.state = document.id == activeDocumentID ? .on : .off
            item.toolTip = document.url?.path ?? document.displayTitle
            menu.addItem(item)
        }
        presentPopupMenu(menu, from: sender)
    }

    @objc private func selectTabFromOverflowMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let id = UUID(uuidString: identifier) else { return }
        selectTab(id: id)
    }

    @objc private func showFileMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "파일")
        addMenuItem(menu, title: "새 탭", action: #selector(newTabAction(_:)), key: "t", target: self)
        addMenuItem(menu, title: "새 메모", action: #selector(newTabAction(_:)), key: "n", target: self)
        addMenuItem(menu, title: "열기…", action: #selector(openAction(_:)), key: "o", target: self)
        menu.addItem(.separator())
        addMenuItem(menu, title: "저장", action: #selector(saveAction(_:)), key: "s", target: self)
        addMenuItem(menu, title: "다른 이름으로 저장…", action: #selector(saveAsAction(_:)), key: "s", modifiers: [.command, .shift], target: self)
        menu.addItem(.separator())
        addMenuItem(menu, title: "탭 닫기", action: #selector(closeTabAction(_:)), key: "w", target: self)
        presentPopupMenu(menu, from: sender)
    }

    @objc private func showEditMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "편집")
        addMenuItem(menu, title: "실행 취소", action: Selector(("undo:")), key: "z")
        addMenuItem(menu, title: "다시 실행", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift])
        menu.addItem(.separator())
        addMenuItem(menu, title: "오려두기", action: #selector(NSText.cut(_:)), key: "x")
        addMenuItem(menu, title: "복사", action: #selector(NSText.copy(_:)), key: "c")
        addMenuItem(menu, title: "붙여넣기", action: #selector(NSText.paste(_:)), key: "v")
        addMenuItem(menu, title: "모두 선택", action: #selector(NSText.selectAll(_:)), key: "a")
        menu.addItem(.separator())
        addFindMenuItem(menu, title: "찾기…", action: .showFindPanel, key: "f")
        addTextFinderMenuItem(menu, title: "찾기 및 바꾸기…", actionTag: 12, key: "f", modifiers: [.command, .option])
        addMenuItem(menu, title: "줄로 이동…", action: #selector(goToLineAction(_:)), key: "l", target: self)
        presentPopupMenu(menu, from: sender)
    }

    @objc private func showViewMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "보기")
        addMenuItem(menu, title: "확대", action: #selector(zoomInAction(_:)), key: "+", target: self)
        addMenuItem(menu, title: "축소", action: #selector(zoomOutAction(_:)), key: "-", target: self)
        addMenuItem(menu, title: "원래 크기", action: #selector(resetZoomAction(_:)), key: "0", target: self)
        menu.addItem(.separator())
        let wrap = addMenuItem(menu, title: "자동 줄 바꿈", action: #selector(toggleWordWrapAction(_:)), target: self)
        wrap.state = wordWrapEnabled ? .on : .off
        menu.addItem(.separator())
        addThemeMenuItems(to: menu)
        menu.addItem(.separator())
        addMenuItem(menu, title: "전체 화면", action: #selector(NSWindow.toggleFullScreen(_:)), key: "f", modifiers: [.command, .control])
        presentPopupMenu(menu, from: sender)
    }

    @objc private func showSettingsMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "설정")
        let styleItem = NSMenuItem(title: "Windows 11 메모장 스타일", action: nil, keyEquivalent: "")
        styleItem.isEnabled = false
        menu.addItem(styleItem)
        menu.addItem(.separator())
        addThemeMenuItems(to: menu)
        menu.addItem(.separator())
        let wrap = addMenuItem(menu, title: "자동 줄 바꿈", action: #selector(toggleWordWrapAction(_:)), target: self)
        wrap.state = wordWrapEnabled ? .on : .off
        addMenuItem(menu, title: "확대/축소 초기화", action: #selector(resetZoomAction(_:)), target: self)
        menu.addItem(.separator())
        addMenuItem(menu, title: "앱 정보", action: #selector(showAbout(_:)), target: self)
        presentPopupMenu(menu, from: sender)
    }

    func showWindowAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusEditor()
    }

    private func restoreSession() -> Bool {
        guard let state = SessionStore.load() else { return false }

        wordWrapEnabled = state.wordWrapEnabled
        editorFontSize = CGFloat(min(48, max(8, state.editorFontSize)))
        if let savedFrame = state.windowFrame {
            _ = window?.setFrame(from: savedFrame)
        }

        var documentsToLoad: [(UUID, URL)] = []
        for tabState in state.tabs {
            let url = tabState.urlPath.map { URL(fileURLWithPath: $0).standardizedFileURL }
            let document = DocumentTab(
                text: tabState.text ?? "",
                url: url,
                encoding: String.Encoding(rawValue: tabState.encodingRawValue)
            )
            document.lineEnding = tabState.lineEnding
            document.customTitle = tabState.customTitle
            document.isDirty = tabState.isDirty
            if tabState.text == nil, let url {
                document.isLoading = true
                document.textView.isEditable = false
                documentsToLoad.append((document.id, url))
                restoredSelectionByDocumentID[document.id] = NSRange(
                    location: max(0, tabState.selectionLocation),
                    length: max(0, tabState.selectionLength)
                )
            }
            configure(document: document)

            if tabState.text != nil {
                let textLength = document.textView.string.utf16.count
                let location = min(max(0, tabState.selectionLocation), textLength)
                let length = min(max(0, tabState.selectionLength), textLength - location)
                document.textView.setSelectedRange(NSRange(location: location, length: length))
            }
            documents.append(document)
        }

        guard !documents.isEmpty else { return false }
        let activeIndex = min(max(0, state.activeTabIndex), documents.count - 1)
        activeDocumentID = documents[activeIndex].id
        refreshTabs()
        showActiveDocument()
        if let activeDocument {
            activeDocument.textView.scrollRangeToVisible(activeDocument.textView.selectedRange())
        }

        for (documentID, url) in documentsToLoad {
            loadContents(documentID: documentID, from: url)
        }
        return true
    }

    private func makeSessionState() -> AppSessionState? {
        guard !documents.isEmpty else { return nil }
        let tabs = documents.map { document in
            let selection = document.textView.selectedRange()
            return SessionTabState(
                urlPath: document.url?.standardizedFileURL.path,
                text: document.isLoading || (document.url != nil && !document.isDirty)
                    ? nil
                    : document.textView.string,
                customTitle: document.customTitle,
                encodingRawValue: document.encoding.rawValue,
                lineEnding: document.lineEnding,
                isDirty: document.isDirty,
                selectionLocation: selection.location,
                selectionLength: selection.length
            )
        }
        let activeIndex = activeDocumentID.flatMap { activeID in
            documents.firstIndex(where: { $0.id == activeID })
        } ?? 0
        return AppSessionState(
            version: 1,
            tabs: tabs,
            activeTabIndex: activeIndex,
            wordWrapEnabled: wordWrapEnabled,
            editorFontSize: Double(editorFontSize),
            windowFrame: window?.frameDescriptor
        )
    }

    private func scheduleSessionSave() {
        guard !terminationWasApproved else { return }
        sessionSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let state = self.makeSessionState() else { return }
            self.sessionWriteQueue.async {
                do {
                    try SessionStore.save(state)
                } catch {
                    NSLog("Session autosave failed: %@", error.localizedDescription)
                }
            }
        }
        sessionSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    private func persistSessionSynchronously() {
        sessionSaveWorkItem?.cancel()
        guard let state = makeSessionState() else {
            clearSessionSynchronously()
            return
        }
        sessionWriteQueue.sync {
            do {
                try SessionStore.save(state)
            } catch {
                NSLog("Session save failed: %@", error.localizedDescription)
            }
        }
    }

    private func clearSessionSynchronously() {
        sessionSaveWorkItem?.cancel()
        sessionWriteQueue.sync {
            SessionStore.clear()
        }
    }

    func open(urls: [URL]) {
        for url in urls where url.isFileURL {
            open(url: url)
        }
    }

    private func createNewTab(text: String = "", url: URL? = nil, encoding: String.Encoding = .utf8) {
        resetRapidTabClosing()
        let document = DocumentTab(text: text, url: url, encoding: encoding)
        configure(document: document)
        documents.append(document)
        activeDocumentID = document.id
        refreshTabs()
        showActiveDocument()
        scheduleSessionSave()
    }

    private func configure(document: DocumentTab) {
        document.textView.delegate = self
        documentByTextView[ObjectIdentifier(document.textView)] = document
        document.textView.font = NSFont(name: "Menlo", size: editorFontSize)
            ?? .monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
        document.textView.textContainerInset = NSSize(width: 16, height: 16)
        applyDocumentTheme(to: document)
        applyWordWrap(to: document)
    }

    private func unregister(document: DocumentTab) {
        document.textView.delegate = nil
        documentByTextView.removeValue(forKey: ObjectIdentifier(document.textView))
        restoredSelectionByDocumentID.removeValue(forKey: document.id)
    }

    private func open(url: URL) {
        let standardizedURL = url.standardizedFileURL
        if let existing = documents.first(where: { $0.url?.standardizedFileURL == standardizedURL }) {
            selectTab(id: existing.id)
            return
        }

        let document = DocumentTab(url: standardizedURL)
        document.isLoading = true
        document.textView.isEditable = false
        configure(document: document)

        if documents.count == 1,
           let only = documents.first,
           only.url == nil,
           !only.isDirty,
           only.textView.string.isEmpty {
            unregister(document: only)
            documents[0] = document
        } else {
            documents.append(document)
        }

        activeDocumentID = document.id
        refreshTabs()
        showActiveDocument()
        scheduleSessionSave()

        loadContents(documentID: document.id, from: standardizedURL)
    }

    private func loadContents(documentID: UUID, from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<(String, String.Encoding, LineEnding), Error>
            do {
                var detectedEncoding = String.Encoding.utf8
                let contents = try String(contentsOf: url, usedEncoding: &detectedEncoding)
                let lineEnding = contents.isEmpty ? LineEnding.crlf : LineEnding.detect(in: contents)
                result = .success((lineEnding.normalizedForEditing(contents), detectedEncoding, lineEnding))
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { [weak self] in
                self?.finishOpening(documentID: documentID, url: url, result: result)
            }
        }
    }

    private func finishOpening(documentID: UUID,
                               url: URL,
                               result: Result<(String, String.Encoding, LineEnding), Error>) {
        guard let document = documents.first(where: { $0.id == documentID }) else { return }

        switch result {
        case let .success((contents, encoding, lineEnding)):
            document.textView.string = contents
            let requestedSelection = restoredSelectionByDocumentID.removeValue(forKey: document.id)
                ?? NSRange(location: 0, length: 0)
            let textLength = contents.utf16.count
            let location = min(requestedSelection.location, textLength)
            let length = min(requestedSelection.length, textLength - location)
            let restoredSelection = NSRange(location: location, length: length)
            document.textView.setSelectedRange(restoredSelection)
            document.textView.scrollRangeToVisible(restoredSelection)
            document.encoding = encoding
            document.lineEnding = lineEnding
            document.isLoading = false
            document.isDirty = false
            document.textView.isEditable = true
            document.textView.undoManager?.removeAllActions()
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            updateTabAppearance(for: document)
            if document.id == activeDocumentID {
                updateWindowTitle()
                updateStatusBar()
                focusEditor()
            }
            scheduleSessionSave()
        case let .failure(error):
            restoredSelectionByDocumentID.removeValue(forKey: document.id)
            document.isLoading = false
            remove(document: document)
            presentError(
                title: "파일을 열 수 없습니다",
                message: "\(url.lastPathComponent)\n\n\(error.localizedDescription)"
            )
        }
    }

    private func showActiveDocument() {
        editorHost.subviews.forEach { $0.removeFromSuperview() }
        guard let document = activeDocument else {
            updateWindowTitle()
            updateStatusBar()
            return
        }

        let view = document.containerView
        view.frame = editorHost.bounds
        view.autoresizingMask = [.width, .height]
        editorHost.addSubview(view)
        updateWindowTitle()
        updateStatusBar()
        focusEditor()
    }

    private func focusEditor() {
        guard let textView = activeDocument?.textView else { return }
        DispatchQueue.main.async { [weak self, weak textView] in
            guard let self, let textView,
                  textView === self.activeDocument?.textView,
                  !self.tabButtonsByID.values.contains(where: { $0.isRenaming }) else { return }
            self.window?.makeFirstResponder(textView)
        }
    }

    private func tabLayout(proposedWindowWidth: CGFloat? = nil) -> TabStripLayout {
        TabStripLayout(windowWidth: proposedWindowWidth ?? window?.contentView?.bounds.width ?? 920,
                       count: documents.count, heldTabWidth: rapidCloseTabWidth,
                       heldViewportWidth: rapidCloseStripWidth)
    }

    private func refreshTabs() {
        let wantedIDs = Set(documents.map(\.id))
        for id in Array(tabButtonsByID.keys) where !wantedIDs.contains(id) {
            tabButtonsByID[id]?.finishRenaming(commit: true)
            tabButtonsByID.removeValue(forKey: id)?.removeFromSuperview()
        }
        for document in documents {
            if tabButtonsByID[document.id] == nil {
                let tab = TabButtonView(tabID: document.id, delegate: self)
                tabDocumentView.addSubview(tab)
                tabButtonsByID[document.id] = tab
            }
            updateTabAppearance(for: document)
        }
        if draggingTabID == nil,
           tabDocumentView.subviews.compactMap({ ($0 as? TabButtonView)?.tabID }) != documents.map(\.id) {
            tabDocumentView.subviews = documents.compactMap { tabButtonsByID[$0.id] }
        }
        updateTabDocumentSize()
        if draggingTabID == nil { revealActiveTab() }
        updateWindowTitle()
    }

    private func updateTabAppearance(for document: DocumentTab) {
        tabButtonsByID[document.id]?.update(title: document.tabTitle,
                                           selected: document.id == activeDocumentID,
                                           toolTip: document.url?.path)
    }

    private func updateTabDocumentSize() {
        let layout = tabLayout()
        tabScrollWidthConstraint?.constant = layout.viewportWidth
        tabOverflowButton.isHidden = !layout.showsOverflow
        tabOverflowWidthConstraint?.constant = layout.showsOverflow ? 32 : 0
        tabOverflowButton.setAccessibilityLabel(layout.showsOverflow ? "모든 탭, 총 \(documents.count)개" : "모든 탭")
        tabBar.layoutSubtreeIfNeeded()
        tabDocumentView.frame = NSRect(x: 0, y: 0, width: layout.contentWidth,
                                      height: max(tabScrollView.contentSize.height, 38))
        for (index, document) in documents.enumerated() {
            tabButtonsByID[document.id]?.frame = layout.frame(at: index)
        }
        let clip = tabScrollView.contentView
        clip.scroll(to: NSPoint(x: min(clip.bounds.minX, max(0, layout.contentWidth - clip.bounds.width)), y: 0))
        tabScrollView.reflectScrolledClipView(clip)
    }

    private func revealActiveTab() {
        guard let id = activeDocumentID, let tab = tabButtonsByID[id] else { return }
        let clip = tabScrollView.contentView
        let visible = clip.bounds
        var x = visible.minX
        if tab.frame.minX < visible.minX { x = tab.frame.minX - 5 }
        if tab.frame.maxX > visible.maxX { x = tab.frame.maxX - visible.width + 5 }
        x = min(max(0, x), max(0, tabDocumentView.bounds.width - visible.width))
        clip.scroll(to: NSPoint(x: x, y: 0))
        tabScrollView.reflectScrolledClipView(clip)
    }

    private func updateWindowTitle() {
        guard let document = activeDocument else {
            window?.title = appDisplayName
            window?.representedURL = nil
            window?.isDocumentEdited = false
            return
        }
        window?.title = "\(document.displayTitle) — \(appDisplayName)"
        window?.representedURL = document.url
        window?.isDocumentEdited = document.isDirty
    }

    private func updateStatusBar() {
        guard let document = activeDocument else {
            cursorStatusLabel.stringValue = ""
            documentStatusLabel.stringValue = ""
            return
        }

        if document.isLoading {
            cursorStatusLabel.stringValue = "파일 여는 중…"
            documentStatusLabel.stringValue = ""
            return
        }

        let textView = document.textView
        let nsText = textView.string as NSString
        let location = min(textView.selectedRange().location, nsText.length)
        let (line, column) = lineAndColumn(in: nsText, location: location)
        cursorStatusLabel.stringValue = "Ln \(line), Col \(column)"

        let zoom = Int((editorFontSize / 14) * 100)
        documentStatusLabel.stringValue = "\(zoom)%    │    \(document.lineEnding.displayName)    │    \(encodingName(document.encoding))"
    }

    private func lineAndColumn(in text: NSString, location: Int) -> (line: Int, column: Int) {
        var line = 1
        var lastLineStart = 0
        var offset = 0

        while offset < location {
            let count = min(statusCharacterBuffer.count, location - offset)
            statusCharacterBuffer.withUnsafeMutableBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                text.getCharacters(baseAddress, range: NSRange(location: offset, length: count))
            }
            for index in 0..<count where statusCharacterBuffer[index] == 10 {
                line += 1
                lastLineStart = offset + index + 1
            }
            offset += count
        }

        return (line, location - lastLineStart + 1)
    }

    private func scheduleStatusBarUpdate() {
        statusUpdateGeneration &+= 1
        let generation = statusUpdateGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.statusUpdateGeneration == generation else { return }
            self.updateStatusBar()
        }
    }

    private func encodingName(_ encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16, .unicode: return "UTF-16"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian: return "UTF-16 BE"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO-8859-1"
        case .windowsCP1252: return "Windows-1252"
        default: return "텍스트"
        }
    }

    private func applyWordWrap(to document: DocumentTab) {
        let textView = document.textView
        let scrollView = document.scrollView
        scrollView.hasHorizontalScroller = !wordWrapEnabled
        textView.isHorizontallyResizable = !wordWrapEnabled
        textView.autoresizingMask = wordWrapEnabled ? [.width] : []
        textView.textContainer?.widthTracksTextView = wordWrapEnabled
        textView.textContainer?.containerSize = NSSize(
            width: wordWrapEnabled ? 0 : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        if !wordWrapEnabled {
            textView.frame.size.width = max(scrollView.contentSize.width, textView.intrinsicContentSize.width)
        }
    }

    @discardableResult
    private func save(document: DocumentTab, saveAs: Bool) -> Bool {
        guard !document.isLoading else { return false }
        var destination = document.url
        if saveAs || destination == nil {
            let panel = NSSavePanel()
            panel.title = "메모 저장"
            panel.prompt = "저장"
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = document.url?.lastPathComponent ?? "제목 없음.txt"
            panel.allowedContentTypes = [.plainText]
            guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }
            destination = selectedURL
        }

        guard let destination else { return false }
        do {
            let serializedText = document.lineEnding.serialized(document.textView.string)
            try serializedText.write(to: destination, atomically: true, encoding: .utf8)
            document.url = destination.standardizedFileURL
            document.encoding = .utf8
            document.isDirty = false
            NSDocumentController.shared.noteNewRecentDocumentURL(destination)
            refreshTabs()
            updateStatusBar()
            scheduleSessionSave()
            return true
        } catch {
            presentError(title: "파일을 저장할 수 없습니다", message: error.localizedDescription)
            return false
        }
    }

    private func confirmClose(document: DocumentTab) -> Bool {
        guard document.isDirty else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "‘\(document.displayTitle)’의 변경 내용을 저장할까요?"
        alert.informativeText = "저장하지 않으면 변경 내용이 사라집니다."
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "저장 안 함")
        alert.addButton(withTitle: "취소")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save(document: document, saveAs: false)
        case .alertSecondButtonReturn:
            document.isDirty = false
            return true
        default:
            return false
        }
    }

    private func remove(document: DocumentTab, createReplacement: Bool = true) {
        guard confirmClose(document: document) else { return }
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        unregister(document: document)
        documents.remove(at: index)

        if documents.isEmpty, createReplacement {
            createNewTab()
            return
        }

        if documents.isEmpty {
            activeDocumentID = nil
        } else if activeDocumentID == document.id {
            activeDocumentID = documents[min(index, documents.count - 1)].id
        }
        refreshTabs()
        showActiveDocument()
        scheduleSessionSave()
    }

    private func close(document: DocumentTab) {
        guard documents.count == 1 else {
            remove(document: document, createReplacement: false)
            return
        }
        guard confirmClose(document: document) else { return }
        unregister(document: document)
        documents.removeAll()
        activeDocumentID = nil
        clearSessionSynchronously()
        terminationWasApproved = true
        NSApp.terminate(nil)
    }

    private func beginRapidTabClosing(for id: UUID) {
        guard documents.count > 1, let tab = tabButtonsByID[id] else { return }
        rapidCloseStripWidth = tabScrollView.contentSize.width
        rapidCloseTabWidth = tab.frame.width
    }

    private func resetRapidTabClosing() {
        rapidCloseStripWidth = nil
        rapidCloseTabWidth = nil
    }

    private func finishRapidTabClosing() {
        guard rapidCloseTabWidth != nil else { return }
        resetRapidTabClosing()
        refreshTabs()
    }

    private func installKeyboardShortcuts() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.window?.isKeyWindow == true else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 48 && (modifiers == .control || modifiers == [.control, .shift]) {
                self.selectAdjacentTab(backward: modifiers.contains(.shift))
                return nil
            }
            let isControlCharacter = event.characters == "\u{17}" ||
                event.charactersIgnoringModifiers == "\u{17}"
            let isPhysicalControlW = modifiers == .control && event.keyCode == 13
            guard isPhysicalControlW || isControlCharacter else { return event }
            self.closeTabAction(nil)
            return nil
        }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) {
            [weak self] event in
            guard let self,
                  self.rapidCloseTabWidth != nil,
                  event.window === self.window else { return event }
            let locationInTabBar = self.tabBar.convert(event.locationInWindow, from: nil)
            if !self.tabBar.bounds.contains(locationInTabBar) {
                self.finishRapidTabClosing()
            }
            return event
        }
    }

    func requestApplicationTermination() -> Bool {
        if terminationWasApproved { return true }
        tabButtonsByID.values.forEach { $0.finishRenaming(commit: true) }
        persistSessionSynchronously()
        terminationWasApproved = true
        return true
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    func selectTab(id: UUID) {
        guard documents.contains(where: { $0.id == id }) else { return }
        tabButtonsByID.values.forEach { $0.finishRenaming(commit: true) }
        resetRapidTabClosing()
        activeDocumentID = id
        refreshTabs()
        showActiveDocument()
        scheduleSessionSave()
    }

    func beginRenamingTab(id: UUID) {
        guard activeDocumentID == id else {
            selectTab(id: id)
            return
        }
        selectTab(id: id)
        // Selecting a tab also schedules editor focus. Begin after that work.
        DispatchQueue.main.async { [weak self] in
            guard let self, let document = self.activeDocument, document.id == id else { return }
            self.tabButtonsByID[id]?.beginRenaming(title: document.displayTitle)
        }
    }

    func renameTab(id: UUID, title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              let document = documents.first(where: { $0.id == id }),
              title != document.displayTitle else { return }
        document.customTitle = title
        updateTabAppearance(for: document)
        updateWindowTitle()
        scheduleSessionSave()
    }

    private func selectAdjacentTab(backward: Bool) {
        guard documents.count > 1,
              let index = documents.firstIndex(where: { $0.id == activeDocumentID }) else { return }
        let next = (index + (backward ? documents.count - 1 : 1)) % documents.count
        selectTab(id: documents[next].id)
    }

    @discardableResult
    private func moveTab(id: UUID, to destination: Int) -> Bool {
        guard let source = documents.firstIndex(where: { $0.id == id }) else { return false }
        let destination = min(max(0, destination), documents.count - 1)
        guard source != destination else { return false }
        let document = documents.remove(at: source)
        documents.insert(document, at: destination)
        return true
    }

    func beginDraggingTab(id: UUID, at point: NSPoint) {
        guard let tab = tabButtonsByID[id] else { return }
        dragScrollTimer?.invalidate()
        dragOffsetX = tabDocumentView.convert(point, from: nil).x - tab.frame.minX
        draggingTabID = id
        dragPoint = point
        selectTab(id: id)
        tabDocumentView.addSubview(tab, positioned: .above, relativeTo: nil)
        tab.alphaValue = 0.85
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let id = self.draggingTabID, let point = self.dragPoint else { return }
            self.dragTab(id: id, to: point)
        }
        dragScrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func dragTab(id: UUID, to point: NSPoint) {
        guard draggingTabID == id, let tab = tabButtonsByID[id] else { return }
        dragPoint = point
        let clip = tabScrollView.contentView
        let mouseX = tabScrollView.convert(point, from: nil).x
        var scrollX = clip.bounds.minX
        if mouseX < 24 { scrollX -= 16 }
        if mouseX > clip.bounds.width - 24 { scrollX += 16 }
        scrollX = min(max(0, scrollX), max(0, tabDocumentView.bounds.width - clip.bounds.width))
        clip.scroll(to: NSPoint(x: scrollX, y: 0))
        tabScrollView.reflectScrolledClipView(clip)

        let layout = tabLayout()
        let x = tabDocumentView.convert(point, from: nil).x - dragOffsetX
        let destination = layout.index(at: x + layout.tabWidth / 2, count: documents.count)
        _ = moveTab(id: id, to: destination)
        updateTabDocumentSize()
        tab.frame.origin.x = min(max(0, x), max(0, layout.contentWidth - layout.tabWidth))
    }

    func endDraggingTab(id: UUID) {
        guard draggingTabID == id else { return }
        dragScrollTimer?.invalidate()
        dragScrollTimer = nil
        dragPoint = nil
        draggingTabID = nil
        tabButtonsByID[id]?.alphaValue = 1
        refreshTabs()
        scheduleSessionSave()
    }

    func closeTab(id: UUID) {
        guard let document = documents.first(where: { $0.id == id }) else { return }
        beginRapidTabClosing(for: id)
        close(document: document)
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              let document = documentByTextView[ObjectIdentifier(textView)],
              !document.isLoading else { return }
        let titleChanged = document.updateDraftTitle(from: textView.string)
        var dirtyStateChanged = false
        if !document.isDirty {
            document.isDirty = true
            dirtyStateChanged = true
        }
        if titleChanged || dirtyStateChanged {
            updateTabAppearance(for: document)
            if document.id == activeDocumentID {
                updateWindowTitle()
            }
        }
        if document.id == activeDocumentID {
            scheduleStatusBarUpdate()
        }
        scheduleSessionSave()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              textView === activeDocument?.textView else { return }
        scheduleStatusBarUpdate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        tabButtonsByID.values.forEach { $0.finishRenaming(commit: true) }
        persistSessionSynchronously()
        terminationWasApproved = true
        return true
    }

    @objc func windowDidResize(_ notification: Notification) {
        resetRapidTabClosing()
        updateResponsiveLayout()
        refreshTabs()
        scheduleSessionSave()
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        resetRapidTabClosing()
        updateResponsiveLayout(for: frameSize.width)
        let layout = tabLayout(proposedWindowWidth: frameSize.width)
        tabScrollWidthConstraint?.constant = layout.viewportWidth
        tabOverflowButton.isHidden = !layout.showsOverflow
        tabOverflowWidthConstraint?.constant = layout.showsOverflow ? 32 : 0
        return frameSize
    }

    private func updateResponsiveLayout(for proposedWidth: CGFloat? = nil) {
        let contentWidth = proposedWidth ?? window?.contentView?.bounds.width ?? 920
        let useCompactToolbar = contentWidth < 700
        formattingLeadingConstraint?.isActive = !useCompactToolbar
        formattingTrailingConstraint?.isActive = !useCompactToolbar
        formattingStack.isHidden = useCompactToolbar
    }

    @objc private func minimizeWindowAction(_ sender: Any?) {
        window?.miniaturize(sender)
    }

    @objc private func maximizeWindowAction(_ sender: Any?) {
        window?.zoom(sender)
    }

    @objc private func closeWindowAction(_ sender: Any?) {
        window?.performClose(sender)
    }

    private func surroundSelection(prefix: String, suffix: String, placeholder: String) {
        guard let textView = activeDocument?.textView else { return }
        let selection = textView.selectedRange()
        let currentText = textView.string as NSString
        let selectedText = selection.length > 0 ? currentText.substring(with: selection) : placeholder
        let replacement = prefix + selectedText + suffix
        textView.insertText(replacement, replacementRange: selection)
        let selectedRange = NSRange(
            location: selection.location + (prefix as NSString).length,
            length: (selectedText as NSString).length
        )
        textView.setSelectedRange(selectedRange)
        focusEditor()
    }

    private func prefixSelectedLines(_ prefix: String) {
        guard let textView = activeDocument?.textView else { return }
        let nsText = textView.string as NSString
        let selection = textView.selectedRange()
        let lineRange = nsText.lineRange(for: selection)
        let block = nsText.substring(with: lineRange)
        let lines = block.components(separatedBy: "\n")
        let replacement = lines.enumerated().map { index, line in
            if index == lines.count - 1 && line.isEmpty { return "" }
            return line.hasPrefix(prefix) ? line : prefix + line
        }.joined(separator: "\n")
        textView.insertText(replacement, replacementRange: lineRange)
        textView.setSelectedRange(NSRange(location: lineRange.location, length: (replacement as NSString).length))
        focusEditor()
    }

    @objc private func insertHeadingAction(_ sender: Any?) {
        prefixSelectedLines("# ")
    }

    @objc private func insertListAction(_ sender: Any?) {
        prefixSelectedLines("- ")
    }

    @objc private func insertBoldAction(_ sender: Any?) {
        surroundSelection(prefix: "**", suffix: "**", placeholder: "굵은 텍스트")
    }

    @objc private func insertItalicAction(_ sender: Any?) {
        surroundSelection(prefix: "_", suffix: "_", placeholder: "기울임 텍스트")
    }

    @objc private func insertStrikethroughAction(_ sender: Any?) {
        surroundSelection(prefix: "~~", suffix: "~~", placeholder: "취소선 텍스트")
    }

    @objc private func insertLinkAction(_ sender: Any?) {
        surroundSelection(prefix: "[", suffix: "](https://)", placeholder: "링크 텍스트")
    }

    @objc private func insertImageAction(_ sender: Any?) {
        guard let textView = activeDocument?.textView else { return }
        textView.insertText("![이미지 설명](image-url)", replacementRange: textView.selectedRange())
        focusEditor()
    }

    @objc private func insertTableAction(_ sender: Any?) {
        guard let textView = activeDocument?.textView else { return }
        let table = "| 열 1 | 열 2 |\n| --- | --- |\n| 내용 | 내용 |"
        textView.insertText(table, replacementRange: textView.selectedRange())
        focusEditor()
    }

    @objc private func newTabAction(_ sender: Any?) {
        createNewTab()
    }

    @objc private func openAction(_ sender: Any?) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "텍스트 파일 열기"
        panel.prompt = "열기"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text, .sourceCode, .data]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.open(urls: panel.urls)
        }
    }

    @objc private func saveAction(_ sender: Any?) {
        guard let document = activeDocument else { return }
        _ = save(document: document, saveAs: false)
    }

    @objc private func saveAsAction(_ sender: Any?) {
        guard let document = activeDocument else { return }
        _ = save(document: document, saveAs: true)
    }

    @objc private func closeTabAction(_ sender: Any?) {
        guard let document = activeDocument else { return }
        resetRapidTabClosing()
        close(document: document)
    }

    @objc private func performCloseWindow(_ sender: Any?) {
        window?.performClose(sender)
    }

    @objc private func setDarkThemeAction(_ sender: Any?) {
        applyTheme(.dark)
    }

    @objc private func setSoftLightThemeAction(_ sender: Any?) {
        applyTheme(.softLight)
    }

    private func applyTheme(_ theme: ThemeMode) {
        ThemeMode.select(theme)
        let appearance = NSAppearance(named: theme.appearanceName)
        NSApp.appearance = appearance
        window?.appearance = appearance
        window?.backgroundColor = WindowsPalette.chrome
        rootView.appearance = appearance
        rootView.layer?.backgroundColor = WindowsPalette.editor.cgColor
        tabBar.layer?.backgroundColor = WindowsPalette.chrome.cgColor
        commandBar.layer?.backgroundColor = WindowsPalette.commandBar.cgColor
        chromeDivider.layer?.backgroundColor = WindowsPalette.border.cgColor
        editorHost.layer?.backgroundColor = WindowsPalette.editor.cgColor
        statusBar.layer?.backgroundColor = WindowsPalette.status.cgColor
        statusDivider.layer?.backgroundColor = WindowsPalette.border.cgColor
        cursorStatusLabel.textColor = WindowsPalette.secondaryText
        documentStatusLabel.textColor = WindowsPalette.secondaryText

        updateHoverButtonTheme(in: rootView)
        windowCloseButton.hoverBackgroundColor = WindowsPalette.closeHover
        windowCloseButton.hoverContentTintColor = .white
        documents.forEach { applyDocumentTheme(to: $0) }
        refreshTabs()
        rootView.needsDisplay = true
    }

    private func updateHoverButtonTheme(in view: NSView) {
        for subview in view.subviews {
            if let button = subview as? HoverButton {
                button.normalBackgroundColor = .clear
                button.hoverBackgroundColor = WindowsPalette.hover
                button.contentTintColor = WindowsPalette.text
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
            updateHoverButtonTheme(in: subview)
        }
    }

    private func applyDocumentTheme(to document: DocumentTab) {
        let appearance = NSAppearance(named: ThemeMode.current.appearanceName)
        document.containerView.appearance = appearance
        document.scrollView.appearance = appearance
        document.scrollView.scrollerKnobStyle = ThemeMode.current == .dark ? .light : .dark
        document.textView.appearance = appearance
        document.textView.backgroundColor = WindowsPalette.editor
        document.textView.textColor = WindowsPalette.text
        document.textView.insertionPointColor = WindowsPalette.text
        document.textView.needsDisplay = true
    }

    @objc private func toggleWordWrapAction(_ sender: NSMenuItem) {
        wordWrapEnabled.toggle()
        sender.state = wordWrapEnabled ? .on : .off
        documents.forEach(applyWordWrap)
        activeDocument?.textView.needsDisplay = true
        scheduleSessionSave()
    }

    @objc private func zoomInAction(_ sender: Any?) {
        editorFontSize = min(32, editorFontSize + 1)
        applyEditorFont()
    }

    @objc private func zoomOutAction(_ sender: Any?) {
        editorFontSize = max(9, editorFontSize - 1)
        applyEditorFont()
    }

    @objc private func resetZoomAction(_ sender: Any?) {
        editorFontSize = 14
        applyEditorFont()
    }

    private func applyEditorFont() {
        let font = NSFont(name: "Menlo", size: editorFontSize)
            ?? .monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
        documents.forEach { $0.textView.font = font }
        updateStatusBar()
        scheduleSessionSave()
    }

    @objc private func goToLineAction(_ sender: Any?) {
        guard let document = activeDocument else { return }
        let alert = NSAlert()
        alert.messageText = "줄로 이동"
        alert.informativeText = "이동할 줄 번호를 입력하세요."
        alert.addButton(withTitle: "이동")
        alert.addButton(withTitle: "취소")
        let input = NSTextField(string: "1")
        input.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = input
        window?.makeFirstResponder(input)
        guard alert.runModal() == .alertFirstButtonReturn,
              let requestedLine = Int(input.stringValue),
              requestedLine > 0 else { return }

        let nsText = document.textView.string as NSString
        var location = 0
        var currentLine = 1
        while currentLine < requestedLine && location < nsText.length {
            let range = nsText.range(of: "\n", options: [], range: NSRange(location: location, length: nsText.length - location))
            if range.location == NSNotFound { location = nsText.length; break }
            location = NSMaxRange(range)
            currentLine += 1
        }
        document.textView.setSelectedRange(NSRange(location: location, length: 0))
        document.textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        focusEditor()
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: appDisplayName,
            .applicationVersion: appDisplayVersion,
            .credits: NSAttributedString(string: "\(appEnglishName) — 빠르고 단순한 macOS용 탭 메모장")
        ])
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(saveAction(_:)) ||
            menuItem.action == #selector(saveAsAction(_:)) ||
            menuItem.action == #selector(goToLineAction(_:)) {
            return activeDocument?.isLoading == false
        }
        if menuItem.action == #selector(closeTabAction(_:)) {
            return activeDocument != nil
        }
        if menuItem.action == #selector(toggleWordWrapAction(_:)) {
            menuItem.state = wordWrapEnabled ? .on : .off
        }
        if menuItem.action == #selector(setDarkThemeAction(_:)) {
            menuItem.state = ThemeMode.current == .dark ? .on : .off
        }
        if menuItem.action == #selector(setSoftLightThemeAction(_:)) {
            menuItem.state = ThemeMode.current == .softLight ? .on : .off
        }
        return true
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: ThemeMode.current.appearanceName)
        NSApp.applicationIconImage = makeApplicationIcon()
        let controller = MainWindowController()
        mainWindowController = controller
        controller.showWindowAndFocus()
        if !pendingURLs.isEmpty {
            controller.open(urls: pendingURLs)
            pendingURLs.removeAll()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let mainWindowController {
            mainWindowController.showWindowAndFocus()
            mainWindowController.open(urls: urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindowController?.showWindowAndFocus()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard mainWindowController?.requestApplicationTermination() ?? true else {
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeApplicationIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 512, height: 512))
        image.lockFocus()

        let outer = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 440, height: 440), xRadius: 96, yRadius: 96)
        NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.96, alpha: 1).setFill()
        outer.fill()

        let page = NSBezierPath(roundedRect: NSRect(x: 112, y: 92, width: 288, height: 330), xRadius: 28, yRadius: 28)
        NSColor.white.setFill()
        page.fill()

        NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.96, alpha: 0.88).setStroke()
        for y in stride(from: 326, through: 174, by: -50) {
            let line = NSBezierPath()
            line.lineWidth = 15
            line.lineCapStyle = .round
            line.move(to: NSPoint(x: 158, y: y))
            line.line(to: NSPoint(x: 354, y: y))
            line.stroke()
        }
        image.unlockFocus()
        return image
    }
}

#if !BEHAVIOR_CHECKS
private let application = NSApplication.shared
private let appDelegate = AppDelegate()
application.setActivationPolicy(.regular)
application.delegate = appDelegate
application.run()
#endif
