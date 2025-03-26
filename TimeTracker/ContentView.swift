//
//  ContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI

// Enum to represent the timer's state
enum TimerState {
    case stopped
    case running
    case paused
}

// Struct to hold recorded work sessions
struct WorkSession: Identifiable, Hashable {
    let id = UUID()
    let duration: TimeInterval
    let endTime: Date
}

struct ContentView: View {
    @State private var timerState: TimerState = .stopped
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var workSessions: [WorkSession] = []
    
    // Internal timer management
    @State private var timer: Timer? = nil
    @State private var startTime: Date? = nil
    @State private var accumulatedTimeBeforePause: TimeInterval = 0.0
    
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        // Optional: Add fractional seconds if desired
        // formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
        // formatter.maximumUnitCount = 4 // Adjust if adding nanoseconds
        return formatter
    }()
    
    // Formatter for history timestamp
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer Display
            Text(formatTime(elapsedTime))
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .padding(.vertical)
            
            // Control Buttons
            HStack(spacing: 15) {
                // Start / Resume Button
                Button {
                    startTimer()
                } label: {
                    Text(timerState == .paused ? "Resume" : "Start")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(timerState == .running)
                .keyboardShortcut(.defaultAction) // Often Enter/Return
                
                // Pause Button
                Button("Pause") {
                    pauseTimer()
                }
                .buttonStyle(.bordered)
                .disabled(timerState != .running)
                .keyboardShortcut("p", modifiers: .command) // Cmd+P
                
                // Stop Button
                Button("Stop") {
                    stopTimer()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(timerState == .stopped)
                .keyboardShortcut(".", modifiers: .command) // Cmd+. (common stop shortcut)
                
            }
            .controlSize(.large)
            
            Divider()
            
            // Work History List
            VStack(alignment: .leading) {
                Text("Work History")
                    .font(.headline)
                if workSessions.isEmpty {
                    Text("No sessions recorded yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    List {
                        ForEach(workSessions) { session in
                            HStack {
                                Text(formatTime(session.duration))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("Stopped: \(session.endTime, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteSession) // Allow deleting history items
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true)) // Modern list style
                }
            }
            
            
            Spacer() // Pushes content to the top
        }
        .padding()
        .onDisappear {
            // Clean up timer if the view disappears unexpectedly
            stopTimerInternal()
        }
    }
    
    private func startTimer() {
        guard timerState != .running else { return } // Avoid starting if already running
        
        // If resuming from pause, keep accumulated time
        // If starting fresh, reset accumulated time
        if timerState == .stopped {
            elapsedTime = 0.0
            accumulatedTimeBeforePause = 0.0
        }
        
        startTime = Date() // Record the moment we start/resume
        timerState = .running
        
        // Invalidate existing timer just in case (though state guard should prevent overlap)
        timer?.invalidate()
        
        // Create and schedule the timer
        // Use a common mode to ensure it fires even during UI interactions
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let startTime = startTime else { return }
            // Calculate elapsed time since the *last* start/resume, add time before pause
            self.elapsedTime = accumulatedTimeBeforePause + Date().timeIntervalSince(startTime)
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func pauseTimer() {
        guard timerState == .running, let startTime = startTime else { return }
        
        timer?.invalidate() // Stop the timer updates
        timer = nil
        
        // Add the time elapsed *in this run segment* to the accumulated total
        accumulatedTimeBeforePause += Date().timeIntervalSince(startTime)
        // Update elapsedTime one last time to show the precise pause time
        elapsedTime = accumulatedTimeBeforePause
        
        timerState = .paused
        self.startTime = nil // Clear start time as we are now paused
    }
    
    private func stopTimer() {
        guard timerState != .stopped else { return }
        
        let finalTime: TimeInterval
        if timerState == .running, let startTime = startTime {
            // Calculate final time if running
            finalTime = accumulatedTimeBeforePause + Date().timeIntervalSince(startTime)
        } else {
            // If paused, the final time is already stored
            finalTime = accumulatedTimeBeforePause
        }
        
        stopTimerInternal() // Stop timer mechanism, clear state
        
        // Record the session if it has a meaningful duration
        if finalTime > 0.1 { // Avoid recording tiny accidental sessions
            let newSession = WorkSession(duration: finalTime, endTime: Date())
            workSessions.insert(newSession, at: 0) // Add to the beginning of the list
        }
        
        // Reset for the next session
        elapsedTime = 0.0
        accumulatedTimeBeforePause = 0.0
    }
    
    // Internal helper to just stop the timer mechanism and reset state vars
    private func stopTimerInternal() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        timerState = .stopped
        // Keep accumulatedTimeBeforePause until next start, don't reset here
    }
    
    private func deleteSession(at offsets: IndexSet) {
        workSessions.remove(atOffsets: offsets)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        // Ensure we handle potential nil results from the formatter
        return timeFormatter.string(from: interval) ?? "00:00:00"
    }
}

#Preview {
    ContentView()
}
