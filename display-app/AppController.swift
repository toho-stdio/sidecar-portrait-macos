//
//  AppController.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import AppKit
import Combine

@MainActor
final class AppController: ObservableObject {
    @Published var statusText: String = "Idle"
    @Published var debugText: String = ""
    @Published var logText: String = ""
    @Published var sidecarDisplayName: String = "Not detected"
    @Published var virtualDisplayName: String = "Not detected"
    @Published var rotationEnabled: Bool = true
    @Published var fillModeEnabled: Bool = true
    @Published var autoRotationEnabled: Bool = false
    @Published var rotationClockwise: Bool = true
    @Published var useContentRectEnabled: Bool = true
    @Published var testPatternEnabled: Bool = false
    @Published var debugOverlayEnabled: Bool = false

    private var didStart = false
    private let renderer = MetalRenderer()
    private let virtualDisplayManager = VirtualDisplayManager()
    private var virtualDisplayInfo: VirtualDisplayInfo?
    private var captureController: CaptureController?
    private var sidecarWindowController: SidecarWindowController?
    private var displaySnapshot: DisplaySelection?
    private var logLines: [String] = []

    init() {
        UserDefaults.standard.register(defaults: [
            "vdPortrait": true,
            "vdFrameRate": 60.0,
            "vdHiDPI": true,
            "vdName": "Virtual Portrait",
            "vdPPI": 264,
            "vdMirror": false
        ])
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillTerminate),
                                               name: NSApplication.willTerminateNotification,
                                               object: nil)
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        start()
    }

    func refreshDisplays() {
        debugText = DisplaySelector.debugSummary()
        let report = DisplaySelector.selectionReport()
        displaySnapshot = report.selection
        sidecarDisplayName = report.sidecar?.name ?? "Not detected"
        virtualDisplayName = report.virtual?.name ?? "Not detected"
        if let reason = report.reason {
            statusText = "Displays refreshed: \(reason)"
        } else {
            statusText = "Displays refreshed"
        }
        appendLog("Display selection: sidecar=\(sidecarDisplayName), virtual=\(virtualDisplayName)")
    }

    func restartCapture() {
        Task {
            await stopCapture()
            start()
        }
    }

    private func start() {
        updateRendererSettings()
        // createVirtualDisplayIfNeeded()
        refreshDisplays()
        startCaptureSession()
    }

    func createMatchingVirtualDisplay() {
        let report = DisplaySelector.selectionReport()
        guard let sidecar = report.sidecar else {
            statusText = "Sidecar display not found"
            return
        }
        
        createVirtualDisplay(width: UInt(sidecar.size.width), height: UInt(sidecar.size.height))
    }

    func rotateVirtualDisplay() {
        // If we have a virtual display, use its dimensions
        if let current = virtualDisplayManager.currentDisplay {
            createVirtualDisplay(width: current.height, height: current.width)
            return
        }
        
        // Fallback: If no virtual display exists, try to match Sidecar but rotated
        let report = DisplaySelector.selectionReport()
        if let sidecar = report.sidecar {
            createVirtualDisplay(width: UInt(sidecar.size.height), height: UInt(sidecar.size.width))
        } else {
            statusText = "No display to rotate"
        }
    }

    private func createVirtualDisplay(width: UInt, height: UInt) {
        if let current = virtualDisplayManager.currentDisplay {
            _ = virtualDisplayManager.destroyDisplay()
        }
        
        do {
            let info = try virtualDisplayManager.createDisplay(withWidth: width,
                                                               height: height,
                                                               frameRate: 60,
                                                               hiDPI: true,
                                                               name: "Virtual Sidecar Match",
                                                               ppi: 264,
                                                               mirror: false)
            virtualDisplayInfo = info
            UserDefaults.standard.set(Int(info.displayID), forKey: "virtualDisplayID")
            statusText = "Created virtual display: \(width)x\(height)"
            appendLog("Created virtual display: \(width)x\(height)")
            refreshDisplays()
            startCaptureSession()
        } catch {
            statusText = "Error creating display: \(error.localizedDescription)"
            appendLog("Error creating display: \(error.localizedDescription)")
        }
    }

    private func startCaptureSession() {
        guard let selection = displaySnapshot else {
            statusText = "No suitable displays found"
            return
        }

        if selection.sidecar.id == selection.virtual.id {
            statusText = "Only one external display detected; treating it as the virtual display"
            return
        }

        guard let sidecarScreen = DisplaySelector.screen(for: selection.sidecar.id) else {
            statusText = "Sidecar screen missing"
            return
        }

        sidecarWindowController = SidecarWindowController(screen: sidecarScreen, renderer: renderer)
        sidecarWindowController?.setDebugOverlay(enabled: debugOverlayEnabled)
        sidecarWindowController?.show()
        sidecarWindowController?.logState()
        appendLog("Sidecar window shown on id \(selection.sidecar.id)")

        if captureController == nil {
            captureController = CaptureController(renderer: renderer,
                                                  statusHandler: { [weak self] message in
                                                      Task { @MainActor in
                                                          self?.statusText = message
                                                      }
                                                  },
                                                  logHandler: { [weak self] message in
                                                      Task { @MainActor in
                                                          self?.appendLog(message)
                                                      }
                                                  },
                                                  frameInfoHandler: { [weak self] captureSize, frameSize, contentSize in
                                                      Task { @MainActor in
                                                          self?.updateRotationForCapture(captureSize: captureSize,
                                                                                          frameSize: frameSize,
                                                                                          contentSize: contentSize)
                                                      }
                                                  })
            captureController?.updateUseContentRect(useContentRectEnabled)
        }

        Task {
            await startCapture(displayID: selection.virtual.id)
        }
    }

    private func startCapture(displayID: CGDirectDisplayID) async {
        if !CGPreflightScreenCaptureAccess() {
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                statusText = "Screen Recording permission denied"
                return
            }
        }

        guard let captureController else {
            statusText = "Capture controller missing"
            return
        }

        do {
            try await captureController.start(displayID: displayID)
            statusText = "Capturing display \(displayID)"
        } catch {
            statusText = "Capture error: \(error.localizedDescription)"
        }
    }

    private func stopCapture() async {
        await captureController?.stop()
        captureController = nil
        statusText = "Capture stopped"
    }

    @objc private func appWillTerminate() {
        _ = virtualDisplayManager.destroyDisplay()
    }

    private func createVirtualDisplayIfNeeded() {
        let defaults = UserDefaults.standard
        let width = defaults.integer(forKey: "vdWidth")
        let height = defaults.integer(forKey: "vdHeight")
        let frameRate = defaults.double(forKey: "vdFrameRate")
        let hiDPI = defaults.object(forKey: "vdHiDPI") as? Bool ?? true
        let name = defaults.string(forKey: "vdName") ?? "Virtual Portrait"
        let ppi = defaults.integer(forKey: "vdPPI")
        let mirror = defaults.object(forKey: "vdMirror") as? Bool ?? false
        let portrait = defaults.object(forKey: "vdPortrait") as? Bool ?? true

        let resolvedWidth: Int
        let resolvedHeight: Int
        if width > 0 && height > 0 {
            resolvedWidth = width
            resolvedHeight = height
        } else if portrait {
            resolvedWidth = 1668
            resolvedHeight = 2388
        } else {
            resolvedWidth = 2388
            resolvedHeight = 1668
        }
        let resolvedRate = frameRate > 0 ? frameRate : 120
        let resolvedPPI = ppi > 0 ? ppi : 264

        if let current = virtualDisplayManager.currentDisplay {
            virtualDisplayInfo = current
            UserDefaults.standard.set(Int(current.displayID), forKey: "virtualDisplayID")
            if current.width == resolvedWidth && current.height == resolvedHeight {
                appendLog("Virtual display already exists (id \(current.displayID))")
                return
            }
            appendLog("Recreating virtual display \(current.width)x\(current.height) -> \(resolvedWidth)x\(resolvedHeight)")
            _ = virtualDisplayManager.destroyDisplay()
        }

        do {
            let info = try virtualDisplayManager.createDisplay(withWidth: UInt(resolvedWidth),
                                                               height: UInt(resolvedHeight),
                                                               frameRate: resolvedRate,
                                                               hiDPI: hiDPI,
                                                               name: name,
                                                               ppi: resolvedPPI,
                                                               mirror: mirror)
            virtualDisplayInfo = info
            UserDefaults.standard.set(Int(info.displayID), forKey: "virtualDisplayID")
            statusText = "Virtual display created (id \(info.displayID))"
            appendLog("Virtual display created: id \(info.displayID) \(info.width)x\(info.height)")
        } catch {
            statusText = "Virtual display error: \(error.localizedDescription)"
            appendLog("Virtual display error: \(error.localizedDescription)")
        }
    }

    func toggleRotation() {
        rotationEnabled.toggle()
        updateRendererSettings()
        appendLog("Rotation enabled: \(rotationEnabled)")
    }

    func toggleRotationDirection() {
        rotationClockwise.toggle()
        updateRendererSettings()
        appendLog("Rotation direction: \(rotationClockwise ? "CW" : "CCW")")
    }

    func toggleFillMode() {
        fillModeEnabled.toggle()
        updateRendererSettings()
        appendLog("Fill mode enabled: \(fillModeEnabled)")
    }

    func toggleAutoRotation() {
        autoRotationEnabled.toggle()
        appendLog("Auto-rotation enabled: \(autoRotationEnabled)")
        updateRendererSettings()
    }

    func toggleContentRect() {
        useContentRectEnabled.toggle()
        captureController?.updateUseContentRect(useContentRectEnabled)
        appendLog("Content crop enabled: \(useContentRectEnabled)")
    }

    func toggleTestPattern() {
        testPatternEnabled.toggle()
        updateRendererSettings()
        appendLog("Test pattern enabled: \(testPatternEnabled)")
    }

    func toggleDebugOverlay() {
        debugOverlayEnabled.toggle()
        sidecarWindowController?.setDebugOverlay(enabled: debugOverlayEnabled)
        appendLog("Debug overlay enabled: \(debugOverlayEnabled)")
    }

    private func updateRendererSettings() {
        let rotation: MetalRenderer.RotationMode
        if rotationEnabled {
            rotation = rotationClockwise ? .cw : .ccw
        } else {
            rotation = .none
        }
        let scale: MetalRenderer.ScaleMode = fillModeEnabled ? .fill : .fit
        let renderMode: MetalRenderer.RenderMode = testPatternEnabled ? .testPattern : .normal
        renderer.update(rotationMode: rotation, scaleMode: scale, renderMode: renderMode)
    }

    private func updateRotationForCapture(captureSize: CGSize, frameSize: CGSize, contentSize: CGSize) {
        guard autoRotationEnabled else {
            appendLog("Auto-rotation disabled by user")
            updateRendererSettings()
            return
        }
        guard captureSize.width > 0, captureSize.height > 0 else { return }
        let capturePortrait = captureSize.height > captureSize.width
        let framePortrait = frameSize.height > frameSize.width
        let contentPortrait = contentSize.height > contentSize.width
        if contentPortrait {
            rotationEnabled = true
            appendLog("Auto-rotation enabled (content is portrait)")
        } else {
            rotationEnabled = false
            appendLog("Auto-rotation disabled (content is landscape)")
        }
        updateRendererSettings()
    }

    private func appendLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logLines.append("[\(timestamp)] \(message)")
        if logLines.count > 80 {
            logLines.removeFirst(logLines.count - 80)
        }
        logText = logLines.joined(separator: "\n")
        NSLog("%@", message)
    }
}
