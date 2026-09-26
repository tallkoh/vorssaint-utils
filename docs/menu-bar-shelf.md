# Menu bar shelf

This fork adds an opt-in menu bar manager. Enable **Menu bar shelf** in Features,
then use **Arrange** in the main Vorssaint dropdown (also available in **Settings → Menu bar**). Hold Command and drag the few icons you want
to keep to the right of the divider. Everything on its left goes into the shelf
when you choose Done. Keep the shelf's chevron to the right of the divider.

Click the chevron for a compact, horizontally scrollable row of app icons. Hover
for names; click to open the original app's menu. A permanent Vorssaint button opens the main panel directly, even if its original icon is hidden. The ellipsis offers arrangement,
refresh, and Settings. The main Vorssaint panel and the shelf dismiss one another.

The selected native item briefly moves beside the chevron before opening. It
returns when its menu closes, when the shelf next opens, or on a normal quit.
Long-lived app windows stop the dismissal poll after one minute; opening the
shelf again returns the item. Disabling the feature removes the divider and
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
- The bridge waits for the native windows to finish moving. AXPress may time out
  while an NSMenu is tracking; a visible menu or newly presented app window is
  accepted as evidence that it opened.
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
asserts the fixture starts physically offscreen, moves beside the test anchor,
opens a real menu inside the display, and returns to its original neighbour.
Only the PID of the fixture it launches can be targeted. Both fixture and test
status items are removed when the processes exit.

Verified locally on an Apple-silicon Mac running macOS 26.4.1: development build,
selftest, catalog/settings/localization unit suites, compact tray rendering, and
native hidden-item reveal/menu/return with the fixture. Multiple displays,
auto-hiding menu bars, full-screen Spaces, macOS 14/15/27, and every third-party
app's custom popover still need wider hardware testing. This is a development
build, not a notarized release.
