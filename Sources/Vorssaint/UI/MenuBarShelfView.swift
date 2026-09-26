// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The shelf is deliberately only a single strip. Setup and explanatory copy
/// live in Settings so this transient surface cannot grow into a second panel.
struct MenuBarShelfView: View {
    @ObservedObject var service: MenuBarShelfService
    @ObservedObject private var l10n = L10n.shared
    @State private var hovered: String?
    private var text: MenuBarShelfStrings { FeatureStrings.menuBarShelf(l10n.language) }

    var body: some View {
        HStack(spacing: 6) {
            if service.loading && service.items.isEmpty {
                ProgressView().controlSize(.small).frame(width: 30, height: 30)
            } else if service.items.isEmpty {
                Button(text.arrange) { service.showSettings() }
                    .buttonStyle(.plain).font(.system(size: 12))
                    .padding(.horizontal, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(service.items) { item in
                            Button { service.open(item) } label: {
                                Image(nsImage: item.applicationURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
                                      ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)!)
                                    .resizable().scaledToFit().frame(width: 20, height: 20)
                                    .frame(width: 32, height: 32)
                                    .background(hovered == item.id ? Color.primary.opacity(0.08) : .clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovered = $0 ? item.id : nil }
                            .help(item.name).accessibilityLabel(item.name)
                        }
                    }
                }
                .frame(width: MenuBarShelfSupport.stripWidth(itemCount: service.items.count))
            }
            if service.error != nil {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange).help(service.error ?? "")
                    .accessibilityLabel(service.error ?? "")
            }
            Divider().frame(height: 18)
            Menu {
                Button(service.arranging ? text.done : text.arrange) { service.setArranging(!service.arranging) }
                Button(l10n.s.homebrewRefresh) { service.refresh() }
                Button(l10n.s.panelSettings) { service.showSettings() }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width: 24).help(text.title)
        }
        .padding(.horizontal, 10)
        .frame(height: MenuBarShelfSupport.stripHeight)
        .fixedSize()
    }
}

struct MenuBarShelfSettings: View {
    @ObservedObject private var l10n = L10n.shared
    private var text: MenuBarShelfStrings { FeatureStrings.menuBarShelf(l10n.language) }
    @AppStorage(DefaultsKey.menuBarShelfEnabled) private var enabled = false
    @ObservedObject private var service = MenuBarShelfService.shared
    @ObservedObject private var permissions = Permissions.shared

    var body: some View {
        SettingsCard(title: text.title) {
            SettingsRow(symbol: "square.grid.2x2", title: text.title,
                        caption: text.caption) {
                Toggle(text.title, isOn: $enabled).labelsHidden().toggleStyle(.switch)
                    .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
            }
            if enabled {
                if !permissions.accessibility {
                    Text(l10n.s.permissionAccessibility)
                        .font(.caption).foregroundStyle(.secondary)
                    Button(l10n.s.permissionRequest) { permissions.requestAccessibility() }
                } else {
                    Text(text.instructions)
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = service.error {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                    HStack {
                        Button(service.arranging ? text.done : text.arrange) {
                            service.setArranging(!service.arranging)
                        }
                        Button(text.open) { service.toggle() }
                    }
                }
            }
        }
    }
}
