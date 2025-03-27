//
//  EditSessionView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

struct EditSessionView: View {
    @Environment(\.dismiss) var dismiss
    let session: WorkSession
    
    @State private var editStartTime: Date
    @State private var editEndTime: Date
    
    @State private var isInvalid: Bool = false
    
    // Reuse the formatter for consistency (consider making formatters globally accessible or passing them)
    let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    init(session: WorkSession) {
        self.session = session
        // Initialize the @State variables with the session's current values
        _editStartTime = State(initialValue: session.startTime)
        _editEndTime = State(initialValue: session.endTime)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Work Session")
                .font(.title2)
            
            LabeledPreciseDatePicker(label: "Start Time:", selection: $editStartTime)
            LabeledPreciseDatePicker(label: "End Time:", selection: $editEndTime)
            
            Divider()
            
            HStack {
                Text("Calculated Duration:")
                Spacer()
                Text(formattedDuration(start: editStartTime, end: editEndTime)) // Use state vars
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(isInvalid ? .red : .primary)
            }
            
            // Show validation error message
            if isInvalid {
                Text("Error: Start time must be before end time.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Spacer()
            
            HStack {
                Button("Cancel", role: .cancel) {
                    // Simply dismiss without applying changes
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    // Apply the temporary edits back to the original session object
                    session.startTime = editStartTime
                    session.endTime = editEndTime
                    // SwiftData automatically tracks changes to 'session' now.
                    // No explicit save needed here unless you want finer control/error handling.
                    // try? modelContext.save() // Optional: If explicit saving is desired
                    
                    // Dismiss the sheet after saving
                    dismiss()
                }
                .disabled(isInvalid)
                .keyboardShortcut(.defaultAction) // Make Save default (Enter key)
            }
        }
        .padding()
        .frame(minWidth: 350, idealWidth: 400, minHeight: 250)
        // Validate dates whenever start or end time changes
        .onChange(of: editStartTime) { _, _ in validateDates() }
        .onChange(of: editEndTime) { _, _ in validateDates() }
        // Perform initial validation when the view appears
        .onAppear(perform: validateDates)
    }
    
    /// Validates that the start time is strictly before the end time.
    private func validateDates() {
        isInvalid = editStartTime >= editEndTime
    }
    
    /// Formats the duration based on start and end dates.
    private func formattedDuration(start: Date, end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        // Handle potentially negative duration if dates are invalid during editing
        if duration < 0 {
            return "Invalid"
        }
        return timeFormatter.string(from: duration.rounded()) ?? "Error"
    }
}

#Preview {
    // Create dummy data for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkSession.self, configurations: config)
    let sampleSession = WorkSession(startTime: Date().addingTimeInterval(-3600), endTime: Date())
    container.mainContext.insert(sampleSession)
    
    return EditSessionView(session: sampleSession)
        .padding()
        .frame(width: 400, height: 300)
}
