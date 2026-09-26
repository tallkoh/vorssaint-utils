// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

struct MenuBarShelfItem: Identifiable {
    let id: String
    let name: String
    let applicationURL: URL?
    let element: AXUIElement
    let frame: CGRect
    let pid: pid_t
}

/// AXExtrasMenuBar belongs to the original app even when Control Centre hosts
/// its window (macOS Tahoe). Window-owner PIDs cannot identify those items.
enum MenuBarShelfScanner {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute),
              let s = attribute(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
              AXValueGetValue(s as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: point, size: size)
    }

    static func hasOpenMenu(_ element: AXUIElement) -> Bool {
        let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.contains {
            frame($0) != nil && attribute($0, kAXRoleAttribute) as? String == kAXMenuRole
        }
    }

    static func scan(applications: [(pid_t, String, URL?)], ownPID: pid_t) -> [MenuBarShelfItem] {
        guard AXIsProcessTrusted() else { return [] }
        var result: [MenuBarShelfItem] = []
        for (pid, appName, url) in applications where pid != ownPID {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.15)
            guard let rawBar = attribute(app, kAXExtrasMenuBarAttribute),
                  CFGetTypeID(rawBar) == AXUIElementGetTypeID() else { continue }
            let bar = rawBar as! AXUIElement
            let children = attribute(bar, kAXChildrenAttribute) as? [AXUIElement] ?? []
            for (index, element) in children.enumerated() {
                guard let rect = frame(element) else { continue }
                let description = attribute(element, kAXDescriptionAttribute) as? String
                let title = attribute(element, kAXTitleAttribute) as? String
                let detail = [description, title].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
                let name = detail.map { $0 == appName ? appName : "\(appName) · \($0)" } ?? appName
                result.append(MenuBarShelfItem(id: "\(pid):\(index)", name: name,
                    applicationURL: url, element: element, frame: rect, pid: pid))
            }
        }
        return result.sorted { $0.frame.minX < $1.frame.minX }
    }
}
