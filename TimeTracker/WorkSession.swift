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
    
    // Initializer for creating new sessions in code
    init(duration: TimeInterval, endTime: Date) {
        self.id = UUID() // Generate ID when creating programmatically
        self.duration = duration
        self.endTime = endTime
    }
}
