//
//  Project.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 27/03/25.
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    // Relationship: One Project has many WorkSessions
    // deleteRule: .nullify means if a project is deleted,
    //             the 'project' property of its sessions becomes nil.
    // inverse: Tells SwiftData how this relationship connects back
    //          from the WorkSession model.
    @Relationship(deleteRule: .nullify, inverse: \WorkSession.project)
    var sessions: [WorkSession]? // Use optional array for relationship

    /// Calculates the total duration of all associated work sessions.
    var totalDuration: TimeInterval {
        // Use compactMap to safely unwrap sessions and sum durations
        (sessions ?? []).reduce(0) { $0 + $1.duration }
    }

    init(name: String = "", createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.sessions = [] // Initialize as empty array
    }
}
