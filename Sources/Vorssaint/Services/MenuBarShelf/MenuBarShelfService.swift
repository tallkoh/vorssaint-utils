// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Combine
import SwiftUI

/// The divider's native position persists through AppKit's autosaveName.
/// Expanding it pushes items on its left out of the menu bar; the separate
/// shelf button stays on its right. Removing it restores the bar, even on crash.
final class MenuBarShelfService: NSObject, ObservableObject, NSPopoverDelegate, @unchecked Sendable {
    static let shared = MenuBarShelfService()
    @Published private(set) var items: [MenuBarShelfItem] = []
    @Published private(set) var arranging = false
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    private let nativeBridge = MenuBarShelfNativeBridge()
    private var interactionTask: Task<Void, Never>?
    private var returnTask: Task<Void, Never>?
    private var launcherWindowID: CGWindowID?
    private var dividerWindowID: CGWindowID?
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
        // Reserve a reachable slot near the system controls on first use.
        // Without this, the manager's own button can start behind the notch.
        for (name, position) in [("MenuBarShelfLauncher", 0), ("MenuBarShelfDivider", 1)] {
            let key = "NSStatusItem Preferred Position \(name)"
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(position, forKey: key)
            }
        }
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
            if self.arranging { self.showSettings() } else { self.collapse() }
        }
    }

    func stop() {
        generation += 1
        let pendingInteraction = interactionTask
        interactionTask?.cancel()
        interactionTask = nil
        returnTask?.cancel()
        returnTask = nil
        collapseWork?.cancel()
        collapseWork = nil
        popover.close()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        let oldDivider = divider
        let oldLauncher = launcher
        // Keep the original neighbour alive until a borrowed item has returned.
        Task { @MainActor [nativeBridge] in
            await pendingInteraction?.value
            _ = await nativeBridge.restore()
            if let oldDivider { NSStatusBar.system.removeStatusItem(oldDivider) }
            if let oldLauncher { NSStatusBar.system.removeStatusItem(oldLauncher) }
        }
        divider = nil
        launcher = nil
        expandedDividerFrame = nil
        launcherWindowID = nil
        dividerWindowID = nil
        items = []
        arranging = false
        loading = false
    }

    @objc func toggle() {
        guard AppFeature.menuBarShelf.isAvailable, AXIsProcessTrusted(), let button = launcher?.button else { return }
        if popover.isShown { popover.close(); return }
        returnTask?.cancel()
        returnTask = nil
        interactionTask?.cancel()
        interactionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.nativeBridge.restore()
            guard !Task.isCancelled, self.launcher != nil else { return }
            self.refresh()
            self.presentShelf(button: button)
        }
    }

    private func presentShelf(button: NSStatusBarButton) {
        // A shelf and the main panel are mutually exclusive surfaces.
        let show = { [weak self, weak button] in
            guard let self, let button, self.launcher != nil else { return }
            var rect = button.bounds
            if let current = self.nativeFrame(for: self.launcher, name: "MenuBarShelfLauncher", cache: &self.launcherWindowID),
               let reported = button.window?.frame {
                rect.origin.x += current.midX - reported.midX
            }
            self.popover.contentSize = NSSize(width: MenuBarShelfSupport.stripWidth(itemCount: self.items.count) + 64, height: MenuBarShelfSupport.stripHeight)
            self.popover.show(relativeTo: rect, of: button, preferredEdge: .minY)
            self.popover.contentViewController?.view.window?.makeKey()
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

    private func nativeFrame(for item: NSStatusItem?, name: String, cache: inout CGWindowID?) -> CGRect? {
        let windows = MenuBarShelfNativeBridge.windows()
        if let cached = cache, let window = windows.first(where: { $0.id == cached }) { return window.frame }
        // Titles are available when screen capture was already granted. They
        // are an optional aid; geometry alone works with Accessibility access.
        let named = windows.filter { $0.title == name }
        if named.count == 1 { cache = named[0].id; return named[0].frame }
        guard let frame = item?.button?.window?.frame, let primary = NSScreen.screens.first else { return nil }
        let converted = CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY,
                               width: frame.width, height: frame.height)
        if let native = MenuBarShelfNativeBridge.matching(converted, in: windows) {
            cache = native.id
            return native.frame
        }
        return nil
    }

    private func captureDividerFrame() {
        expandedDividerFrame = nativeFrame(for: divider, name: "MenuBarShelfDivider", cache: &dividerWindowID)
        _ = nativeFrame(for: launcher, name: "MenuBarShelfLauncher", cache: &launcherWindowID)
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
        captureDividerFrame()
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
        let nativeWindows = MenuBarShelfNativeBridge.windows()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        loading = true
        error = nil
        scanQueue.async { [weak self] in
            let result = MenuBarShelfScanner.scan(applications: apps, ownPID: ownPID)
            let hidden = result.filter {
                MenuBarShelfNativeBridge.matching($0.frame, in: nativeWindows) != nil
                    && MenuBarShelfSupport.belongsInShelf(item: $0.frame, divider: boundary, screen: screenRect)
            }
            DispatchQueue.main.async {
                guard let self, self.generation == request, self.launcher != nil else { return }
                self.items = hidden
                self.loading = false
                self.popover.contentSize = NSSize(width: MenuBarShelfSupport.stripWidth(itemCount: hidden.count) + 64,
                                                 height: MenuBarShelfSupport.stripHeight)
            }
        }
    }

    func open(_ item: MenuBarShelfItem) {
        guard AppFeature.menuBarShelf.isAvailable, launcher != nil, AXIsProcessTrusted(),
              let anchor = nativeFrame(for: launcher, name: "MenuBarShelfLauncher", cache: &launcherWindowID) else { return }
        popover.close()
        interactionTask?.cancel()
        interactionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let revealed = await self.nativeBridge.reveal(item, anchor: anchor)
            guard !Task.isCancelled, self.launcher != nil else { return }
            guard revealed else { self.showOpenError(); return }
            // The native item is now physically beside the shelf, so both
            // NSMenu and custom popovers receive a real, visible anchor.
            let baseline = Self.visibleWindows(for: item.pid)
            self.scanQueue.async { [weak self] in
                let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
                // AppKit's menu tracking can outlive the AX messaging timeout.
                // A visible menu is evidence of success even when AX times out.
                let menuOpen = MenuBarShelfScanner.hasOpenMenu(item.element)
                let presentedWindow = !Self.visibleWindows(for: item.pid).subtracting(baseline).isEmpty
                DispatchQueue.main.async {
                    guard let self, self.launcher != nil else { return }
                    if result != .success && !menuOpen && !presentedWindow { self.showOpenError() }
                    self.returnAfterDismissal(item, baseline: baseline)
                }
            }
        }
    }

    private static func visibleWindows(for pid: pid_t) -> Set<CGWindowID> {
        let raw = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(raw.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) != 25 else { return nil }
            return info[kCGWindowNumber as String] as? CGWindowID
        })
    }

    private func returnAfterDismissal(_ item: MenuBarShelfItem, baseline: Set<CGWindowID>) {
        returnTask?.cancel()
        returnTask = Task { @MainActor [weak self] in
            // Let the target finish presenting before deciding that it is closed.
            try? await Task.sleep(for: .seconds(1))
            for _ in 0..<120 {
                guard !Task.isCancelled, let self, self.launcher != nil else { return }
                let menuOpen: Bool = await withCheckedContinuation { continuation in
                    self.scanQueue.async {
                        continuation.resume(returning: MenuBarShelfScanner.hasOpenMenu(item.element))
                    }
                }
                guard !Task.isCancelled else { return }
                if !menuOpen && Self.visibleWindows(for: item.pid).subtracting(baseline).isEmpty {
                    _ = await self.nativeBridge.restore()
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            // A long-lived app window can stay open. The next shelf opening
            // returns the item; never run a permanent polling loop for it.
        }
    }

    @MainActor func restoreBeforeTermination() async {
        returnTask?.cancel()
        interactionTask?.cancel()
        await interactionTask?.value
        _ = await nativeBridge.restore()
    }

    private func showOpenError() {
        error = FeatureStrings.menuBarShelf(L10n.shared.language).failed
        if let button = launcher?.button { presentShelf(button: button) }
    }

    func popoverDidClose(_ notification: Notification) {
        // Nothing is automatically collapsed while the user is arranging.
    }
}
