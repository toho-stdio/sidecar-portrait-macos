# Rotated Sidecar (display-app)

MacOS app that captures a virtual portrait display, rotates it, and shows it full-screen on a Sidecar display. It uses ScreenCaptureKit for capture and Metal for rotation/rendering.
Heavily inspired by BetterDisplay sidecar portrait method https://github.com/waydabber/BetterDisplay/wiki/Rotated-Sidecar. Any PR for changes and improvement are welcome
## Requirements

- macOS 14+
- Sidecar-enabled iPad
- Screen Recording permission (prompted on first run)

## Install
- Download and open built app zip https://github.com/toho-stdio/sidecar-portrait-macos-source/blob/main/display-app-0.01.zip

## Build & Run

1. Open `display-app/display-app.xcodeproj` in Xcode.
2. Build and run the `display-app` target.
3. When prompted, grant Screen Recording permission.

## Quick Start & Best Practices

Follow this workflow to set up your environment correctly:

1.  **Connect Sidecar**: Connect your iPad to your Mac and enable Sidecar (Extended Display mode).
2.  **Isolate Sidecar Display (Crucial)**:
    *   Open **System Settings > Displays > Arrange**.
    *   **Goal**: Prevent your mouse from accidentally moving to the real iPad screen (which is just showing a video feed).
    *   **Action**: Drag the **Sidecar Display** to a far corner (e.g., bottom-right diagonal) where you are unlikely to move your mouse.
3.  **Create Display**: In the app, click **Create Virtual Display**.
4.  **Arrange Virtual Display**:
    *   Back in System Settings, you will see a new display.
    *   Place this **Virtual Display** comfortably next to your main monitor. This is the screen you will actually use.
5.  **Rotate**: If the orientation is wrong (e.g., Landscape vs Portrait), click **Rotate Virtual Display**.
6.  **Final Sync**: Click **Restart Capture** to ensure the video feed is perfectly aligned.

![IMG_3694](https://github.com/user-attachments/assets/ddc5d5e9-6871-4d1a-9bce-198173ad028e)


## Usage Guide

The app provides a control panel with several buttons to manage the virtual display and capture process.

### Primary Controls

These buttons manage the virtual display lifecycle and capture stream:

*   **Create Virtual Display**:
    *   Detects your connected Sidecar display.
    *   Creates a new virtual display that matches the Sidecar's resolution.
    *   Use this when starting the app to establish the virtual screen.

*   **Rotate Virtual Display**:
    *   Swaps the width and height of the current virtual display (Landscape ↔ Portrait).
    *   Destroys the current virtual display and creates a new one with the inverted dimensions.
    *   Use this if the virtual display orientation doesn't match your physical Sidecar orientation.

*   **Restart Capture**:
    *   Stops and restarts the ScreenCaptureKit stream.
    *   Refreshes the display list and re-attaches the Sidecar window.
    *   Use this if the stream freezes or if you've physically reconnected the Sidecar.

### Rotation Controls (CW / CCW)

While "Rotate Virtual Display" changes the *screen dimensions*, these buttons control how the *content* is rendered:

*   **Rotation On/Off**: Toggles the rendering rotation effect.
*   **Rotate CW / Rotate CCW**:
    *   Switches the rotation direction between Clockwise (CW) and Counter-Clockwise (CCW).
    *   Use **Rotate CW** (Clockwise) if the content is sideways 90°.
    *   Use **Rotate CCW** (Counter-Clockwise) if the content is sideways -90° (or 270°).

## How It Works

- A virtual display is created in portrait mode.
- The app captures that display with ScreenCaptureKit.
- Each frame is rotated in a Metal shader.
- The rotated frame is presented in a borderless, full-screen window on the Sidecar display.

## Defaults (UserDefaults)

You can override these in Xcode’s Run Scheme > Arguments > Environment, or in code:

- `vdPortrait` (Bool, default `true`)  
  - `true` => 1668x2388  
  - `false` => 2388x1668
- `vdWidth` / `vdHeight` (Int)  
  - If set, these override `vdPortrait`.
- `vdFrameRate` (Double, default `120.0`)
- `vdHiDPI` (Bool, default `true`)
- `vdName` (String, default `"Virtual Portrait"`)
- `vdPPI` (Int, default `264`)
- `vdMirror` (Bool, default `false`)
- `sidecarDisplayID` / `virtualDisplayID` (Int)  
  - Force a display selection by display ID.
- `virtualDisplayName` (String)  
  - Match a display by name (substring).

## UI Controls

- `Restart Capture`: restarts the ScreenCaptureKit stream.
- `Refresh Displays`: re-scan displays and selection.
- `Rotation On/Off`: toggles rotation.
- `Rotate CW/CCW`: rotation direction.
- `Fill/Fit`: fill crops to full screen; fit preserves full content.
- `Auto Rotation`: automatic rotation based on captured content orientation.
- `Crop On/Off`: use ScreenCaptureKit contentRect for cropping.
- `Pattern On/Off`: shows a test pattern to verify the render path.
- `Overlay On/Off`: shows a red overlay to verify the Sidecar window.

## Mouse/Pointer

The Sidecar window is output-only. Move the cursor to the virtual display to interact; the cursor will appear in the capture output. Input forwarding is not implemented.

## Notes

- If the Sidecar window shows nothing, toggle **Overlay** or **Pattern** to verify the window is visible and the Metal layer is rendering.
- Some log messages about HAL audio are expected; audio capture is disabled.
