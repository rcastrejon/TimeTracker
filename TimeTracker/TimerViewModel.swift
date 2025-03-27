//
//  TimerViewModel.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData
import Combine

// Enum to represent the timer's state
enum TimerState: String {
    case stopped = "Stopped"
    case running = "Running"
    case paused = "Paused"
}

// ObservableObject to manage the timer state and logic
class TimerViewModel: ObservableObject {
    @Published var timerState: TimerState = .stopped
    @Published var elapsedTime: TimeInterval = 0.0
    
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var accumulatedTimeBeforePause: TimeInterval = 0.0
    
    let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium 
        return formatter
    }()
    
    func startTimer() {
        guard timerState != .running else { return }
        
        if timerState == .stopped {
            elapsedTime = 0.0
            accumulatedTimeBeforePause = 0.0
        }
        
        startTime = Date()
        timerState = .running // Update published property
        
        timer?.invalidate() // Ensure no previous timer is running
        
        // Schedule timer on the main run loop in common modes
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            // Use DispatchQueue.main.async to ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                self.elapsedTime = self.accumulatedTimeBeforePause + Date().timeIntervalSince(startTime)
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    func pauseTimer() {
        guard timerState == .running, let startTime = startTime else { return }
        
        timer?.invalidate()
        timer = nil
        
        accumulatedTimeBeforePause += Date().timeIntervalSince(startTime)
        // Update elapsedTime precisely on pause
        elapsedTime = accumulatedTimeBeforePause
        
        timerState = .paused // Update published property
        self.startTime = nil
    }
    
    func stopTimer(context: ModelContext) {
        guard timerState != .stopped else { return }
        
        let finalTime: TimeInterval
        if timerState == .running, let startTime = startTime {
            finalTime = accumulatedTimeBeforePause + Date().timeIntervalSince(startTime)
        } else { // Paused state
            finalTime = accumulatedTimeBeforePause
        }
        
        stopTimerInternal() // Stop timer mechanism, clear state
        
        // Only save if duration is meaningful (e.g., more than a fraction of a second)
        // Using 1.0 second threshold, adjust if needed
        if finalTime >= 1.0 {
            let newSession = WorkSession(duration: finalTime, endTime: Date())
            // Insert into the provided context
            context.insert(newSession)
            // SwiftData handles saving automatically in most SwiftUI contexts
            // or could explicitly call try? context.save() if needed.
        } else {
            print("Session too short, not saving.")
        }
        
        // Reset visual timer immediately after stopping
        elapsedTime = 0.0
        accumulatedTimeBeforePause = 0.0
        // state is already set to stopped in stopTimerInternal
    }
    
    func discardTimer() {
        // Only discard if the timer isn't already stopped
        guard timerState != .stopped else { return }
        
        // Reset visual timer and accumulated time immediately
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            self.elapsedTime = 0.0
        }
        self.accumulatedTimeBeforePause = 0.0
        
        // Use the internal helper to stop the timer mechanism and set the state to stopped
        // This avoids saving the session, which stopTimer(context:) does.
        stopTimerInternal()
    }
    
    private func stopTimerInternal() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        // Ensure state is updated on the main thread if called from background later
        DispatchQueue.main.async {
            self.timerState = .stopped // Update published property
        }
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        return timeFormatter.string(from: interval.rounded()) ?? "00:00:00"
    }
    
    deinit {
        // Ensure timer is invalidated when the ViewModel is deallocated
        timer?.invalidate()
    }
}
