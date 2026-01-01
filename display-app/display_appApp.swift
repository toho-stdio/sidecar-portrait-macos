//
//  display_appApp.swift
//  display-app
//
//  Created by toho on 31/12/25.
//

import SwiftUI

@main
struct display_appApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .onAppear {
                    controller.startIfNeeded()
                }
        }
    }
}
