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
@MainActor
class TimerViewModel: ObservableObject {
    @Published var timerState: TimerState = .stopped
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var selectedProject: Project? = nil {
        // Use didSet to automatically save when the property changes
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
        if let uuidString = UserDefaults.standard.string(forKey: UserDefaults.Keys.lastSelectedProjectID) {
            self.lastSelectedProjectID = UUID(uuidString: uuidString)
            print("Loaded last project ID: \(uuidString)")
        } else {
            self.lastSelectedProjectID = nil
            print("No last project ID found in UserDefaults.")
        }
    }
    
    private func saveLastSelectedProjectID() {
        if let projectID = selectedProject?.id {
            UserDefaults.standard.set(projectID.uuidString, forKey: UserDefaults.Keys.lastSelectedProjectID)
            print("Saved last project ID: \(projectID.uuidString)")
        } else {
            // If 'None' is selected, remove the key
            UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
            print("Removed last project ID from UserDefaults (None selected).")
        }
    }
    
    /// Attempts to restore the selected project using the ID loaded from UserDefaults.
    /// Call this method once the ModelContext is available (e.g., in a View's onAppear).
    func restoreSelectedProject(context: ModelContext) {
        guard let projectID = self.lastSelectedProjectID else {
            print("No project ID to restore.")
            return
        }
        
        // Prevent re-fetching if already set (might happen if onAppear fires multiple times)
        guard selectedProject?.id != projectID else {
            print("Project \(projectID) already selected.")
            return
        }
        
        print("Attempting to restore project with ID: \(projectID)")
        // Fetch the project corresponding to the stored ID
        let fetchDescriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectID }
        )
        
        do {
            let projects = try context.fetch(fetchDescriptor)
            if let projectToRestore = projects.first {
                // No DispatchQueue needed due to @MainActor
                self.selectedProject = projectToRestore
                print("Successfully restored project: \(projectToRestore.name)")
            } else {
                print("Project with ID \(projectID) not found in database. Clearing saved ID.")
                UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
                self.lastSelectedProjectID = nil
                // No DispatchQueue needed due to @MainActor
                self.selectedProject = nil
            }
        } catch {
            print("Error fetching project to restore: \(error)")
            UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
            self.lastSelectedProjectID = nil
            // No DispatchQueue needed due to @MainActor
            self.selectedProject = nil
        }
    }
    
    func startTimer() {
        guard timerState != .running else { return }
        
        timerTask?.cancel()
        
        if timerState == .stopped {
            elapsedTime = 0.0
            accumulatedTimeBeforePause = 0.0
        }
        
        startTime = Date()
        timerState = .running
        
        // Start a new Task for the timer loop
        timerTask = Task {
            while !Task.isCancelled {
                // Calculate elapsed time directly within the loop
                if let currentStartTime = self.startTime {
                    self.elapsedTime = self.accumulatedTimeBeforePause + Date().timeIntervalSince(currentStartTime)
                }
                
                // Sleep for 1 second (nanoseconds)
                // Task.sleep throws CancellationError if cancelled during sleep
                try await Task.sleep(for: .seconds(1))
            }
            // If loop exits due to cancellation, do cleanup if needed (handled by stop/discard)
            print("Timer task loop finished or cancelled.")
        }
    }
    
    func pauseTimer() {
        guard timerState == .running, let currentStartTime = startTime else { return }
        
        timerTask?.cancel()
        timerTask = nil
        
        // Calculate accumulated time precisely at the moment of pause
        accumulatedTimeBeforePause += Date().timeIntervalSince(currentStartTime)
        elapsedTime = accumulatedTimeBeforePause // Update display
        
        timerState = .paused
        self.startTime = nil
    }
    
    func stopTimer() -> (duration: TimeInterval, endTime: Date)? {
        guard timerState != .stopped else { return nil }
        
        let finalEndTime = Date()
        let finalDuration: TimeInterval
        
        if timerState == .running, let currentStartTime = startTime {
            // Calculate final duration if it was running
            finalDuration = accumulatedTimeBeforePause + finalEndTime.timeIntervalSince(currentStartTime)
            // Cancel the task as part of stopping
            timerTask?.cancel()
        } else { // Paused state
            finalDuration = accumulatedTimeBeforePause
            // Task is already cancelled/nil in paused state
        }
        
        stopTimerInternal() // Reset internal state
        
        elapsedTime = 0.0
        accumulatedTimeBeforePause = 0.0
        
        if finalDuration >= 1.0 {
            return (duration: finalDuration, endTime: finalEndTime)
        } else {
            print("Session too short, not saving.")
            return nil
        }
    }
    
    func discardTimer() {
        guard timerState != .stopped else { return }
        
        timerTask?.cancel()
        
        self.elapsedTime = 0.0
        self.accumulatedTimeBeforePause = 0.0
        
        stopTimerInternal() // Reset internal state
    }
    
    private func stopTimerInternal() {
        // Cancel the task explicitly, though pause/stop should already do it
        timerTask?.cancel()
        timerTask = nil
        startTime = nil
        self.timerState = .stopped // Update state (already on main actor)
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        return Formatters.durationFormatter.string(from: interval.rounded()) ?? "00:00:00"
    }
}
