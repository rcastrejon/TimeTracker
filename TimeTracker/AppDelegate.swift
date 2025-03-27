//
//  AppDelegate.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application did finish launching.")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        print("AppDelegate: applicationShouldTerminateAfterLastWindowClosed called.")
        // --- Check current policy before setting ---
        // Only change to .accessory if we are currently .regular (or something else)
        if sender.activationPolicy() != .accessory {
            sender.setActivationPolicy(.accessory)
            print("AppDelegate: Set activation policy to accessory (hiding Dock icon).")
        } else {
            // Policy is already .accessory, no need to set it again.
            print("AppDelegate: Policy already .accessory. No change needed.")
        }
        return false
    }
}
