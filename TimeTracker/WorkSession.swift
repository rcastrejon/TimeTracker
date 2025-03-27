//
//  WorkSession.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import Foundation
import SwiftData

@Model
final class WorkSession { // Use 'final class' for SwiftData models
    var id: UUID
    var duration: TimeInterval
    var endTime: Date
    
    // Computed property to calculate the start time
    var startTime: Date {
        // Subtract the duration from the end time
        return endTime.addingTimeInterval(-duration)
    }
    
    // Initializer for creating new sessions in code
    init(duration: TimeInterval, endTime: Date) {
        self.id = UUID() // Generate ID when creating programmatically
        self.duration = duration
        self.endTime = endTime
    }
}
