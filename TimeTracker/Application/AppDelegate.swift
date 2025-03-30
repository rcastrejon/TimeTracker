//
//  AppDelegate.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // --- Check current policy before setting ---
        // Only change to .accessory if we are currently .regular (or something else)
        if sender.activationPolicy() != .accessory {
            sender.setActivationPolicy(.accessory)
        }
        return false
    }
}
