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
    @Published var selectedProject: Project? = nil {
        // Use didSet to automatically save when the property changes
        didSet {
            saveLastSelectedProjectID()
        }
    }
    
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var accumulatedTimeBeforePause: TimeInterval = 0.0
    
    private var lastSelectedProjectID: UUID? = nil
    private var cancellables = Set<AnyCancellable>() // To hold the Combine subscriber
    
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
                // Use DispatchQueue.main.async to ensure UI updates are on the main thread
                DispatchQueue.main.async {
                    self.selectedProject = projectToRestore
                    print("Successfully restored project: \(projectToRestore.name)")
                }
                
            } else {
                print("Project with ID \(projectID) not found in database. Clearing saved ID.")
                // The saved project no longer exists, clear the UserDefaults entry
                UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
                self.lastSelectedProjectID = nil // Clear the temporary ID as well
                DispatchQueue.main.async {
                    self.selectedProject = nil // Ensure UI reflects 'None' if project not found
                }
            }
        } catch {
            print("Error fetching project to restore: \(error)")
            // Optionally clear the saved ID on error as well
            UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.lastSelectedProjectID)
            self.lastSelectedProjectID = nil
            DispatchQueue.main.async {
                self.selectedProject = nil
            }
        }
    }
    
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
