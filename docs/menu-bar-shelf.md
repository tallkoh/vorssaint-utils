# Menu bar shelf

This fork adds an opt-in menu bar manager. Enable **Menu bar shelf** in Features,
then use **Arrange** in the main Vorssaint dropdown (also available in
**Settings → Menu bar**). A scrollable list includes hidden items by name and
app icon. Switch **Keep visible** on for your favourites, off to put an item in
the shelf. Choose Done when finished. No offscreen dragging is needed.

Click the chevron for a compact, horizontally scrollable row of app icons. Hover
for names; click to open the original app's menu. A permanent Vorssaint button opens the main panel directly, even if its original icon is hidden. The ellipsis offers arrangement,
refresh, and Settings. The main Vorssaint panel and the shelf dismiss one another.

The selected native item briefly moves beside the chevron before opening. It
returns when its menu closes, when the shelf next opens, or on a normal quit.
Return and pin operations briefly expand the divider so their destination is
onscreen. If the original neighbour remains offscreen, the item returns to the
shelf boundary instead; hidden-item order may change.
Long-lived app windows stop the dismissal poll after one minute; opening the
shelf again returns the item. The return monitor must observe a menu/window
before interpreting its disappearance as dismissal. Apps that expose neither
keep their temporary anchor until the next shelf action. Disabling the feature removes the divider and
restores access to the whole menu bar. If a nested macOS modal loop prevents
cleanup during Quit, a bounded fallback lets the process exit and removes the
divider; all icons remain accessible. The app does not change other apps' settings.

## Implementation

- Accessibility supplies each original application's menu extras and actions.
  On Tahoe the actual windows are hosted by Control Centre, so the window-owner
  PID alone cannot identify the application.
- The native divider position is the membership source of truth. AppKit's
  autosaved status-item positions preserve arrangement. Machine-specific setup
  completion is excluded from settings backups.
- The shelf uses app icons and accessible names, so Screen Recording is not
  required. Window titles, when already available, improve anchor lookup; cached
  window IDs and geometry support the Accessibility-only path.
- Native item movement uses short-lived, uniquely tagged event taps and verified
  window IDs. Ambiguous or stale matches fail without clicking another app.
  Each tap expires within 350 ms. Mouse-up is sent twice to leave Tahoe's native
  drag tracking, including when an operation is cancelled.
- The bridge waits for native geometry to settle, with up to three move attempts.
  Items exposing an NSMenu use AXPress after reveal; custom buttons use native
  clicks. Unsupported AX actions fall back to the native path. Native clicks
  use a separate single-delivery path with no move-only window field;
  they never replay a real click through both the session and app. Moves still
  use the double-release native drag protocol.
- Permission refresh publishes immediately on the main thread before request
  code decides whether to show the missing-access guide. Settings also exposes
  the existing stale-signature repair path when access is absent.
- The tray is 48 points tall. Its icon area is capped at 356 points and scrolls
  horizontally. Setup text lives exclusively in Settings.

The native event-routing approach was informed by
[Ice](https://github.com/jordanbaird/Ice) by Jordan Baird and contributors and
[Ice 2](https://github.com/teddychan/ice-2) by Teddy Chan and contributors, both
GPL-3.0. This fork retains the repository's GPL-3.0-or-later license. No Ice
binaries or private user data are bundled.

## Verification

```sh
./build.sh --dev
build/VorssaintDeveloper --selftest
./build.sh --test-suite=menu-bar-shelf --test-suite=features \
  --test-suite=settings --test-suite=localization --test-suite=command-bar
./Tools/test-menu-bar-shelf.sh
```

The native smoke test is interactive and requires Accessibility. It creates a
throwaway fixture app and temporarily hides menu bar items for a few seconds. It
runs both a native NSMenu and a custom toggle-panel fixture. It asserts the
fixture starts physically offscreen, moves beside the test anchor, opens a
visible native surface, and returns to its original neighbour. The toggle
fixture catches duplicate clicks that would immediately close its panel.
Only the PID of the fixture it launches can be targeted. Both fixture and test
status items are removed when the processes exit.

Verified locally on an Apple-silicon Mac running macOS 26.4.1: development build,
selftest, catalog/settings/localization unit suites, compact tray rendering, and
native hidden-item reveal/menu/return with both fixture types. OneDrive’s
Activity Centre and Rectangle’s native menu opened from the installed shelf;
Chrome was pinned and unpinned using the named list. Multiple displays,
auto-hiding menu bars, full-screen Spaces, macOS 14/15/27, and every third-party
app's custom popover still need wider hardware testing. This is a development
build, not a notarized release.
