// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum MenuBarShelfTests {
    static func run(_ suite: TestSuite) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let service = (try? String(contentsOf: root.appendingPathComponent("Sources/Vorssaint/Services/MenuBarShelf/MenuBarShelfService.swift"), encoding: .utf8)) ?? ""
        let view = (try? String(contentsOf: root.appendingPathComponent("Sources/Vorssaint/UI/MenuBarShelfView.swift"), encoding: .utf8)) ?? ""
        let app = (try? String(contentsOf: root.appendingPathComponent("Sources/Vorssaint/App/AppDelegate.swift"), encoding: .utf8)) ?? ""
        suite.expect(view.contains("Button { service.openVorssaint() }") && service.contains("openPanelFromShelf(anchor: button, rect: rect)"),
                     "Vorssaint has a permanent direct action independent of hidden AX items")
        let recovery = app.components(separatedBy: "func reshowStatusItem() {").last?.components(separatedBy: "private var isReshowingStatusItem").first ?? ""
        suite.expect((recovery.range(of: "MenuBarShelfService.shared.setArranging(true)")?.lowerBound ?? recovery.endIndex) < (recovery.range(of: "statusController?.recreateStatusItem()")?.lowerBound ?? recovery.startIndex),
                     "icon recovery expands our divider before rebuilding the app icon")

        suite.expect(MenuBarShelfSupport.stripHeight == 48, "tray stays one compact menu-bar-height row")
        suite.expect(MenuBarShelfSupport.stripWidth(itemCount: 1) == 32, "one icon never leaves an empty card grid")
        suite.expect(MenuBarShelfSupport.stripWidth(itemCount: 40) == 356, "overflow scrolls horizontally instead of growing the panel")
        let windowFrame = CGRect(x: 1200, y: 0, width: 38, height: 33)
        let window = MenuBarShelfNativeBridge.Window(id: 42, frame: windowFrame)
        suite.expect(MenuBarShelfNativeBridge.matching(CGRect(x: 1199, y: 4.5, width: 40, height: 24), in: [window])?.id == 42,
                     "Tahoe AX inset maps to the original hosted native window")
        suite.expect(MenuBarShelfNativeBridge.matching(windowFrame, in: [window, window]) == nil,
                     "ambiguous windows cannot receive a synthetic event")
        suite.expect(MenuBarShelfNativeBridge.matching(CGRect(x: 1100, y: 0, width: 38, height: 33), in: [window]) == nil,
                     "stale geometry cannot select a neighbouring item")
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let divider = CGRect(x: 1100, y: 0, width: 20, height: 33)
        let cases: [(String, CGRect, Bool)] = [
            ("left of divider is shelved", CGRect(x: 1060, y: 4, width: 38, height: 24), true),
            ("right of divider stays pinned", CGRect(x: 1140, y: 4, width: 38, height: 24), false),
            ("negative overflow stays accessible", CGRect(x: -9000, y: 4, width: 38, height: 24), true),
            ("Tahoe bottom sentinel stays accessible", CGRect(x: -1, y: 981, width: 38, height: 24), true),
            ("zero-sized hosted placeholders are excluded", CGRect(x: 0, y: 982, width: 0, height: 0), false),
            ("ordinary window is excluded", CGRect(x: 900, y: 200, width: 38, height: 24), false),
        ]
        for (name, frame, expected) in cases {
            suite.expect(MenuBarShelfSupport.belongsInShelf(item: frame, divider: divider, screen: screen) == expected, name)
        }
        let offsetScreen = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
        let offsetDivider = CGRect(x: -400, y: -1080, width: 20, height: 24)
        suite.expect(MenuBarShelfSupport.belongsInShelf(item: CGRect(x: -450, y: -1080, width: 24, height: 24), divider: offsetDivider, screen: offsetScreen), "offset display uses global coordinates")
        suite.expect(MenuBarShelfSupport.collapsedLength(screenWidths: [1512, 6016, 6016]) > 13544, "wide desktop cannot exhaust the divider")
        suite.expect(MenuBarShelfSupport.collapsedLength(screenWidths: []) == 10000, "missing display list has a finite fallback")
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.menuBarShelfEnabled), "enabled preference is portable")
        suite.expect(!SettingsBackupSupport.exportKeys().contains(DefaultsKey.menuBarShelfConfigured), "placement setup never follows a backup to another Mac")
        suite.expect(AppFeature.menuBarShelf.permissions == [.accessibility], "only Accessibility is required")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.menuBarShelf(language)
            suite.expect(!strings.title.isEmpty && !strings.instructions.isEmpty && !strings.failed.isEmpty,
                         "shelf copy is present for \(language.rawValue)")
        }
    }
}
