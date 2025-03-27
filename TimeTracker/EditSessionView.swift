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
    @Environment(\.modelContext) private var modelContext
    
    let session: WorkSession
    
    @State private var editStartTime: Date
    @State private var editEndTime: Date
    @State private var editProject: Project?
    @State private var isInvalid: Bool = false
    
    @Query(sort: \Project.name) private var projects: [Project]
    
    init(session: WorkSession) {
        self.session = session
        // Initialize the @State variables with the session's current values
        _editStartTime = State(initialValue: session.startTime)
        _editEndTime = State(initialValue: session.endTime)
        _editProject = State(initialValue: session.project)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Work Session")
                .font(.title2)
            
            LabeledPreciseDatePicker(label: "Start Time:", selection: $editStartTime)
            LabeledPreciseDatePicker(label: "End Time:", selection: $editEndTime)
            
            HStack {
                Text("Project:")
                Picker("Select Project", selection: $editProject) {
                    Text("None").tag(Project?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project))
                    }
                }
                // Maybe add a button to create projects directly from here
                // Button { ... } label: { Image(systemName: "plus.circle.fill") }
            }
            
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
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    // Apply the temporary edits back to the original session object
                    session.startTime = editStartTime
                    session.endTime = editEndTime
                    session.project = editProject
                    // SwiftData automatically tracks changes to 'session' now.
                    // No explicit save needed here unless you want finer control/error handling.
                    // try? modelContext.save() // Optional: If explicit saving is desired
                    
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
        return Formatters.durationFormatter.string(from: duration.rounded()) ?? "Error"
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkSession.self, Project.self, configurations: config)
        
        // Sample projects
        let project1 = Project(name: "Website Redesign")
        let project2 = Project(name: "API Development")
        container.mainContext.insert(project1)
        container.mainContext.insert(project2)
        
        // Sample session linked to project1
        let sampleSession = WorkSession(startTime: Date().addingTimeInterval(-3600), endTime: Date(), project: project1)
        container.mainContext.insert(sampleSession)
        
        return EditSessionView(session: sampleSession)
            .modelContainer(container)
            .padding()
            .frame(width: 400, height: 350)
    } catch {
        fatalError("Failed to create model container for preview: \(error)")
    }
}
