// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

/// Native status items cannot be reparented into our window. Bring the selected
/// item beside the shelf before opening its own menu, then return it afterwards.
/// The event-routing technique is informed by Ice / Ice 2 (GPL-3.0); see
/// docs/menu-bar-shelf.md. Every operation uses a verified window ID, never a
/// blind click at an old screen coordinate.
@MainActor
final class MenuBarShelfNativeBridge {
    nonisolated init() {}
    struct Window {
        let id: CGWindowID
        let frame: CGRect
        let title: String?
        init(id: CGWindowID, frame: CGRect, title: String? = nil) {
            self.id = id; self.frame = frame; self.title = title
        }
    }
    struct Borrowed {
        let item: MenuBarShelfItem
        let windowID: CGWindowID
        let successorID: CGWindowID
    }
    private(set) var borrowed: Borrowed?
    private var busy = false

    nonisolated static func windows() -> [Window] {
        let raw = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return raw.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.height > 0, frame.height <= 64, frame.width > 0 else { return nil }
            return Window(id: id, frame: frame, title: info[kCGWindowName as String] as? String)
        }
    }

    nonisolated static func matching(_ frame: CGRect, in windows: [Window]) -> Window? {
        let matches = windows.filter {
            abs($0.frame.midX - frame.midX) < 4 && abs($0.frame.midY - frame.midY) < 8
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func isOnScreen(_ frame: CGRect) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        return NSScreen.screens.contains {
            CGRect(x: $0.frame.minX, y: primary.frame.maxY - $0.frame.maxY,
                   width: $0.frame.width, height: $0.frame.height).contains(frame)
        }
    }

    func reveal(_ item: MenuBarShelfItem, anchor: CGRect) async -> Bool {
        guard !busy, AXIsProcessTrusted(), borrowed == nil,
              let frame = MenuBarShelfScanner.frame(item.element) else { return false }
        let windows = Self.windows()
        guard let source = Self.matching(frame, in: windows),
              let target = Self.matching(anchor, in: windows),
              source.id != target.id,
              let successor = windows.filter({
                  $0.id != source.id && $0.frame.minX >= source.frame.maxX - 2
                    && abs($0.frame.midY - source.frame.midY) < 8
              }).min(by: { $0.frame.minX < $1.frame.minX }) else { return false }
        busy = true
        defer { busy = false }
        let saved = Borrowed(item: item, windowID: source.id, successorID: successor.id)
        // Record before moving: even a partial move must be returned.
        borrowed = saved
        return await move(id: source.id, pid: item.pid, beside: target.id, right: true)
    }

    @discardableResult
    func restore(fallbackID: CGWindowID? = nil) async -> Bool {
        guard !busy else { return false }
        guard let saved = borrowed else { return true }
        guard NSRunningApplication(processIdentifier: saved.item.pid) != nil else {
            borrowed = nil
            return true
        }
        busy = true
        defer { busy = false }
        let successor = Self.windows().first { $0.id == saved.successorID }
        let target = successor.map { Self.isOnScreen($0.frame) } == true ? saved.successorID : (fallbackID ?? saved.successorID)
        let restored = await move(id: saved.windowID, pid: saved.item.pid, beside: target, right: false)
        if restored { borrowed = nil }
        return restored
    }

    /// Move permanently for the named arrangement list. Commit only verified geometry.
    func place(_ item: MenuBarShelfItem, anchor: CGRect, right: Bool) async -> Bool {
        guard !busy, borrowed == nil, let frame = MenuBarShelfScanner.frame(item.element),
              let source = Self.matching(frame, in: Self.windows()),
              let target = Self.matching(anchor, in: Self.windows()) else { return false }
        busy = true
        defer { busy = false }
        return await move(id: source.id, pid: item.pid, beside: target.id, right: right)
    }

    /// Standard NSMenu items expose a menu child; custom buttons need a native
    /// click. Choose by capability instead of replaying a second click blindly.
    func activateBorrowed() async -> Bool {
        guard let saved = borrowed else { return false }
        let result: AXError? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let children = MenuBarShelfScanner.attribute(saved.item.element, kAXChildrenAttribute) as? [AXUIElement] ?? []
                guard children.contains(where: { MenuBarShelfScanner.attribute($0, kAXRoleAttribute) as? String == kAXMenuRole }) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: AXUIElementPerformAction(saved.item.element, kAXPressAction as CFString))
            }
        }
        if let result {
            // AppKit menu tracking can outlive AX's messaging timeout.
            if result == .success || result == .cannotComplete { return true }
            guard result == .actionUnsupported || result == .notImplemented || result == .invalidUIElement else { return false }
        }
        return await clickBorrowed()
    }

    /// A verified native click also works for apps with custom status-button actions.
    /// AXPress alone can report success without invoking those actions.
    func clickBorrowed() async -> Bool {
        guard !busy, let saved = borrowed, AXIsProcessTrusted(),
              let window = Self.windows().first(where: { $0.id == saved.windowID }),
              let primary = NSScreen.screens.first,
              NSScreen.screens.contains(where: {
                  CGRect(x: $0.frame.minX, y: primary.frame.maxY - $0.frame.maxY,
                         width: $0.frame.width, height: $0.frame.height).contains(window.frame)
              }),
              let source = CGEventSource(stateID: .hidSystemState) else { return false }
        busy = true
        defer { busy = false }
        let point = CGPoint(x: window.frame.midX, y: window.frame.midY)
        guard let down = event(.leftMouseDown, point: point, window: window.id, pid: saved.item.pid, source: source, isMove: false),
              let up = event(.leftMouseUp, point: point, window: window.id, pid: saved.item.pid, source: source, isMove: false) else { return false }
        down.flags = []; up.flags = []
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 0)
        let cursor = CGEvent(source: nil)?.location
        source.localEventsSuppressionInterval = 0
        let delivered = await Relay.send(down, pid: saved.item.pid, redeliver: false)
        let released = await Relay.send(up, pid: saved.item.pid, redeliver: false)
        if let cursor { CGWarpMouseCursorPosition(cursor) }
        return delivered && released
    }

    private func move(id: CGWindowID, pid: pid_t, beside targetID: CGWindowID, right: Bool, attempts: Int = 3) async -> Bool {
        guard AXIsProcessTrusted(), !Task.isCancelled else { return false }
        let windows = Self.windows()
        guard let item = windows.first(where: { $0.id == id }),
              let target = windows.first(where: { $0.id == targetID }),
              let source = CGEventSource(stateID: .hidSystemState) else { return false }
        var start = CGPoint(x: right ? target.frame.maxX : target.frame.minX, y: target.frame.minY)
        var end = start
        if (right ? item.frame.minX <= target.frame.maxX : item.frame.maxX <= target.frame.minX) {
            end.x -= item.frame.width
        } else { start.x += right ? 1 : -1 }
        guard let down = event(.leftMouseDown, point: start, window: id, pid: pid, source: source),
              let up = event(.leftMouseUp, point: end, window: targetID, pid: pid, source: source) else { return false }
        down.flags = .maskCommand
        up.flags = []
        let cursor = CGEvent(source: nil)?.location
        source.localEventsSuppressionInterval = 0
        _ = await Relay.send(down, pid: pid)
        try? await Task.sleep(for: .milliseconds(40))
        // Always release even if the down event timed out or the caller cancelled.
        _ = await Relay.send(up, pid: pid)
        // Tahoe requires a second release to leave native drag tracking.
        _ = await Relay.send(up, pid: pid)
        if let cursor { CGWarpMouseCursorPosition(cursor) }
        // Tahoe animates the hosted windows after the event has been accepted.
        // Wait for settled geometry, not just delivery of the mouse-up event.
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(50))
            let current = Self.windows()
            guard let moved = current.first(where: { $0.id == id }),
                  let targetNow = current.first(where: { $0.id == targetID }) else { return false }
            if abs(right ? moved.frame.minX - targetNow.frame.maxX : moved.frame.maxX - targetNow.frame.minX) < 4 {
                return true
            }
            if Task.isCancelled { return false }
        }
        if attempts > 1 && !Task.isCancelled {
            return await move(id: id, pid: pid, beside: targetID, right: right, attempts: attempts - 1)
        }
        return false
    }

    private func event(_ type: CGEventType, point: CGPoint, window: CGWindowID,
                       pid: pid_t, source: CGEventSource, isMove: Bool = true) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: point, mouseButton: .left) else { return nil }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(window))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(window))
        if isMove, let windowField = CGEventField(rawValue: 0x33) {
            event.setIntegerValueField(windowField, value: Int64(window))
        }
        return event
    }

    /// Relay only our uniquely tagged event through the owning app and session.
    /// Taps are scoped to one operation, bounded to 350 ms and always removed.
    private final class Relay: @unchecked Sendable {
        // Event taps and completion blocks all run on the main run loop.
        let event: CGEvent
        let pid: pid_t
        var phase = 0
        let redeliver: Bool
        var taps: [CFMachPort] = []
        var sources: [CFRunLoopSource] = []
        var continuation: CheckedContinuation<Bool, Never>?
        init(_ event: CGEvent, pid: pid_t, redeliver: Bool) { self.event = event; self.pid = pid; self.redeliver = redeliver }

        @MainActor static func send(_ event: CGEvent, pid: pid_t, redeliver: Bool = true) async -> Bool {
            let relay = Relay(event, pid: pid, redeliver: redeliver)
            return await withCheckedContinuation { continuation in
                relay.continuation = continuation
                relay.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { relay.finish(false) }
            }
        }

        func start() {
            let pointer = Unmanaged.passUnretained(self).toOpaque()
            let mask = CGEventMask(1) << event.type.rawValue
            let callback: CGEventTapCallBack = { _, _, received, pointer in
                guard let pointer else { return Unmanaged.passUnretained(received) }
                let relay = Unmanaged<Relay>.fromOpaque(pointer).takeUnretainedValue()
                guard received.getIntegerValueField(.eventSourceUserData)
                    == relay.event.getIntegerValueField(.eventSourceUserData) else { return Unmanaged.passUnretained(received) }
                if relay.phase == 0 {
                    relay.phase = 1
                    relay.event.post(tap: .cgSessionEventTap)
                    return nil
                }
                if relay.phase == 2 {
                    relay.phase = 3
                    DispatchQueue.main.async { relay.finish(true) }
                }
                return Unmanaged.passUnretained(received)
            }
            let session: CGEventTapCallBack = { _, _, received, pointer in
                guard let pointer else { return Unmanaged.passUnretained(received) }
                let relay = Unmanaged<Relay>.fromOpaque(pointer).takeUnretainedValue()
                if relay.phase == 1 && received.getIntegerValueField(.eventSourceUserData)
                    == relay.event.getIntegerValueField(.eventSourceUserData) {
                    relay.phase = 2
                    received.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(relay.pid))
                    if relay.redeliver { relay.event.postToPid(relay.pid) }
                    else {
                        // Clicks must reach the app once. Reposting the real
                        // event here can immediately toggle a custom menu shut.
                        relay.phase = 3
                        DispatchQueue.main.async { relay.finish(true) }
                    }
                }
                return Unmanaged.passUnretained(received)
            }
            guard let appTap = CGEvent.tapCreateForPid(pid: pid, place: .headInsertEventTap,
                    options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: pointer) else { finish(false); return }
            taps.append(appTap)
            guard let sessionTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
                    options: .listenOnly, eventsOfInterest: mask, callback: session, userInfo: pointer) else { finish(false); return }
            taps.append(sessionTap)
            for tap in taps {
                let source = CFMachPortCreateRunLoopSource(nil, tap, 0)!
                sources.append(source)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            event.postToPid(pid)
        }

        func finish(_ success: Bool) {
            guard let continuation else { return }
            self.continuation = nil
            for tap in taps { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
            for source in sources { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            taps.removeAll()
            sources.removeAll()
            continuation.resume(returning: success)
        }
    }
}
