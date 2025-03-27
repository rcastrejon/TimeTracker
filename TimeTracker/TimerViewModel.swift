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
    @Published var selectedProject: Project? = nil
    
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var accumulatedTimeBeforePause: TimeInterval = 0.0
    
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
    
    func stopTimer() -> (duration: TimeInterval, endTime: Date)? {
        guard timerState != .stopped else { return nil }
        
        let finalEndTime = Date()
        let finalDuration: TimeInterval
        if timerState == .running, let startTime = startTime {
            finalDuration = accumulatedTimeBeforePause + finalEndTime.timeIntervalSince(startTime)
        } else { // Paused state
            finalDuration = accumulatedTimeBeforePause
        }
        
        stopTimerInternal() // Stop timer mechanism, clear state
        
        // Reset visual timer immediately
        elapsedTime = 0.0
        accumulatedTimeBeforePause = 0.0
        
        // Only return data if duration is meaningful
        if finalDuration >= 1.0 {
            return (duration: finalDuration, endTime: finalEndTime)
        } else {
            print("Session too short, not saving.")
            return nil
        }
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
        return Formatters.durationFormatter.string(from: interval.rounded()) ?? "00:00:00"
    }
    
    deinit {
        // Ensure timer is invalidated when the ViewModel is deallocated
        timer?.invalidate()
    }
}
