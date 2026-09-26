// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

/// Opt-in native integration probe. It targets ONLY our harmless fixture app.
/// Build separately from the unit suite; see docs/menu-bar-shelf.md.
@main
struct MenuBarShelfSmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        UserDefaults.standard.set(0, forKey: "NSStatusItem Preferred Position VorssaintShelfSmoke")
        let anchor = NSStatusBar.system.statusItem(withLength: 26)
        anchor.autosaveName = "VorssaintShelfSmoke"
        anchor.button?.title = "T"
        UserDefaults.standard.set(1, forKey: "NSStatusItem Preferred Position VorssaintShelfSmokeDivider")
        let divider = NSStatusBar.system.statusItem(withLength: 20)
        divider.autosaveName = "VorssaintShelfSmokeDivider"
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
                divider.length = 10_000
                try await Task.sleep(for: .milliseconds(500))
                guard AXIsProcessTrusted() else { throw Failure("Accessibility is required for the native probe") }
                guard let argument = CommandLine.arguments.dropFirst().first,
                      let pid = pid_t(argument),
                      let fixture = NSRunningApplication(processIdentifier: pid),
                      fixture.bundleIdentifier == "com.vorssaint.shelf-fixture"
                else { throw Failure("Pass the PID of the dedicated fixture app") }
                let list = MenuBarShelfScanner.scan(applications: [(fixture.processIdentifier, "Fixture", fixture.bundleURL)], ownPID: getpid())
                guard let item = list.first, let window = anchor.button?.window,
                      let screen = NSScreen.screens.first else { throw Failure("Fixture or anchor unavailable") }
                guard item.frame.maxX < 0 else { throw Failure("Fixture must start physically offscreen: \(item.frame)") }
                print("PASS: fixture begins physically offscreen")
                let rect = window.frame
                let target = CGRect(x: rect.minX, y: screen.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
                let bridge = MenuBarShelfNativeBridge()
                guard await bridge.reveal(item, anchor: target) else {
                    _ = await bridge.restore()
                    throw Failure("Native reveal did not settle beside the anchor")
                }
                print("PASS: hidden fixture moved beside the anchor")
                var actions: CFArray?
                AXUIElementCopyActionNames(item.element, &actions)
                print("Fixture actions: \(actions as Any)")
                // Run AX off the main thread: menu tracking must keep pumping.
                let pressed = await withCheckedContinuation { continuation in
                    DispatchQueue.global().async {
                        continuation.resume(returning: AXUIElementPerformAction(item.element, kAXPressAction as CFString))
                    }
                }
                try await Task.sleep(for: .milliseconds(350))
                let children = MenuBarShelfScanner.attribute(item.element, kAXChildrenAttribute) as? [AXUIElement] ?? []
                let menu = children.first { MenuBarShelfScanner.attribute($0, kAXRoleAttribute) as? String == kAXMenuRole }
                let menuFrame = menu.flatMap(MenuBarShelfScanner.frame)
                let visible = menuFrame.map { $0.width > 0 && $0.minX >= 0 && $0.minY >= 0 && $0.minY < screen.frame.height } ?? false
                print("Native press result: \(pressed.rawValue); visible menu: \(visible); frame: \(String(describing: menuFrame))")
                if let menu {
                    var menuActions: CFArray?
                    AXUIElementCopyActionNames(menu, &menuActions)
                    print("Menu actions: \(menuActions as Any)")
                    print("Cancel result: \(AXUIElementPerformAction(menu, kAXCancelAction as CFString).rawValue)")
                }
                try await Task.sleep(for: .milliseconds(500))
                if let saved = bridge.borrowed {
                    print("Return neighbour: \(saved.successorID)")
                }
                let restored = await bridge.restore()
                guard restored else {
                    if let saved = bridge.borrowed {
                        print("Remaining geometry:", MenuBarShelfNativeBridge.windows().filter { $0.id == saved.windowID || $0.id == saved.successorID })
                    }
                    throw Failure("Fixture did not return to its original neighbour")
                }
                print("PASS: fixture returned to its original neighbour")
                guard visible else { throw Failure("Native fixture menu was not visible") }
                NSStatusBar.system.removeStatusItem(divider)
                NSStatusBar.system.removeStatusItem(anchor)
                print("NATIVE SHELF SMOKE OK")
                exit(0)
            } catch {
                NSStatusBar.system.removeStatusItem(divider)
                NSStatusBar.system.removeStatusItem(anchor)
                fputs("NATIVE SHELF SMOKE FAILED: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
