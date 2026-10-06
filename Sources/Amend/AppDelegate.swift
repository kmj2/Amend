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
            m.addItem(withTitle: "\(appName) 정보", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
            m.addItem(.separator())
            m.addItem(withTitle: "\(appName) 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
            m.addItem(withTitle: "기타 가리기", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
                .keyEquivalentModifierMask = [.command, .option]
            m.addItem(withTitle: "모두 보기", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
            m.addItem(.separator())
            m.addItem(withTitle: "\(appName) 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }

        main.addSubmenu("편집") { m in
            m.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
            m.addItem(withTitle: "실행 복귀", action: Selector(("redo:")), keyEquivalent: "z")
                .keyEquivalentModifierMask = [.command, .shift]
            m.addItem(.separator())
            m.addItem(withTitle: "오려두기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            m.addItem(withTitle: "복사하기", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            m.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            m.addItem(withTitle: "모두 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
            m.addItem(.separator())
            let find = m.addItem(withTitle: "찾기…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
            find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        }

        main.addSubmenu("변경") { m in
            m.addItem(withTitle: "수락", action: #selector(MainWindowController.acceptSelected(_:)), keyEquivalent: "\r", target: target)
            m.addItem(withTitle: "거절", action: #selector(MainWindowController.declineSelected(_:)), keyEquivalent: "\r", target: target)
                .keyEquivalentModifierMask = [.command, .shift]
            m.addItem(.separator())
            m.addItem(withTitle: "다음 변경", action: #selector(MainWindowController.selectNext(_:)), keyEquivalent: "]", target: target)
            m.addItem(withTitle: "이전 변경", action: #selector(MainWindowController.selectPrevious(_:)), keyEquivalent: "[", target: target)
            m.addItem(.separator())
            m.addItem(withTitle: "모두 수락", action: #selector(MainWindowController.acceptAll(_:)), keyEquivalent: "", target: target)
            m.addItem(withTitle: "모두 거절", action: #selector(MainWindowController.declineAll(_:)), keyEquivalent: "", target: target)
            m.addItem(.separator())
            m.addItem(withTitle: "결과 복사", action: #selector(MainWindowController.copyResult(_:)), keyEquivalent: "c", target: target)
                .keyEquivalentModifierMask = [.command, .shift]
            m.addItem(withTitle: "모두 지우기", action: #selector(MainWindowController.clearAll(_:)), keyEquivalent: "", target: target)
        }

        main.addSubmenu("보기") { m in
            m.addItem(withTitle: "인라인 비교 보기", action: #selector(MainWindowController.toggleInline(_:)), keyEquivalent: "i", target: target)
                .keyEquivalentModifierMask = [.command, .option]
            m.addItem(.separator())
            m.addItem(withTitle: "글자 크게", action: #selector(MainWindowController.biggerFont(_:)), keyEquivalent: "+", target: target)
            m.addItem(withTitle: "글자 작게", action: #selector(MainWindowController.smallerFont(_:)), keyEquivalent: "-", target: target)
            m.addItem(withTitle: "기본 크기", action: #selector(MainWindowController.resetFont(_:)), keyEquivalent: "0", target: target)
        }

        let window = main.addSubmenu("윈도우") { m in
            m.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
            m.addItem(withTitle: "확대/축소", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
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
