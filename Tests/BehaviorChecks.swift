
private let checkApp = NSApplication.shared
checkApp.setActivationPolicy(.prohibited)
private var checkCount = 0
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checkCount += 1
}

private let checkWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                                   styleMask: [.titled], backing: .buffered, defer: false)
private let checkDocument = DocumentTab(text: "first line\nsecond line\nlast line")
checkWindow.contentView = checkDocument.containerView
checkDocument.containerView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
checkDocument.scrollView.frame = checkDocument.containerView.bounds
private let editor = checkDocument.textView
checkWindow.makeFirstResponder(editor)

private func pressBoundary(home: Bool, modifiers: NSEvent.ModifierFlags = []) {
    let character = String(UnicodeScalar(home ? NSHomeFunctionKey : NSEndFunctionKey)!)
    let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                                modifierFlags: modifiers.union(.function), timestamp: 0,
                                windowNumber: checkWindow.windowNumber, context: nil,
                                characters: character, charactersIgnoringModifiers: character,
                                isARepeat: false, keyCode: home ? 115 : 119)!
    editor.keyDown(with: event)
}

private func expectSelection(_ range: NSRange, _ message: String) {
    check(editor.selectedRange() == range, "\(message): got \(editor.selectedRange()), expected \(range)")
}

editor.setSelectedRange(NSRange(location: 16, length: 0))
pressBoundary(home: true)
expectSelection(NSRange(location: 11, length: 0), "Home goes to current line start")
pressBoundary(home: false)
expectSelection(NSRange(location: 22, length: 0), "End goes to current line end")
pressBoundary(home: true, modifiers: .control)
expectSelection(NSRange(location: 0, length: 0), "Ctrl+Home goes to document start")
pressBoundary(home: false, modifiers: .control)
expectSelection(NSRange(location: 32, length: 0), "Ctrl+End goes to document end")

editor.setSelectedRange(NSRange(location: 16, length: 0))
pressBoundary(home: true, modifiers: .shift)
expectSelection(NSRange(location: 11, length: 5), "Shift+Home selects to line start")
pressBoundary(home: false, modifiers: .shift)
expectSelection(NSRange(location: 16, length: 6), "Shift+End retains original anchor")
editor.setSelectedRange(NSRange(location: 16, length: 0))
pressBoundary(home: true, modifiers: [.control, .shift])
expectSelection(NSRange(location: 0, length: 16), "Ctrl+Shift+Home selects to document start")
editor.setSelectedRange(NSRange(location: 16, length: 0))
pressBoundary(home: false, modifiers: [.control, .shift])
expectSelection(NSRange(location: 16, length: 16), "Ctrl+Shift+End selects to document end")

editor.string = ""
editor.setSelectedRange(NSRange(location: 0, length: 0))
for home in [true, false] {
    pressBoundary(home: home)
    pressBoundary(home: home, modifiers: .control)
    expectSelection(NSRange(location: 0, length: 0), "Empty document boundaries are safe")
}
editor.string = "한글 😀 테스트\n끝\n"
editor.setSelectedRange(NSRange(location: 5, length: 0))
pressBoundary(home: true)
expectSelection(NSRange(location: 0, length: 0), "Unicode line start")
pressBoundary(home: false)
expectSelection(NSRange(location: ("한글 😀 테스트" as NSString).length, length: 0), "Unicode line end")
pressBoundary(home: false, modifiers: .control)
expectSelection(NSRange(location: (editor.string as NSString).length, length: 0), "Trailing empty line")

editor.string = String(repeating: "word ", count: 100)
editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
editor.layoutManager!.ensureLayout(for: editor.textContainer!)
editor.setSelectedRange(NSRange(location: 75, length: 0))
pressBoundary(home: true)
private let wrappedStart = editor.selectedRange().location
check(wrappedStart > 0 && wrappedStart < 75, "Home uses the displayed wrapped line")
editor.setSelectedRange(NSRange(location: 75, length: 0))
pressBoundary(home: false)
private let wrappedEnd = editor.selectedRange().location
check(wrappedEnd >= 75 && wrappedEnd < editor.string.utf16.count, "End uses the displayed wrapped line")

private let legacyJSON = #"{"urlPath":null,"text":"draft","encodingRawValue":4,"lineEnding":"crlf","isDirty":true,"selectionLocation":0,"selectionLength":0}"#.data(using: .utf8)!
private let legacyTab = try JSONDecoder().decode(SessionTabState.self, from: legacyJSON)
check(legacyTab.customTitle == nil, "Existing sessions still decode")
private let renamedState = SessionTabState(urlPath: "/tmp/original.txt", text: nil, customTitle: "새 이름",
                                           encodingRawValue: 4, lineEnding: .crlf, isDirty: false,
                                           selectionLocation: 0, selectionLength: 0)
private let restoredTab = try JSONDecoder().decode(SessionTabState.self, from: JSONEncoder().encode(renamedState))
check(restoredTab.customTitle == "새 이름", "Custom title survives session round trip")
checkDocument.url = URL(fileURLWithPath: "/tmp/original.txt")
checkDocument.customTitle = restoredTab.customTitle
check(checkDocument.displayTitle == "새 이름", "Custom name overrides automatic title")
check(checkDocument.url?.lastPathComponent == "original.txt", "Renaming keeps the file path")
check(!checkDocument.isDirty, "Tab naming doesn't dirty document contents")

private final class RenameDelegateCheck: TabButtonDelegate {
    var committed: String?
    func selectTab(id: UUID) {}
    func closeTab(id: UUID) {}
    func beginRenamingTab(id: UUID) {}
    func renameTab(id: UUID, title: String) { committed = title }
    func beginDraggingTab(id: UUID, at point: NSPoint) {}
    func dragTab(id: UUID, to point: NSPoint) {}
    func endDraggingTab(id: UUID) {}
}
private let renameDelegate = RenameDelegateCheck()
private let tabView = TabButtonView(tabID: UUID(), delegate: renameDelegate)
checkWindow.contentView = tabView
tabView.frame = NSRect(x: 0, y: 0, width: 240, height: 36)
tabView.beginRenaming(title: "Old name")
private let field = tabView.subviews.compactMap { $0 as? NSTextField }.first!
check(field.currentEditor()?.selectedRange == NSRange(location: 0, length: 8), "Rename selects the whole name")
field.currentEditor()?.string = "New name"
tabView.finishRenaming(commit: true)
check(renameDelegate.committed == "New name" && !tabView.isRenaming, "Rename commits edited text: committed=\(String(describing: renameDelegate.committed)), editing=\(tabView.isRenaming)")
tabView.beginRenaming(title: "New name")
field.currentEditor()?.string = "Cancelled name"
tabView.finishRenaming(commit: false)
check(renameDelegate.committed == "New name", "Escape keeps the previous name")



// Layout calculations cover both sparse and very crowded tab strips.
for width: CGFloat in [340, 480, 920, 1440] {
    for count in [1, 2, 6, 40, 200] {
        let layout = TabStripLayout(windowWidth: width, count: count)
        check(layout.viewportWidth + 232 + (layout.showsOverflow ? 32 : 0) <= width,
              "Tab controls fit a \(width)-point window with \(count) tabs")
        check(layout.tabWidth >= 80 && layout.tabWidth <= 240, "Tab widths stay usable")
        check(layout.contentWidth >= layout.viewportWidth, "Scrollable content covers its viewport")
        check(layout.frame(at: count - 1).maxX <= layout.contentWidth, "Last tab stays in scrollable content")
    }
}

private extension MainWindowController {
    func checkCrowdedTabs() throws {
        for index in 1...39 {
            createNewTab()
            activeDocument?.customTitle = "Check \(index)"
        }
        refreshTabs()
        let ids = documents.map(\.id)
        check(ids.count == 40, "Forty tabs are open")
        check(tabButtonsByID.count == 40, "Every tab remains in the strip")
        window!.contentView!.layoutSubtreeIfNeeded()
        window!.setContentSize(NSSize(width: 340, height: 300))
        windowDidResize(Notification(name: NSWindow.didResizeNotification))
        check(abs(window!.contentView!.bounds.width - 340) < 1, "Crowded window shrinks to 340 points")
        check(tabScrollView.frame.maxX < minimizeButton.frame.minX, "Tab viewport doesn't overlap window controls")
        check(tabScrollView.contentView.bounds.maxX >= tabButtonsByID[ids.last!]!.frame.maxX,
              "New active tab scrolls into view")
        let activeID = activeDocumentID
        beginRenamingTab(id: ids[0])
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        check(activeDocumentID == ids[0], "First click switches to an inactive tab")
        check(tabButtonsByID[ids[0]]?.isRenaming == false, "First click does not start renaming")
        beginRenamingTab(id: ids[0])
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        check(tabButtonsByID[ids[0]]?.isRenaming == true, "Second click on the selected tab starts renaming")
        tabButtonsByID[ids[0]]?.finishRenaming(commit: false)
        selectTab(id: activeID!)
        let originalEditor = documents[0].textView
        check(moveTab(id: ids[0], to: 39), "First tab can move to the end")
        refreshTabs()
        check(documents.last?.id == ids[0] && documents.last?.textView === originalEditor,
              "Reorder retains the same document and editor")
        check(activeDocumentID == activeID, "Reorder doesn't change active document")
        check(moveTab(id: ids[0], to: 0), "Tab can move back to the beginning")
        check(documents.map(\.id) == ids, "Both drag directions preserve order")
        remove(document: documents[0], createReplacement: false)
        check(activeDocumentID == activeID, "Closing a background tab preserves active tab")
        selectAdjacentTab(backward: false)
        check(activeDocumentID == documents.first?.id, "Next tab wraps around")
        selectAdjacentTab(backward: true)
        check(activeDocumentID == documents.last?.id, "Previous tab wraps around")
        _ = moveTab(id: documents[0].id, to: documents.count - 1)
        let titles = documents.map(\.displayTitle)
        persistSessionSynchronously()
        let restored = MainWindowController()
        check(restored.documents.map(\.displayTitle) == titles, "Reordered tab names persist on restart")
        // Cancel delayed saves before the temporary session directory is removed.
        sessionSaveWorkItem?.cancel()
        restored.sessionSaveWorkItem?.cancel()
    }
}
private let crowdedController = MainWindowController()
try crowdedController.checkCrowdedTabs()
print("Passed \(checkCount) behavior checks")
