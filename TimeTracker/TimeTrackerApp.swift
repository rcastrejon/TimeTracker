//
//  TimeTrackerApp.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI

@main
struct TimeTrackerApp: App {
    var body: some Scene {
        Window("Work Timer", id: "main") {
            ContentView()
                .frame(minWidth: 400, minHeight: 400)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
