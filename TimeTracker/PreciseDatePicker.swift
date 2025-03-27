//
//  PreciseDatePicker.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import AppKit

struct PreciseDatePicker: NSViewRepresentable {
    var label: String
    @Binding var selection: Date
    
    func makeNSView(context: Context) -> NSDatePicker {
        let datePicker = NSDatePicker()
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [
            .yearMonthDay, // Include date elements
            .hourMinuteSecond // Explicitly include hour, minute, AND second
        ]
        datePicker.target = context.coordinator // Set the target for action messages
        datePicker.action = #selector(Coordinator.dateChanged(_:)) // Set the action method
        datePicker.translatesAutoresizingMaskIntoConstraints = false // Important for layout
        return datePicker
    }
    
    // Updates the NSDatePicker when the SwiftUI @Binding changes.
    func updateNSView(_ nsView: NSDatePicker, context: Context) {
        // Avoid feedback loops: only update if the picker's value
        // is significantly different from the binding's value.
        // Using timeIntervalSince1970 avoids potential floating point issues with direct Date comparison.
        if abs(nsView.dateValue.timeIntervalSince1970 - selection.timeIntervalSince1970) > 0.001 {
            nsView.dateValue = selection
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PreciseDatePicker
        
        init(_ datePicker: PreciseDatePicker) {
            self.parent = datePicker
        }
        
        @objc func dateChanged(_ sender: NSDatePicker) {
            // Update the SwiftUI @Binding ($selection) with the new value from the picker.
            parent.selection = sender.dateValue
        }
    }
}

// Helper to integrate the label nicely in SwiftUI (optional but good practice)
struct LabeledPreciseDatePicker: View {
    var label: String
    @Binding var selection: Date
    
    var body: some View {
        HStack {
            Text(label)
            PreciseDatePicker(label: label, selection: $selection)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var previewDate = Date()
        var body: some View {
            VStack {
                LabeledPreciseDatePicker(label: "Precise Date:", selection: $previewDate)
                Text("Selected: \(previewDate, style: .date) \(previewDate, style: .time)")
            }
            .padding()
            .frame(width: 300)
        }
    }
    return PreviewWrapper()
}
