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

    var duration: TimeInterval {
        max(0, endTime.timeIntervalSince(startTime))
    }

    init(startTime: Date, endTime: Date) {
        // Ensure startTime is before endTime during initialization if possible,
        // although validation during editing is more critical.
        guard startTime <= endTime else {
            print("Warning: Attempted to create WorkSession with startTime after endTime. Adjusting.")
            self.id = UUID()
            self.startTime = endTime
            self.endTime = endTime
            return
        }
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
    }

    // Convenience init matching the old structure (calculates startTime from duration)
    // Useful for existing code like stopTimer that provides duration and endTime.
    convenience init(duration: TimeInterval, endTime: Date) {
        let calculatedStartTime = endTime.addingTimeInterval(-max(0, duration))
        self.init(startTime: calculatedStartTime, endTime: endTime)
    }
}
