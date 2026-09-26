# Native menu bar shelf

Follow the Mac's selected appearance in daytime and evening use. Use the system
popover material, SF type and symbols. The tray is 48 points tall, with 32-point
icon hit targets and 20-point app icons. Use 4-point icon spacing and 10-point
outer padding. Cap the icon strip at 356 points and scroll horizontally for
more items. Hover backgrounds are subtle system foreground at 8% opacity.
Labels belong in tooltips and accessibility labels. A trailing ellipsis exposes
arrange, refresh, and Settings. The main dropdown and Settings show setup instructions and a visible Done action. A permanent Vorssaint button in the shelf opens the main panel directly.

The shelf and main menu panel are mutually exclusive. Width follows item count,
so a single item never occupies an oversized panel. Preserve keyboard focus and
native menu actions. Explicit failure feedback is more important than decoration.

Arrangement is a scrollable list of detected apps with Keep visible switches.
It includes offscreen items; never require dragging something the user cannot
see. Only the chevron is a normal visible shelf control.
