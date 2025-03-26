//
//  TimerViewModel.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import Combine

// Enum to represent the timer's state
enum TimerState: String {
    case stopped = "Stopped"
    case running = "Running"
    case paused = "Paused"
}

// Struct to hold recorded work sessions
struct WorkSession: Identifiable, Hashable, Codable {
    let id: UUID
    let duration: TimeInterval
    let endTime: Date
    
    init(duration: TimeInterval, endTime: Date) {
        self.id = UUID() // Generate a NEW ID only when creating a session this way
        self.duration = duration
        self.endTime = endTime
    }
    
    // Define the keys used for encoding/decoding (optional but good practice)
    private enum CodingKeys: String, CodingKey {
        case id, duration, endTime
    }
    
    // Explicit Initializer required by Decodable
    // This is called when creating a WorkSession FROM encoded data (e.g., JSON)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode each property from the container using the defined keys
        // This correctly assigns the DECODED id to the let constant.
        self.id = try container.decode(UUID.self, forKey: .id)
        self.duration = try container.decode(TimeInterval.self, forKey: .duration)
        self.endTime = try container.decode(Date.self, forKey: .endTime)
    }
    
    // Swift can synthesize the `encode(to:)` method automatically
    // because all properties conform to Codable and we defined CodingKeys (or if names match).
    // No need to write `encode(to:)` unless customization is needed.
}

// ObservableObject to manage the timer state and logic
class TimerViewModel: ObservableObject {
    @Published var timerState: TimerState = .stopped
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var workSessions: [WorkSession] = [] // Consider using @AppStorage later for persistence
    
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
    
    init() {
        // In a real app, we might load saved workSessions here
        // For now, it starts empty
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
    
    func stopTimer() {
        guard timerState != .stopped else { return }
        
        let finalTime: TimeInterval
        if timerState == .running, let startTime = startTime {
            finalTime = accumulatedTimeBeforePause + Date().timeIntervalSince(startTime)
        } else { // Paused state
            finalTime = accumulatedTimeBeforePause
        }
        
        stopTimerInternal() // Stop timer mechanism, clear state
        
        if finalTime > 0.1 {
            let newSession = WorkSession(duration: finalTime, endTime: Date())
            // Insert at the beginning to show newest first
            workSessions.insert(newSession, at: 0) // Update published property
        }
        
        // Reset visual timer immediately after stopping
        elapsedTime = 0.0
        accumulatedTimeBeforePause = 0.0
        // state is already set to stopped in stopTimerInternal
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
    
    func deleteSession(at offsets: IndexSet) {
        workSessions.remove(atOffsets: offsets) // Update published property
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        return timeFormatter.string(from: interval) ?? "00:00:00"
    }
    
    deinit {
        // Ensure timer is invalidated when the ViewModel is deallocated
        timer?.invalidate()
    }
}
