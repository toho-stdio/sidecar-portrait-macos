//
//  ContentView.swift
//  display-app
//
//  Created by toho on 31/12/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: AppController
    @State private var isAdvancedExpanded = false
    @State private var step1Completed = false
    @State private var step2Completed = false
    @State private var step3Completed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rotated Sidecar")
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 16) {
                StepButton(
                    title: "Create Virtual Display",
                    subtitle: "Step 1",
                    isCompleted: step1Completed
                ) {
                    controller.createMatchingVirtualDisplay()
                    step1Completed = true
                }
                
                StepButton(
                    title: "Rotate Virtual Display",
                    subtitle: "Step 2",
                    isCompleted: step2Completed
                ) {
                    controller.rotateVirtualDisplay()
                    step2Completed = true
                }
                
                StepButton(
                    title: "Restart Capture",
                    subtitle: "Step 3",
                    isCompleted: step3Completed
                ) {
                    controller.restartCapture()
                    step3Completed = true
                }
                
                StepButton(
                    title: "Hide App",
                    subtitle: "Step 4 (Optional)",
                    isCompleted: false
                ) {
                    controller.hideApp()
                }
            }
            .padding(.vertical, 12)
            
            Spacer()
            
            DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
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
                    }
                    
                    Divider()
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], alignment: .leading) {
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
                    .padding(.top, 4)
                }
            } label: {
                HStack {
                    Text("Advanced")
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        isAdvancedExpanded.toggle()
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 600)
    }
}

struct StepButton: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.green : Color.secondary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

#Preview {
    ContentView()
}
