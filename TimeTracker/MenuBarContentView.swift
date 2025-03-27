//
//  MenuBarContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

struct MenuBarContentView: View {
    // Access the shared ViewModel
    @EnvironmentObject var viewModel: TimerViewModel
    // Access the openWindow action from the environment
    @Environment(\.openWindow) var openWindow
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // Display Current Status
        Text("Status: \(viewModel.timerState.rawValue)")
        
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
            viewModel.stopTimer(context: modelContext)
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
            print("MenuBar: Set activation policy to regular (showing Dock icon).")
        }
        
        Divider()
        
        // Standard Quit Button
        Button("Quit WorkTimer") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
