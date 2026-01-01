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
}
