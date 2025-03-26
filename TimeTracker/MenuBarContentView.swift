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
        Button(viewModel.timerState == .paused ? "Resume" : "Start") {
            viewModel.startTimer()
        }
        .disabled(viewModel.timerState == .running)
        .keyboardShortcut("s", modifiers: [.command, .option]) // Example shortcut
        
        Button("Pause") {
            viewModel.pauseTimer()
        }
        .disabled(viewModel.timerState != .running)
        .keyboardShortcut("p", modifiers: [.command, .option]) // Example shortcut
        
        Button("Stop") {
            viewModel.stopTimer(context: modelContext)
        }
        .disabled(viewModel.timerState == .stopped)
        .keyboardShortcut(".", modifiers: [.command, .option]) // Example shortcut
        
        Divider()
        
        // Option to open the main window
        Button("Open Timer Window") {
            openWindow(id: "main") // Use the ID defined for the Window
        }
        
        Divider()
        
        // Standard Quit Button
        Button("Quit WorkTimer") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
