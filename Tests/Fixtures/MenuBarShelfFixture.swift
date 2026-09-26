// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
final class Delegate: NSObject, NSApplicationDelegate {
 var status: NSStatusItem!
 var panel: NSPanel!
 func applicationDidFinishLaunching(_ notification: Notification) {
  NSApp.setActivationPolicy(.accessory)
  status = NSStatusBar.system.statusItem(withLength: 26)
  status.button?.image = NSImage(systemSymbolName:"testtube.2",accessibilityDescription:"Shelf test")
  if CommandLine.arguments.contains("--custom") {
   panel = NSPanel(contentRect: NSRect(x: 600, y: 400, width: 240, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: false)
   panel.title = "Shelf fixture panel"
   panel.hidesOnDeactivate = false
   status.button?.target = self
   status.button?.action = #selector(togglePanel)
   return
  }
  let menu=NSMenu(title:"Shelf test")
  menu.addItem(withTitle:"Shelf fixture opened",action:nil,keyEquivalent:"")
  let quit=menu.addItem(withTitle:"Quit fixture",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"")
  quit.target=NSApp
  status.menu=menu
 }
 @objc func togglePanel() {
  FileHandle.standardOutput.write(Data("toggle visible=\(panel.isVisible)\n".utf8))
  if panel.isVisible { panel.orderOut(nil) }
  else { panel.makeKeyAndOrderFront(nil) }
 }
}
let app=NSApplication.shared
let delegate=Delegate()
app.delegate=delegate
app.run()
