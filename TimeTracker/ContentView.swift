//
//  ContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI

struct ContentView: View {
    // Get the shared ViewModel from the environment
    @EnvironmentObject var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer Display - Reads from ViewModel
            Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .padding(.vertical)
            
            // Control Buttons - Call ViewModel methods
            HStack(spacing: 15) {
                Button {
                    timerViewModel.startTimer() // Call ViewModel
                } label: {
                    Text(timerViewModel.timerState == .paused ? "Resume" : "Start")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(timerViewModel.timerState == .running) // Read ViewModel state
                .keyboardShortcut(.defaultAction)
                
                Button("Pause") {
                    timerViewModel.pauseTimer() // Call ViewModel
                }
                .buttonStyle(.bordered)
                .disabled(timerViewModel.timerState != .running) // Read ViewModel state
                .keyboardShortcut("p", modifiers: .command)
                
                Button("Stop") {
                    timerViewModel.stopTimer() // Call ViewModel
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(timerViewModel.timerState == .stopped) // Read ViewModel state
                .keyboardShortcut(".", modifiers: .command)
            }
            .controlSize(.large)
            
            Divider()
            
            // Work History List - Reads from ViewModel
            VStack(alignment: .leading) {
                Text("Work History")
                    .font(.headline)
                if timerViewModel.workSessions.isEmpty { // Read ViewModel
                    Text("No sessions recorded yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    List {
                        // Use ViewModel's sessions and formatters
                        ForEach(timerViewModel.workSessions) { session in
                            HStack {
                                Text(timerViewModel.formatTime(session.duration))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("Stopped: \(session.endTime, formatter: timerViewModel.dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: timerViewModel.deleteSession) // Call ViewModel
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                }
            }
            
            Spacer()
        }
        .padding()
        // No need for onDisappear cleanup here anymore, ViewModel handles timer lifecycle
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerViewModel()) // Inject a sample ViewModel
        .frame(width: 400, height: 400)
}
