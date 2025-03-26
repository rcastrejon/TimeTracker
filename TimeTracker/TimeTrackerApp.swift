//
//  TimeTrackerApp.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

@main
struct WorkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Create a single instance of the ViewModel for the entire app lifecycle
    @StateObject private var timerViewModel = TimerViewModel()
    
    // SwiftData model container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkSession.self, // Register model class
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false) // Set to true for in-memory testing
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        // Main Application Window (can be closed)
        Window("Work Timer", id: "main") {
            ContentView()
                .environmentObject(timerViewModel) // Inject the ViewModel
                .frame(minWidth: 400, minHeight: 400)
        }
        .modelContainer(sharedModelContainer)
        // Prevent creating new windows via the File menu (keeps single main window)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        // Menu Bar Extra Scene
        MenuBarExtra {
            // --- Menu Content ---
            // Instantiate the dedicated view struct
            MenuBarContentView()
                .environmentObject(timerViewModel) // Inject the ViewModel
                .modelContainer(sharedModelContainer)
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
