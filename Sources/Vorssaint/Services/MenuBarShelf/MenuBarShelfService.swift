// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Combine
import SwiftUI

/// The divider's native position persists through AppKit's autosaveName.
/// Expanding it pushes items on its left out of the menu bar; the separate
/// shelf button stays on its right. Removing it restores the bar, even on crash.
final class MenuBarShelfService: NSObject, ObservableObject, NSPopoverDelegate {
    static let shared = MenuBarShelfService()
    @Published private(set) var items: [MenuBarShelfItem] = []
    @Published private(set) var arranging = false
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    private var divider: NSStatusItem?
    private var launcher: NSStatusItem?
    private let popover = NSPopover()
    private let scanQueue = DispatchQueue(label: "com.vorssaint.menu-bar-shelf", qos: .userInitiated)
    private var generation = 0
    private var observers: [NSObjectProtocol] = []
    private var defaultsSubscription: AnyCancellable?
    private var expandedDividerFrame: CGRect?
    private var collapseWork: DispatchWorkItem?

    private override init() {
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        defaultsSubscription = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        guard AppFeature.menuBarShelf.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.menuBarShelfEnabled),
              AXIsProcessTrusted() else { stop(); return }
        guard launcher == nil else { return }
        // Create launcher first; subsequent items appear to its left by default.
        let buttonItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buttonItem.autosaveName = "MenuBarShelfLauncher"
        buttonItem.button?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: FeatureStrings.menuBarShelf(L10n.shared.language).title)
        buttonItem.button?.toolTip = FeatureStrings.menuBarShelf(L10n.shared.language).title
        buttonItem.button?.target = self
        buttonItem.button?.action = #selector(toggle)
        launcher = buttonItem
        let separator = NSStatusBar.system.statusItem(withLength: 20)
        separator.autosaveName = "MenuBarShelfDivider"
        separator.button?.title = "│"
        separator.button?.toolTip = FeatureStrings.menuBarShelf(L10n.shared.language).instructions
        separator.button?.target = self
        separator.button?.action = #selector(toggle)
        divider = separator
        popover.contentViewController = NSHostingController(rootView: MenuBarShelfView(service: self))
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                            object: nil, queue: .main) { [weak self] _ in self?.displayChanged() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                            object: nil, queue: .main) { [weak self] _ in self?.displayChanged() })
        // First launch stays expanded so the user can put the boundary where
        // they want it. Never hide everything before showing the setup path.
        arranging = !UserDefaults.standard.bool(forKey: DefaultsKey.menuBarShelfConfigured)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.launcher != nil else { return }
            self.captureDividerFrame()
            if !self.arranging { self.collapse() }
        }
    }

    func stop() {
        generation += 1
        collapseWork?.cancel()
        collapseWork = nil
        popover.close()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        if let divider { NSStatusBar.system.removeStatusItem(divider) }
        if let launcher { NSStatusBar.system.removeStatusItem(launcher) }
        divider = nil
        launcher = nil
        expandedDividerFrame = nil
        items = []
        arranging = false
        loading = false
    }

    @objc func toggle() {
        guard AppFeature.menuBarShelf.isAvailable, AXIsProcessTrusted(), let button = launcher?.button else { return }
        if popover.isShown { popover.close(); return }
        refresh()
        // A shelf and the main panel are mutually exclusive surfaces.
        let show = { [weak self, weak button] in
            guard let self, let button, self.launcher != nil else { return }
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.closePopover(animated: false, completion: show)
        } else { show() }
    }

    func dismiss() { popover.close() }

    func showSettings() {
        popover.close()
        SettingsRouter.shared.request(FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration))
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    func setArranging(_ enabled: Bool) {
        guard divider != nil else { return }
        collapseWork?.cancel()
        arranging = enabled
        error = nil
        if enabled {
            divider?.length = 20
            popover.close()
        } else {
            captureDividerFrame()
            UserDefaults.standard.set(true, forKey: DefaultsKey.menuBarShelfConfigured)
            collapse()
            refresh()
        }
    }

    private func captureDividerFrame() {
        guard let window = divider?.button?.window,
              let primary = NSScreen.screens.first else { return }
        let f = window.frame
        expandedDividerFrame = CGRect(x: f.minX, y: primary.frame.maxY - f.maxY,
                                      width: f.width, height: f.height)
    }

    private func collapse() {
        guard !arranging, let divider else { return }
        divider.length = MenuBarShelfSupport.collapsedLength(screenWidths: NSScreen.screens.map { $0.frame.width })
    }

    private func displayChanged() {
        guard let divider else { return }
        popover.close()
        generation += 1
        items = []
        divider.length = 20
        let work = DispatchWorkItem { [weak self] in
            self?.captureDividerFrame()
            self?.collapse()
        }
        collapseWork?.cancel()
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func refresh() {
        guard AppFeature.menuBarShelf.isAvailable, launcher != nil, AXIsProcessTrusted() else { stop(); return }
        if arranging { captureDividerFrame() }
        guard let boundary = expandedDividerFrame,
              let primary = NSScreen.screens.first,
              let screen = launcher?.button?.window?.screen ?? NSScreen.main else { return }
        let screenRect = CGRect(x: screen.frame.minX, y: primary.frame.maxY - screen.frame.maxY,
                                width: screen.frame.width, height: screen.frame.height)
        let apps = NSWorkspace.shared.runningApplications.map {
            ($0.processIdentifier, $0.localizedName ?? $0.bundleIdentifier ?? "App", $0.bundleURL)
        }
        generation += 1
        let request = generation
        let ownPID = ProcessInfo.processInfo.processIdentifier
        loading = true
        error = nil
        scanQueue.async { [weak self] in
            let result = MenuBarShelfScanner.scan(applications: apps, ownPID: ownPID)
            let hidden = result.filter { MenuBarShelfSupport.belongsInShelf(item: $0.frame, divider: boundary, screen: screenRect) }
            DispatchQueue.main.async {
                guard let self, self.generation == request, self.launcher != nil else { return }
                self.items = hidden
                self.loading = false
            }
        }
    }

    func open(_ item: MenuBarShelfItem) {
        guard AppFeature.menuBarShelf.isAvailable, launcher != nil, AXIsProcessTrusted() else { stop(); return }
        popover.close()
        // AXPress targets the real item; no guessed screen coordinates and no
        // synthetic click sent to whichever app happens to sit underneath it.
        scanQueue.async { [weak self] in
            let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
            DispatchQueue.main.async {
                guard let self, self.launcher != nil else { return }
                if result != .success {
                    self.error = FeatureStrings.menuBarShelf(L10n.shared.language).failed
                    if let button = self.launcher?.button {
                        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    }
                }
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // Nothing is automatically collapsed while the user is arranging.
    }
}
