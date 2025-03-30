//
//  TimerViewModel.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

// Enum to represent the timer's state
enum TimerState: String {
    case stopped = "Stopped"
    case running = "Running"
    case paused = "Paused"
}

@Observable @MainActor
final class TimerViewModel {
    private static let minimumSessionDuration: TimeInterval = 1.0
    
    var showShortSessionAlert = false
    var timerState: TimerState = .stopped
    var elapsedTime: TimeInterval = 0.0
    var selectedProject: Project? = nil {
        didSet {
            saveLastSelectedProjectID()
        }
    }
    
    private var timerTask: Task<Void, Error>? = nil
    private var startTime: Date? = nil
    private var accumulatedTimeBeforePause: TimeInterval = 0.0
    private var lastSelectedProjectID: UUID? = nil
    
    init() {
        loadLastSelectedProjectID()
    }
    
    private func loadLastSelectedProjectID() {
        guard let uuidString = UserDefaults.standard.string(forKey: UserDefaults.Keys.lastSelectedProjectID) else {
            return
        }
        self.lastSelectedProjectID = UUID(uuidString: uuidString)
    }
    
    private func saveLastSelectedProjectID() {
        if let projectID = selectedProject?.id {
            UserDefaults.standard.set(projectID.uuidString, forKey: UserDefaults.Keys.lastSelectedProjectID)
        } else {
            // If 'None' is selected, remove the key
            UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
        }
    }
    
    /// Attempts to restore the selected project using the ID loaded from UserDefaults.
    /// Call this method once the ModelContext is available (e.g., in a View's onAppear).
    func restoreSelectedProject(context: ModelContext) {
        guard let projectID = self.lastSelectedProjectID else {
            selectedProject = nil // Ensure consistency if no ID is stored
            return
        }
        
        // Prevent re-fetching if already set
        guard selectedProject?.id != projectID else {
            return
        }
        
        // Fetch the project corresponding to the stored ID
        let fetchDescriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectID }
        )
        
        do {
            let projects = try context.fetch(fetchDescriptor)
            if let projectToRestore = projects.first {
                self.selectedProject = projectToRestore
            } else {
                // If the project ID is invalid (project deleted?), clear the stored setting.
                print("Warning: Could not find project with stored ID \(projectID). Clearing selection.")
                clearLastSelectedProject()
            }
        } catch {
            print("Error fetching project to restore: \(error)")
            clearLastSelectedProject()
        }
    }
    
    private func clearLastSelectedProject() {
        UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
        self.lastSelectedProjectID = nil
        self.selectedProject = nil
    }
    
    func startTimer() {
        guard timerState != .running else { return }
        
        timerTask?.cancel()
        
        if timerState == .stopped {
            elapsedTime = 0.0
            accumulatedTimeBeforePause = 0.0
        }
        
        startTime = Date.now
        timerState = .running
        
        // Start a new Task for the timer loop
        timerTask = Task {
            while !Task.isCancelled {
                // Calculate elapsed time directly within the loop
                // Ensure startTime is captured safely if accessed across await points
                if let currentStartTime = self.startTime {
                    // Update elapsedTime on the main actor
                    self.elapsedTime = self.accumulatedTimeBeforePause + Date.now.timeIntervalSince(currentStartTime)
                }
                
                // Sleep for 1 second (nanoseconds)
                try await Task.sleep(for: .seconds(1))
            }
            // Task cleanup happens implicitly on cancellation or completion
            // Or explicitly in stop/discard methods
        }
    }
    
    func pauseTimer() {
        guard timerState == .running, let currentStartTime = startTime else { return }
        
        timerTask?.cancel()
        timerTask = nil
        
        // Calculate accumulated time precisely at the moment of pause
        accumulatedTimeBeforePause += Date.now.timeIntervalSince(currentStartTime)
        elapsedTime = accumulatedTimeBeforePause // Update display
        
        timerState = .paused
        self.startTime = nil // Clear start time as it's no longer relevant for paused state
    }
    
    /// Stops the timer and returns session data if the duration is sufficient.
    /// - Returns: A tuple containing the final duration and end time, or nil if the session was too short or timer wasn't running/paused.
    func stopTimer() -> (duration: TimeInterval, endTime: Date)? {
        guard timerState != .stopped else { return nil }
        
        let finalEndTime = Date.now
        let finalDuration: TimeInterval
        
        if timerState == .running, let currentStartTime = startTime {
            // Calculate final duration if it was running
            finalDuration = accumulatedTimeBeforePause + finalEndTime.timeIntervalSince(currentStartTime)
        } else { // Paused state
            finalDuration = accumulatedTimeBeforePause
        }
        
        resetTimerState()
        
        if finalDuration >= TimerViewModel.minimumSessionDuration {
            return (duration: finalDuration, endTime: finalEndTime)
        } else {
            self.showShortSessionAlert = true
            return nil
        }
    }
    
    /// Discards the current timer progress without saving a session.
    func discardTimer() {
        guard timerState != .stopped else { return }
        resetTimerState()
    }
    
    /// Resets the timer's internal state and cancels any active task.
    private func resetTimerState() {
        timerTask?.cancel()
        timerTask = nil
        startTime = nil
        elapsedTime = 0.0
        accumulatedTimeBeforePause = 0.0
        timerState = .stopped
    }
    
    /// Formats a time interval into a string (HH:MM:SS).
    func formatTime(_ interval: TimeInterval) -> String {
        // Ensure non-negative interval for formatter
        let nonNegativeInterval = max(0, interval)
        return Formatters.durationFormatter.string(from: nonNegativeInterval.rounded()) ?? "00:00:00"
    }
}
