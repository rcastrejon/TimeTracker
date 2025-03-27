//
//  WorkSession.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import Foundation
import SwiftData

@Model
final class WorkSession {
    var id: UUID
    var startTime: Date
    var endTime: Date
    
    var project: Project?
    
    var duration: TimeInterval {
        max(0, endTime.timeIntervalSince(startTime))
    }
    
    init(startTime: Date, endTime: Date, project: Project? = nil) {
        guard startTime <= endTime else {
            print("Warning: Attempted to create WorkSession with startTime after endTime. Adjusting.")
            self.id = UUID()
            self.startTime = endTime
            self.endTime = endTime
            self.project = project // Assign project even in warning case
            return
        }
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.project = project // Assign the project
    }
    
    // Convenience init matching the old structure (calculates startTime from duration)
    // Useful for existing code like stopTimer that provides duration and endTime.
    convenience init(duration: TimeInterval, endTime: Date, project: Project? = nil) {
        let calculatedStartTime = endTime.addingTimeInterval(-max(0, duration))
        self.init(startTime: calculatedStartTime, endTime: endTime, project: project)
    }
}
