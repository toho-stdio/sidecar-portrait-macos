//
//  MetalRenderer.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import AppKit
import Metal
import MetalKit
import CoreVideo

final class MetalRenderer {
    enum RotationMode: UInt32 {
        case none = 0
        case ccw = 1
        case cw = 2
    }

    enum RenderMode: UInt32 {
        case normal = 0
        case testPattern = 1
    }

    enum ScaleMode {
        case fit
        case fill
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private let samplerState: MTLSamplerState
    private var textureCache: CVMetalTextureCache?
    private let renderQueue = DispatchQueue(label: "display-app.metal.render")
    private var rotationMode: RotationMode = .ccw
    private var scaleMode: ScaleMode = .fit
    private var renderMode: RenderMode = .normal
    private var frameCounter: Int = 0

    weak var layer: CAMetalLayer? {
        didSet {
            layer?.device = device
            layer?.pixelFormat = .bgra8Unorm
            layer?.framebufferOnly = true
        }
    }

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal not supported")
        }

        self.device = device
        self.commandQueue = commandQueue

        let library = try? device.makeLibrary(source: MetalRenderer.shaderSource, options: nil)
        guard let library,
              let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            fatalError("Failed to create Metal shader library")
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }

        let quadVertices: [Float] = [
            -1, -1, 0, 1,
             1, -1, 1, 1,
            -1,  1, 0, 0,
             1,  1, 1, 0
        ]

        guard let vertexBuffer = device.makeBuffer(bytes: quadVertices,
                                                   length: quadVertices.count * MemoryLayout<Float>.size,
                                                   options: .storageModeShared) else {
            fatalError("Failed to create vertex buffer")
        }

        self.vertexBuffer = vertexBuffer

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        self.samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!

        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }

    func resetFrameCounter() {
        renderQueue.async { [weak self] in
            self?.frameCounter = 0
        }
    }

    func update(rotationMode: RotationMode, scaleMode: ScaleMode, renderMode: RenderMode) {
        renderQueue.async { [weak self] in
            self?.rotationMode = rotationMode
            self?.scaleMode = scaleMode
            self?.renderMode = renderMode
            let scaleText: String
            switch scaleMode {
            case .fill:
                scaleText = "fill"
            case .fit:
                scaleText = "fit"
            }
            NSLog("Renderer settings: rotation=%u scale=%@ render=%u",
                  rotationMode.rawValue, scaleText, renderMode.rawValue)
        }
    }

    func render(pixelBuffer: CVPixelBuffer, contentRect: CGRect) {
        renderQueue.async { [weak self] in
            self?.draw(pixelBuffer: pixelBuffer, contentRect: contentRect)
        }
    }

    private func draw(pixelBuffer: CVPixelBuffer, contentRect: CGRect) {
        guard let layer else { return }
        guard let drawable = layer.nextDrawable() else {
            if frameCounter % 120 == 0 {
                NSLog("Renderer: nextDrawable returned nil")
            }
            return
        }
        guard let texture = makeTexture(from: pixelBuffer) else { return }

        let srcWidth = Float(CVPixelBufferGetWidth(pixelBuffer))
        let srcHeight = Float(CVPixelBufferGetHeight(pixelBuffer))
        let dstWidth = Float(drawable.texture.width)
        let dstHeight = Float(drawable.texture.height)
        let useRotation = rotationMode != .none
        let contentWidth = max(Float(contentRect.width) * srcWidth, 1)
        let contentHeight = max(Float(contentRect.height) * srcHeight, 1)
        let targetWidth = useRotation ? contentHeight : contentWidth
        let targetHeight = useRotation ? contentWidth : contentHeight
        let scaleValue: Float
        switch scaleMode {
        case .fit:
            scaleValue = min(dstWidth / targetWidth, dstHeight / targetHeight)
        case .fill:
            scaleValue = max(dstWidth / targetWidth, dstHeight / targetHeight)
        }

        let params = Params(scale: scaleValue,
                            rotateMode: rotationMode.rawValue,
                            renderMode: renderMode.rawValue,
                            pad0: 0,
                            contentOrigin: SIMD2(Float(contentRect.origin.x), Float(contentRect.origin.y)),
                            contentSize: SIMD2(Float(contentRect.width), Float(contentRect.height)))
        if frameCounter == 0 {
            let modeText: String
            switch scaleMode {
            case .fill:
                modeText = "fill"
            case .fit:
                modeText = "fit"
            }
            NSLog("Renderer frame: src %.0fx%.0f dst %.0fx%.0f rotate=%u scale=%.3f render=%u",
                  srcWidth, srcHeight, dstWidth, dstHeight, rotationMode.rawValue, scaleValue, renderMode.rawValue)
            NSLog("Renderer contentRect: %.3f,%.3f %.3f,%.3f",
                  contentRect.origin.x, contentRect.origin.y,
                  contentRect.size.width, contentRect.size.height)
            NSLog("Renderer target: content %.0fx%.0f target %.0fx%.0f mode %@",
                  contentWidth, contentHeight, targetWidth, targetHeight, modeText)
        }
        frameCounter += 1

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        encoder.setViewport(MTLViewport(originX: 0,
                                        originY: 0,
                                        width: Double(dstWidth),
                                        height: Double(dstHeight),
                                        znear: 0,
                                        zfar: 1))
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.setFragmentBytes([params], length: MemoryLayout<Params>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTextureOut: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTextureOut
        )
        guard status == kCVReturnSuccess, let cvTexture = cvTextureOut else {
            return nil
        }
        return CVMetalTextureGetTexture(cvTexture)
    }
}

private struct Params {
    var scale: Float
    var rotateMode: UInt32
    var renderMode: UInt32
    var pad0: UInt32
    var contentOrigin: SIMD2<Float>
    var contentSize: SIMD2<Float>
}

private extension MetalRenderer {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
        float2 uv [[attribute(1)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    struct Params {
        float scale;
        uint rotateMode;
        uint renderMode;
        uint pad0;
        float2 contentOrigin;
        float2 contentSize;
    };

    vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.uv = in.uv;
        return out;
    }

    fragment float4 fragment_main(VertexOut in [[stage_in]],
                                  constant Params &params [[buffer(0)]],
                                  texture2d<float> tex [[texture(0)]],
                                  sampler samp [[sampler(0)]]) {
        float2 uv = (in.uv - 0.5) / params.scale + 0.5;
        if (params.renderMode == 1) {
            // Debug test pattern for visibility/orientation.
            float2 g = floor(in.uv * 8.0);
            float checker = fmod(g.x + g.y, 2.0);
            float3 base = mix(float3(0.1, 0.1, 0.1), float3(0.3, 0.3, 0.3), checker);
            float3 quad = (in.uv.x < 0.5) ?
                ((in.uv.y < 0.5) ? float3(1.0, 0.2, 0.2) : float3(0.2, 1.0, 0.2)) :
                ((in.uv.y < 0.5) ? float3(0.2, 0.2, 1.0) : float3(1.0, 1.0, 0.2));
            float2 edge = smoothstep(0.0, 0.01, min(in.uv, 1.0 - in.uv));
            float border = 1.0 - min(edge.x, edge.y);
            float3 color = mix(base, quad, 0.7);
            color = mix(color, float3(1.0, 1.0, 1.0), border);
            return float4(color, 1.0);
        }

        float2 contentUV;
        if (params.rotateMode == 1) {
            // CCW: swap axes within the content rect.
            contentUV = params.contentOrigin + float2(uv.y, 1.0 - uv.x) * params.contentSize;
        } else if (params.rotateMode == 2) {
            // CW: swap axes within the content rect.
            contentUV = params.contentOrigin + float2(1.0 - uv.y, uv.x) * params.contentSize;
        } else {
            contentUV = params.contentOrigin + uv * params.contentSize;
        }
        return tex.sample(samp, contentUV);
    }
    """
}
