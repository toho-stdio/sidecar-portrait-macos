//
//  MetalDisplayView.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import AppKit
import Metal

final class MetalDisplayView: NSView {
    private let renderer: MetalRenderer
    
    var inputHandler: ((NSEvent, CGPoint) -> Void)?

    init(frame frameRect: NSRect, renderer: MetalRenderer) {
        self.renderer = renderer
        super.init(frame: frameRect)
        wantsLayer = true
        if let metalLayer = layer as? CAMetalLayer {
            renderer.layer = metalLayer
            metalLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
            metalLayer.isOpaque = true
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeBackingLayer() -> CALayer {
        CAMetalLayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let metalLayer = layer as? CAMetalLayer {
            renderer.layer = metalLayer
        }
        updateDrawableSize()
    }

    override func layout() {
        super.layout()
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        guard let metalLayer = layer as? CAMetalLayer else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    // MARK: - Event Handling

    override func mouseDown(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func otherMouseDown(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func otherMouseUp(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func otherMouseDragged(with event: NSEvent) {
        handleEvent(event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        handleEvent(event)
    }
    
    private func handleEvent(_ event: NSEvent) {
        guard let handler = inputHandler else { return }
        
        let settings = renderer.currentSettings
        let location = convert(event.locationInWindow, from: nil)
        let bounds = self.bounds
        
        // Normalize view coordinates (0,0 is Top-Left to match Metal UVs)
        // location.y in NSView is 0 at bottom.
        let viewUV = CGPoint(x: location.x / bounds.width,
                             y: (bounds.height - location.y) / bounds.height)
        
        // Reverse scale transform: uv = (in.uv - 0.5) / params.scale + 0.5
        // So: intermediateUV = (viewUV - 0.5) / scale + 0.5
        let scale = CGFloat(settings.scale)
        let intermediateUV = CGPoint(x: (viewUV.x - 0.5) / scale + 0.5,
                                     y: (viewUV.y - 0.5) / scale + 0.5)
        
        // Check if point is within the drawn content area
        if intermediateUV.x < 0 || intermediateUV.x > 1 || intermediateUV.y < 0 || intermediateUV.y > 1 {
            return
        }
        
        // Reverse rotation and map to content rect
        let contentUV: CGPoint
        switch settings.rotation {
        case .ccw:
            // CCW: x -> y, y -> 1-x
            // Shader: contentUV = origin + float2(uv.y, 1.0 - uv.x) * size
            contentUV = CGPoint(x: settings.contentRect.origin.x + intermediateUV.y * settings.contentRect.width,
                                y: settings.contentRect.origin.y + (1.0 - intermediateUV.x) * settings.contentRect.height)
        case .cw:
            // CW: x -> 1-y, y -> x
            // Shader: contentUV = origin + float2(1.0 - uv.y, uv.x) * size
            contentUV = CGPoint(x: settings.contentRect.origin.x + (1.0 - intermediateUV.y) * settings.contentRect.width,
                                y: settings.contentRect.origin.y + intermediateUV.x * settings.contentRect.height)
        case .none:
            // None: x -> x, y -> y
            // Shader: contentUV = origin + uv * size
            contentUV = CGPoint(x: settings.contentRect.origin.x + intermediateUV.x * settings.contentRect.width,
                                y: settings.contentRect.origin.y + intermediateUV.y * settings.contentRect.height)
        }
        
        handler(event, contentUV)
    }
}
