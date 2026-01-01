//
//  SidecarWindowController.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import AppKit

final class SidecarWindowController {
    private let window: NSWindow
    private let metalView: MetalDisplayView
    private let overlayLabel: NSTextField
    private let overlayView: NSView
    private let targetScreen: NSScreen

    init(screen: NSScreen, renderer: MetalRenderer) {
        targetScreen = screen
        let frame = screen.frame
        let size = frame.size
        window = NSWindow(contentRect: frame,
                          styleMask: [.borderless],
                          backing: .buffered,
                          defer: false,
                          screen: screen)
        window.isOpaque = true
        window.backgroundColor = .black
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true

        metalView = MetalDisplayView(frame: NSRect(origin: .zero, size: size), renderer: renderer)
        metalView.autoresizingMask = [.width, .height]
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]
        container.addSubview(metalView)

        overlayView = NSView(frame: NSRect(origin: .zero, size: size))
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
        overlayView.autoresizingMask = [.width, .height]

        overlayLabel = NSTextField(labelWithString: "SIDECAR DEBUG")
        overlayLabel.font = NSFont.systemFont(ofSize: 48, weight: .bold)
        overlayLabel.textColor = NSColor.systemRed
        overlayLabel.alignment = .center
        overlayLabel.frame = CGRect(x: 0, y: size.height / 2 - 40, width: size.width, height: 80)
        overlayLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        overlayView.addSubview(overlayLabel)
        overlayView.isHidden = true

        container.addSubview(overlayView)
        window.contentView = container
    }

    func show() {
        window.setFrame(targetScreen.frame, display: true)
        window.setFrameOrigin(targetScreen.frame.origin)
        window.setContentSize(targetScreen.frame.size)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        logState()
    }

    func setDebugOverlay(enabled: Bool) {
        overlayView.isHidden = !enabled
    }

    func logState() {
        let screenInfo: String
        if let screen = window.screen {
            screenInfo = "\(screen.localizedName) frame=\(Int(screen.frame.width))x\(Int(screen.frame.height)) origin=\(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y)))"
        } else {
            screenInfo = "nil"
        }
        NSLog("Sidecar window screen: %@ visible=%d frame=%.0fx%.0f origin=%.0f,%.0f",
              screenInfo,
              window.isVisible ? 1 : 0,
              window.frame.width,
              window.frame.height,
              window.frame.origin.x,
              window.frame.origin.y)
    }
}
