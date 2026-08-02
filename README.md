# Rotated Sidecar (display-app)

A macOS app that makes Apple **Sidecar usable in portrait orientation**.

Sidecar normally treats the iPad as a landscape display. This app works around that by creating a **virtual portrait display**, capturing it with **ScreenCaptureKit**, rotating each frame in a **Metal shader**, and presenting the result full-screen in a borderless window on the physical Sidecar display.

Heavily inspired by BetterDisplay's Rotated Sidecar method: https://github.com/waydabber/BetterDisplay/wiki/Rotated-Sidecar

## How it works

```text
Virtual portrait display (CGVirtualDisplay, 1668x2388 hiDPI)
        ↓
ScreenCaptureKit capture (SCStream on the virtual display)
        ↓
Metal rotation + fit/fill scaling (inline shader, optional content crop)
        ↓
Borderless full-screen window (level .screenSaver) on the Sidecar display
```

You drag windows to the *virtual* portrait display; the iPad then shows them rotated to portrait. The iPad screen itself never receives windows — it only shows the video feed.

## Requirements

- **macOS 14+**
- **Sidecar-enabled iPad** running Sidecar in Extended Display mode
- **Screen Recording permission** (prompted on first capture start; also grantable in System Settings → Privacy & Security → Screen & System Audio Recording)
- No third-party dependencies

## Main features

- One-click **Start Portrait Session**: creates a portrait virtual display, starts capture, and presents on the iPad automatically
- Automatic Sidecar display placement — the real Sidecar display is moved to a small corner portal so your cursor never accidentally enters it, and restored when the session ends
- Rotate the virtual display between portrait ↔ landscape (swaps width/height)
- Metal renderer: CW/CCW/off rotation, fill/fit scaling, test pattern mode, content-rect cropping
- Borderless full-screen presentation window on the Sidecar display
- Status bar menu with live Sidecar status, start/restart, and **Restore Sidecar Position**
- Mouse input forwarding: clicks, drags, and scroll on the iPad map to the virtual display
- Sidecar disconnect handling: clean teardown, no leftover windows or virtual displays

## Install

Prebuilt app archive:
https://github.com/toho-stdio/sidecar-portrait-macos-source/blob/main/display-app-0.01.zip

## Quick Start

1. **Connect Sidecar**: connect your iPad and enable Sidecar in Extended Display mode.
2. **Start Portrait Session**: click the big button (or the menu bar item). The app resolves the real Sidecar display, moves it to a small corner portal, creates a portrait virtual display, starts capture, presents on the iPad, and auto-hides the control window after 5 s (click Cancel to keep it).
3. **Arrange the virtual display**: in System Settings, place the new virtual display next to your main monitor. This is the screen you actually use.
4. **Fix orientation if needed**: Advanced → **Rotate Virtual Display** (swaps dimensions) and **Rotate CW / CCW** (content rotation).
5. **Restart**: while running, the button becomes **Restart Portrait Session**.
6. **Restore position**: when the session ends the Sidecar display returns to its original position automatically.

## Controls

| Control | Behavior |
|---|---|
| Start Portrait Session (primary) | Full setup: detect Sidecar → create portrait virtual display → start capture → present on the iPad → auto-hide control window (5 s) |
| Restart Portrait Session (while running) | Stops the stream, validates the Sidecar target, reuses the virtual display, starts fresh |
| Status line | Result of the last action (idle / starting / running / stopping / error / disconnected) |
| Auto-hide countdown row | 5 s countdown with **Cancel** |
| Hide Control Window (Advanced) | Hides only the control window; the Sidecar presentation window stays |
| Refresh Displays (Advanced) | Re-scans displays and selection |
| Create Virtual Display (Advanced) | Manual: create a virtual display matching the Sidecar dimensions |
| Rotate Virtual Display (Advanced) | Manual: swap the virtual display dimensions (Landscape ↔ Portrait) |
| Rotation On/Off | Toggles the render rotation |
| Rotate CW / CCW | Rotation direction |
| Fill / Fit | Fill crops to full screen; fit preserves full content |
| Auto Rotation | Automatic rotation from captured content orientation |
| Crop On/Off | Uses ScreenCaptureKit `contentRect` for cropping |
| Pattern On/Off | Test pattern to verify the render path |
| Overlay On/Off | Red overlay to verify the Sidecar window |

## Status bar menu

```
Start Portrait Session / Restart Portrait Session   ← same action as the big button
Sidecar: Connected (name) / Not detected / Disconnected   ← live status
Restore Sidecar Position
────────────────────
Show App (⌘S)  ·  Quit (⌘Q)
```

- The action item is disabled while starting/stopping.
- The status-bar icon changes by state: `display` (idle), `display.badge.checkmark` (running), `display.trianglebadge.exclamationmark` (disconnected).
- **Restore Sidecar Position** stops the session, destroys the virtual display, and restores the Sidecar display to its original position.

## Stop / Reset a session

- **Quit**: status bar menu → **Quit** (or Cmd+Q).
- **Restart Portrait Session** stops the stream and restarts cleanly.
- If Sidecar disconnects: the app hides the presentation window, stops capture, destroys the virtual display, and re-arms the button — press **Start Portrait Session** again after reconnecting.
- Verify nothing was left behind: `system_profiler SPDisplaysDataType` should list only the built-in and any real external displays.

## Mouse/Pointer

The Sidecar window forwards **mouse events** (click, drag, scroll, all mouse buttons) to the virtual display via synthesized `CGEvent`s. Move your cursor onto the virtual display to interact. **Keyboard input is not forwarded** (mouse only).

## Known limitations

- Keyboard input is not forwarded to the virtual display.
- No automatic restart when Sidecar reconnects — a reconnected Sidecar may get a *new* display ID, so reconnect is treated as a fresh session (press Start again).
- Automatic Sidecar placement uses application-scoped display configuration — macOS reverts it when the app quits, and the app restores it on normal session end. Placement behavior should be validated on the macOS versions you support (Apple gives no special guarantees for Sidecar displays).
- Some HAL audio log lines are expected; audio capture is disabled.
