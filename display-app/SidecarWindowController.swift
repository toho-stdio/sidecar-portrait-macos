//
//  SidecarWindowController.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import AppKit
import CoreGraphics

final class SidecarWindowController {
    let window: NSWindow
    private let metalView: MetalDisplayView
    private let overlayLabel: NSTextField
    private let overlayView: NSView
    private let targetScreen: NSScreen
    private let virtualDisplayID: CGDirectDisplayID

    init(screen: NSScreen, renderer: MetalRenderer, virtualDisplayID: CGDirectDisplayID) {
        self.targetScreen = screen
        self.virtualDisplayID = virtualDisplayID
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
        // window.ignoresMouseEvents = true // Disabled to allow input capture

        metalView = MetalDisplayView(frame: NSRect(origin: .zero, size: size), renderer: renderer)
        metalView.autoresizingMask = [.width, .height]
        
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
        
        // Setup input forwarding - Now safe because all properties are initialized
        metalView.inputHandler = { [weak self] event, normalizedPoint in
            self?.handleInput(event: event, normalizedPoint: normalizedPoint)
        }

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]
        container.addSubview(metalView)
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
    
    private func handleInput(event: NSEvent, normalizedPoint: CGPoint) {
        let bounds = CGDisplayBounds(virtualDisplayID)
        let targetX = bounds.origin.x + normalizedPoint.x * bounds.width
        let targetY = bounds.origin.y + normalizedPoint.y * bounds.height
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        // Map NSEvent type to CGEventType
        let eventType: CGEventType?
        var mouseButton: CGMouseButton = .left
        
        switch event.type {
        case .leftMouseDown:
            eventType = .leftMouseDown
            mouseButton = .left
        case .leftMouseUp:
            eventType = .leftMouseUp
            mouseButton = .left
        case .leftMouseDragged:
            eventType = .leftMouseDragged
            mouseButton = .left
        case .rightMouseDown:
            eventType = .rightMouseDown
            mouseButton = .right
        case .rightMouseUp:
            eventType = .rightMouseUp
            mouseButton = .right
        case .rightMouseDragged:
            eventType = .rightMouseDragged
            mouseButton = .right
        case .otherMouseDown:
            eventType = .otherMouseDown
            mouseButton = .center
        case .otherMouseUp:
            eventType = .otherMouseUp
            mouseButton = .center
        case .otherMouseDragged:
            eventType = .otherMouseDragged
            mouseButton = .center
        case .scrollWheel:
            eventType = .scrollWheel
        default:
            eventType = nil
        }
        
        guard let type = eventType else { return }
        
        if type == .scrollWheel {
            let scrollY = Int32(event.scrollingDeltaY)
            let scrollX = Int32(event.scrollingDeltaX)
            
            if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                         units: .pixel,
                                         wheelCount: 2,
                                         wheel1: scrollY,
                                         wheel2: scrollX,
                                         wheel3: 0) {
                scrollEvent.location = targetPoint
                scrollEvent.post(tap: .cghidEventTap)
            }
        } else {
            if let mouseEvent = CGEvent(mouseEventSource: nil,
                                        mouseType: type,
                                        mouseCursorPosition: targetPoint,
                                        mouseButton: mouseButton) {
                
                if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
                     mouseEvent.setIntegerValueField(.mouseEventClickState, value: Int64(event.clickCount))
                }
                
                mouseEvent.post(tap: .cghidEventTap)
            }
        }
    }
}
