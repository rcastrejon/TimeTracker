//
//  MenuBarContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

struct MenuBarContentView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @Environment(\.openWindow) var openWindow
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Project.name) private var projects: [Project]
    
    var body: some View {
        // Display Current Status & Project
        Text("Status: \(viewModel.timerState.rawValue)")
        Text("Project: \(viewModel.selectedProject?.name ?? "None")")
        
        Divider()
        
        // Control Buttons
        Button(viewModel.timerState == .stopped ? "Start" : "Resume") {
            viewModel.startTimer()
        }
        .disabled(viewModel.timerState == .running)
        .keyboardShortcut("s", modifiers: [.command, .option])
        
        Button("Pause") {
            viewModel.pauseTimer()
        }
        .disabled(viewModel.timerState != .running)
        .keyboardShortcut("p", modifiers: [.command, .option])
        
        Button("Stop") {
            if let sessionData = viewModel.stopTimer() {
                let newSession = WorkSession(duration: sessionData.duration, endTime: sessionData.endTime, project: viewModel.selectedProject)
                modelContext.insert(newSession)
            }
        }
        .disabled(viewModel.timerState == .stopped)
        .keyboardShortcut(".", modifiers: [.command, .option])
        
        Button("Discard") {
            viewModel.discardTimer()
        }
        // Enable if timer is running OR paused (i.e., not stopped)
        .disabled(viewModel.timerState == .stopped)
        .keyboardShortcut(.delete, modifiers: .option)
        
        Divider()
        
        // Option to open the main window
        Button("Open Timer Window") {
            // --- Explicitly show the Dock icon ---
            // Set activation policy to regular BEFORE opening the window
            // to ensure the Dock icon appears.
            NSApplication.shared.setActivationPolicy(.regular)
            
            // Now open the window
            openWindow(id: "main")
            
            // This makes the app (and its newly opened/focused window) active.
            // 'ignoringOtherApps: true' is generally preferred for direct user actions
            // like clicking a button to open something.
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        
        Divider()
        
        // Standard Quit Button
        Button("Quit WorkTimer") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
