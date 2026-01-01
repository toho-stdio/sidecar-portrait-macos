//
//  ContentView.swift
//  display-app
//
//  Created by toho on 31/12/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rotated Sidecar")
                .font(.title2)
            Text(controller.statusText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(controller.debugText)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                Text(controller.logText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .frame(height: 140)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Sidecar: \(controller.sidecarDisplayName)")
                Text("Virtual: \(controller.virtualDisplayName)")
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            HStack {
                Button("Restart Capture") {
                    controller.restartCapture()
                }
                Button("Refresh Displays") {
                    controller.refreshDisplays()
                }
                Button(controller.rotationEnabled ? "Rotation On" : "Rotation Off") {
                    controller.toggleRotation()
                }
                Button(controller.rotationClockwise ? "Rotate CW" : "Rotate CCW") {
                    controller.toggleRotationDirection()
                }
                Button(controller.fillModeEnabled ? "Fill Mode" : "Fit Mode") {
                    controller.toggleFillMode()
                }
                Button(controller.autoRotationEnabled ? "Auto Rotation" : "Manual Rotation") {
                    controller.toggleAutoRotation()
                }
                Button(controller.useContentRectEnabled ? "Crop On" : "Crop Off") {
                    controller.toggleContentRect()
                }
                Button(controller.testPatternEnabled ? "Pattern On" : "Pattern Off") {
                    controller.toggleTestPattern()
                }
                Button(controller.debugOverlayEnabled ? "Overlay On" : "Overlay Off") {
                    controller.toggleDebugOverlay()
                }
            }
        }
        .padding(16)
        .frame(minWidth: 420)
    }
}

#Preview {
    ContentView()
}
