// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct MenuBarShelfView: View {
    @ObservedObject var service: MenuBarShelfService
    @ObservedObject private var l10n = L10n.shared
    private var text: MenuBarShelfStrings { FeatureStrings.menuBarShelf(l10n.language) }
    @State private var search = ""
    private var filtered: [MenuBarShelfItem] {
        service.items.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(text.title, systemImage: "square.grid.2x2").font(.headline)
                Spacer()
                Button { service.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help(l10n.s.homebrewRefresh).accessibilityLabel(l10n.s.homebrewRefresh)
                Button(service.arranging ? text.done : text.arrange) { service.setArranging(!service.arranging) }
            }
            if service.arranging {
                Text(text.instructions)
                    .font(.callout).foregroundStyle(.secondary)
            }
            TextField(text.search, text: $search)
                .textFieldStyle(.roundedBorder)
            if service.loading {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else if filtered.isEmpty {
                Text(text.empty)
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 94, maximum: 116))], spacing: 10) {
                        ForEach(filtered) { item in
                            Button { service.open(item) } label: {
                                VStack(spacing: 8) {
                                    Image(nsImage: item.applicationURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
                                          ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)!)
                                        .resizable().scaledToFit().frame(width: 28, height: 28)
                                    Text(item.name).font(.system(size: 11)).lineLimit(2)
                                        .multilineTextAlignment(.center).frame(height: 30)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            .help(item.name).accessibilityLabel(item.name)
                        }
                    }
                    .padding(2)
                }
                .frame(maxHeight: 300)
            }
            if let error = service.error {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(18).frame(width: 390)
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
