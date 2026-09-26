// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
final class Delegate: NSObject, NSApplicationDelegate {
 var status: NSStatusItem!
 func applicationDidFinishLaunching(_ notification: Notification) {
  NSApp.setActivationPolicy(.accessory)
  status = NSStatusBar.system.statusItem(withLength: 26)
  status.button?.image = NSImage(systemSymbolName:"testtube.2",accessibilityDescription:"Shelf test")
  let menu=NSMenu(title:"Shelf test")
  menu.addItem(withTitle:"Shelf fixture opened",action:nil,keyEquivalent:"")
  let quit=menu.addItem(withTitle:"Quit fixture",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"")
  quit.target=NSApp
  status.menu=menu
 }
}
let app=NSApplication.shared
let delegate=Delegate()
app.delegate=delegate
app.run()
