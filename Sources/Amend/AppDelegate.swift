import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = MainWindowController()
        NSApp.mainMenu = buildMenu(target: windowController)
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func buildMenu(target: MainWindowController) -> NSMenu {
        let main = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        main.addSubmenu("") { m in
            m.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
            m.addItem(.separator())
            m.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
            m.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
                .keyEquivalentModifierMask = [.command, .option]
            m.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
            m.addItem(.separator())
            m.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }

        main.addSubmenu("Edit") { m in
            m.addItem(withTitle: "Undo", action: #selector(MainWindowController.performUndo(_:)), keyEquivalent: "z", target: target)
            m.addItem(withTitle: "Redo", action: #selector(MainWindowController.performRedo(_:)), keyEquivalent: "z", target: target)
                .keyEquivalentModifierMask = [.command, .shift]
            m.addItem(.separator())
            m.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            m.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            m.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            m.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
            m.addItem(.separator())
            let find = m.addItem(withTitle: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
            find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        }

        main.addSubmenu("Changes") { m in
            m.addItem(withTitle: "Accept", action: #selector(MainWindowController.acceptSelected(_:)), keyEquivalent: "\r", target: target)
            m.addItem(withTitle: "Reject", action: #selector(MainWindowController.rejectSelected(_:)), keyEquivalent: "\r", target: target)
                .keyEquivalentModifierMask = [.command, .shift]
            m.addItem(.separator())
            m.addItem(withTitle: "Next Change", action: #selector(MainWindowController.selectNext(_:)), keyEquivalent: "]", target: target)
            m.addItem(withTitle: "Previous Change", action: #selector(MainWindowController.selectPrevious(_:)), keyEquivalent: "[", target: target)
            m.addItem(.separator())
            m.addItem(withTitle: "Accept All", action: #selector(MainWindowController.acceptAll(_:)), keyEquivalent: "", target: target)
            m.addItem(withTitle: "Reject All", action: #selector(MainWindowController.rejectAll(_:)), keyEquivalent: "", target: target)
            m.addItem(.separator())
            m.addItem(withTitle: "Copy Result", action: #selector(MainWindowController.copyResult(_:)), keyEquivalent: "c", target: target)
                .keyEquivalentModifierMask = [.command, .shift]
            m.addItem(withTitle: "Clear All", action: #selector(MainWindowController.clearAll(_:)), keyEquivalent: "", target: target)
        }

        main.addSubmenu("View") { m in
            m.addItem(withTitle: "Show Comparison", action: #selector(MainWindowController.toggleInline(_:)), keyEquivalent: "i", target: target)
                .keyEquivalentModifierMask = [.command, .option]
            m.addItem(withTitle: "Sync Scrolling", action: #selector(MainWindowController.toggleSyncScrolling(_:)), keyEquivalent: "", target: target)
            m.addItem(.separator())
            m.addItem(withTitle: "Bigger", action: #selector(MainWindowController.biggerFont(_:)), keyEquivalent: "+", target: target)
            m.addItem(withTitle: "Smaller", action: #selector(MainWindowController.smallerFont(_:)), keyEquivalent: "-", target: target)
            m.addItem(withTitle: "Actual Size", action: #selector(MainWindowController.resetFont(_:)), keyEquivalent: "0", target: target)
        }

        let window = main.addSubmenu("Window") { m in
            m.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
            m.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        }
        NSApp.windowsMenu = window
        return main
    }
}

private extension NSMenu {
    @discardableResult
    func addSubmenu(_ title: String, _ build: (NSMenu) -> Void) -> NSMenu {
        let sub = NSMenu(title: title)
        build(sub)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = sub
        addItem(item)
        return sub
    }

    @discardableResult
    func addItem(withTitle title: String, action: Selector, keyEquivalent: String, target: AnyObject) -> NSMenuItem {
        let item = addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}
