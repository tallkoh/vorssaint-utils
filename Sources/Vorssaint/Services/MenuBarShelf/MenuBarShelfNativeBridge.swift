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
    func restore() async -> Bool {
        guard !busy else { return false }
        guard let saved = borrowed else { return true }
        guard NSRunningApplication(processIdentifier: saved.item.pid) != nil else {
            borrowed = nil
            return true
        }
        busy = true
        defer { busy = false }
        let restored = await move(id: saved.windowID, pid: saved.item.pid, beside: saved.successorID, right: false)
        if restored { borrowed = nil }
        return restored
    }

    private func move(id: CGWindowID, pid: pid_t, beside targetID: CGWindowID, right: Bool) async -> Bool {
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
        return false
    }

    private func event(_ type: CGEventType, point: CGPoint, window: CGWindowID,
                       pid: pid_t, source: CGEventSource) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: point, mouseButton: .left) else { return nil }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(window))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(window))
        if let windowField = CGEventField(rawValue: 0x33) {
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
        var taps: [CFMachPort] = []
        var sources: [CFRunLoopSource] = []
        var continuation: CheckedContinuation<Bool, Never>?
        init(_ event: CGEvent, pid: pid_t) { self.event = event; self.pid = pid }

        @MainActor static func send(_ event: CGEvent, pid: pid_t) async -> Bool {
            let relay = Relay(event, pid: pid)
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
                    relay.event.postToPid(relay.pid)
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
