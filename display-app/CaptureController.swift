//
//  CaptureController.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import Foundation
import ScreenCaptureKit
import CoreMedia

final class CaptureController: NSObject, SCStreamOutput {
    private let renderer: MetalRenderer
    private let statusHandler: (String) -> Void
    private let logHandler: (String) -> Void
    private let frameInfoHandler: (CGSize, CGSize, CGSize) -> Void
    private let outputQueue = DispatchQueue(label: "display-app.capture.output")
    private var stream: SCStream?
    private var frameCount: Int = 0
    private var didLogFirstFrame = false
    private var captureSize: CGSize = .zero
    private var didLogContentRect = false
    private var useContentRect = true

    init(renderer: MetalRenderer,
         statusHandler: @escaping (String) -> Void,
         logHandler: @escaping (String) -> Void,
         frameInfoHandler: @escaping (CGSize, CGSize, CGSize) -> Void) {
        self.renderer = renderer
        self.statusHandler = statusHandler
        self.logHandler = logHandler
        self.frameInfoHandler = frameInfoHandler
    }

    func start(displayID: CGDirectDisplayID) async throws {
        let shareable = try await SCShareableContent.current
        guard let display = shareable.displays.first(where: { $0.displayID == displayID }) else {
            let list = shareable.displays.map {
                "Display \($0.displayID) \($0.width)x\($0.height)"
            }
            let joined = list.isEmpty ? "No shareable displays" : list.joined(separator: " | ")
            statusHandler("Display \(displayID) not found. Shareable: \(joined)")
            return
        }

        logHandler("SCDisplay \(display.displayID) \(display.width)x\(display.height)")
        NSLog("Capture start display=%u size=%dx%d", display.displayID, display.width, display.height)
        captureSize = CGSize(width: display.width, height: display.height)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = false
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true

        if let mode = CGDisplayCopyDisplayMode(displayID) {
            configuration.width = mode.pixelWidth
            configuration.height = mode.pixelHeight
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await stream.startCapture()
        self.stream = stream
        frameCount = 0
        didLogFirstFrame = false
        didLogContentRect = false
        renderer.resetFrameCounter()
        statusHandler("Capture started")
    }

    func stop() async {
        guard let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            statusHandler("Stop capture error: \(error.localizedDescription)")
        }
        self.stream = nil
        statusHandler("Capture stopped")
    }

    func updateUseContentRect(_ enabled: Bool) {
        outputQueue.async { [weak self] in
            self?.useContentRect = enabled
            if let logHandler = self?.logHandler {
                logHandler("Content crop enabled: \(enabled)")
                NSLog("Content crop enabled: %d", enabled ? 1 : 0)
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let bufferSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                                height: CVPixelBufferGetHeight(pixelBuffer))
        let info = contentRectInfo(for: sampleBuffer, bufferSize: bufferSize)
        let normalizedRect: CGRect
        if useContentRect, let info {
            normalizedRect = info.normalized
        } else {
            normalizedRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        renderer.render(pixelBuffer: pixelBuffer, contentRect: normalizedRect)
        updateContentRect(info: info)
        frameCount += 1
        if !didLogFirstFrame {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            didLogFirstFrame = true
            logHandler("First frame \(width)x\(height)")
            NSLog("First frame %dx%d", width, height)
            let contentSize = info?.rectPixels.size ?? CGSize(width: width, height: height)
            frameInfoHandler(captureSize, CGSize(width: width, height: height), contentSize)
        } else if frameCount % 120 == 0 {
            logHandler("Frame \(frameCount)")
            NSLog("Frame %d", frameCount)
        }
    }

    private func updateContentRect(info: ContentRectInfo?) {
        guard !didLogContentRect, let info else { return }
        didLogContentRect = true
        let log = String(format: "Content rect: %.1fx%.1f %.1fx%.1f (mode=%@ scale=%.3f c=%.3f sf=%.3f) norm %.3f,%.3f %.3f,%.3f",
                         info.rectPixels.origin.x,
                         info.rectPixels.origin.y,
                         info.rectPixels.size.width,
                         info.rectPixels.size.height,
                         info.scaleMode,
                         info.scale,
                         info.contentScale,
                         info.scaleFactor,
                         info.normalized.origin.x,
                         info.normalized.origin.y,
                         info.normalized.size.width,
                         info.normalized.size.height)
        logHandler(log)
        NSLog("%@", log)
    }

    private struct ContentRectInfo {
        let normalized: CGRect
        let rectPixels: CGRect
        let scaleMode: String
        let contentScale: CGFloat
        let scaleFactor: CGFloat
        let scale: CGFloat
    }

    private func contentRectInfo(for sampleBuffer: CMSampleBuffer, bufferSize: CGSize) -> ContentRectInfo? {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                             createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let contentRectDict = attachments[.contentRect] as? NSDictionary,
              let contentRect = CGRect(dictionaryRepresentation: contentRectDict),
              bufferSize.width > 0,
              bufferSize.height > 0 else {
            return nil
        }

        let scaleInfo = contentScaleInfo(for: sampleBuffer)
        let scaleFactor = scaleInfo.scaleFactor
        let scale: CGFloat = scaleFactor > 0 ? scaleFactor : 1.0
        let mode = scale == 1.0 ? "raw" : "scaleFactor"

        let rectPixels = CGRect(x: contentRect.origin.x * scale,
                                y: contentRect.origin.y * scale,
                                width: contentRect.size.width * scale,
                                height: contentRect.size.height * scale)

        let normalized = CGRect(x: rectPixels.origin.x / bufferSize.width,
                                y: rectPixels.origin.y / bufferSize.height,
                                width: rectPixels.size.width / bufferSize.width,
                                height: rectPixels.size.height / bufferSize.height)

        return ContentRectInfo(normalized: normalized,
                               rectPixels: rectPixels,
                               scaleMode: mode,
                               contentScale: scaleInfo.contentScale,
                               scaleFactor: scaleInfo.scaleFactor,
                               scale: scale)
    }

    private func contentScaleInfo(for sampleBuffer: CMSampleBuffer) -> (contentScale: CGFloat, scaleFactor: CGFloat) {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                             createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first else {
            return (1.0, 1.0)
        }

        let contentScale = attachments[.contentScale] as? CGFloat ?? 1.0
        let scaleFactor = attachments[.scaleFactor] as? CGFloat ?? 1.0
        return (contentScale, scaleFactor)
    }
}
