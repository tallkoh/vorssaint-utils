// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Keep the membership decision independent of Accessibility and AppKit.
/// Native menu-bar order is the source of truth; no fragile PID/title preferences.
enum MenuBarShelfSupport {
    static func belongsInShelf(item: CGRect, divider: CGRect, screen: CGRect) -> Bool {
        guard item.width > 0, item.height > 0, divider.width > 0 else { return false }
        // AppKit reports an offscreen sentinel at the bottom of the display for
        // some overflow items. They still belong in the shelf.
        if item.minX < screen.minX || item.minY >= screen.maxY - 1 { return true }
        guard abs(item.midY - divider.midY) < max(40, divider.height) else { return false }
        return item.midX < divider.maxX
    }

    static func collapsedLength(screenWidths: [CGFloat]) -> CGFloat {
        // A finite length comfortably larger than even a multi-monitor desktop.
        max(10_000, screenWidths.reduce(0, +) * 2)
    }
}
