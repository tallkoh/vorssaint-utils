# Vorssaint fork

## Register
Product. A native macOS utility, built with AppKit and SwiftUI.

## Users and purpose
People with crowded Mac menu bars need to keep a handful of favourites visible
and access the remaining items quickly. The menu bar shelf is a transient
extension of the menu bar. It should take one click to open and one to choose an
item. The original app remains responsible for its menu and actions.

## Design principles
Use the system appearance and accessibility semantics. Keep setup in Settings.
The shelf is a small horizontal icon strip with names available on hover and to
VoiceOver. Never stack it over the main Vorssaint panel. Avoid card grids, search
forms, duplicated headings, instructions, and large blank areas in the tray.
Persist changes in focused commits while implementing this fork.
