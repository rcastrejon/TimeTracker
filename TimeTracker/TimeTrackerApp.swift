//
//  TimeTrackerApp.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI

@main
struct WorkTimerApp: App {
    // Create a single instance of the ViewModel for the entire app lifecycle
    @StateObject private var timerViewModel = TimerViewModel()
    // No longer need @Environment(\.openWindow) here, it's in MenuBarContentView
    
    var body: some Scene {
        // Main Application Window (can be closed)
        Window("Work Timer", id: "main") {
            ContentView()
                .environmentObject(timerViewModel) // Inject the ViewModel
                .frame(minWidth: 400, minHeight: 400)
        }
        // Prevent creating new windows via the File menu (keeps single main window)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        // Menu Bar Extra Scene
        MenuBarExtra {
            // --- Menu Content ---
            // Instantiate the dedicated view struct
            MenuBarContentView()
                .environmentObject(timerViewModel) // Inject the ViewModel HERE
        } label: {
            // --- Menu Bar Icon/Label ---
            menuBarLabel() // Call the helper for the label
        }
        .menuBarExtraStyle(.menu)
    }
    
    // Helper ViewBuilder for Menu Bar Label
    @ViewBuilder
    private func menuBarLabel() -> some View {
        // Directly use the switch to return the appropriate Image view
        switch timerViewModel.timerState {
        case .stopped:
            Image(systemName: "timer")
        case .running:
            Image(systemName: "pause.circle.fill")
        case .paused:
            Image(systemName: "play.circle.fill")
        }
    }
}
