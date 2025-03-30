//
//  ContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \WorkSession.endTime, order: .reverse) private var workSessions: [WorkSession]
    @Query(sort: \Project.name) private var projects: [Project]
    
    @State private var sessionToEdit: WorkSession? = nil
    @State private var showingAddProjectSheet = false
    
    @State private var didRestoreProject = false
    
    private var groupedSessions: [(key: Project?, value: [WorkSession])] {
        let dictionary = Dictionary(grouping: workSessions) { $0.project }
        
        let noProjectSessions = dictionary[nil] ?? []
        let projectGroups = dictionary.filter { $0.key != nil }
        
        // Sort project groups using the pre-fetched project order
        let sortedProjectGroups = projectGroups.sorted { group1, group2 in
            guard let p1 = group1.key, let p2 = group2.key else { return false } // Should not happen due to filter
            // Find the index based on the @Query sort order captured in 'projects'
            let idx1 = projects.firstIndex(where: { $0.id == p1.id }) ?? Int.max
            let idx2 = projects.firstIndex(where: { $0.id == p2.id }) ?? Int.max
            return idx1 < idx2
        }
        
        // Combine sorted projects and the "No Project" group (always shown last)
        var result = sortedProjectGroups
        result.append((key: nil, value: noProjectSessions)) // Append "No Project" group
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer Display - Reads from ViewModel
            Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .padding(.vertical)
            
            HStack {
                Text("Project:")
                Picker("Select Project", selection: $timerViewModel.selectedProject) {
                    Text("None").tag(Project?.none) // Option for no project
                    ForEach(projects) { project in
                        // Use .tag(Optional(project)) for optional binding
                        Text(project.name).tag(Optional(project))
                    }
                }
                Button {
                    showingAddProjectSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain) // Use plain style for icon button
                .help("Add New Project")
            }
            .padding(.horizontal)
            
            // Control Buttons - Call ViewModel methods
            HStack(spacing: 15) {
                Button {
                    timerViewModel.startTimer()
                } label: {
                    Text(timerViewModel.timerState == .stopped ? "Start" : "Resume")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(timerViewModel.timerState == .running) // Read ViewModel state
                .keyboardShortcut(.defaultAction)
                
                Button("Pause") {
                    timerViewModel.pauseTimer() // Call ViewModel
                }
                .buttonStyle(.bordered)
                .disabled(timerViewModel.timerState != .running) // Read ViewModel state
                .keyboardShortcut("p", modifiers: .command)
                
                Button("Stop") {
                    if let sessionData = timerViewModel.stopTimer() {
                        let newSession = WorkSession(duration: sessionData.duration, endTime: sessionData.endTime, project: timerViewModel.selectedProject)
                        modelContext.insert(newSession)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(timerViewModel.timerState == .stopped) // Read ViewModel state
                .keyboardShortcut(".", modifiers: .command)
                
                Button("Discard") {
                    timerViewModel.discardTimer()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                // Enable if timer is running OR paused (i.e., not stopped)
                .disabled(timerViewModel.timerState == .stopped)
                .keyboardShortcut(.delete)
            }
            .controlSize(.large)
            
            Divider()
            
            // Work History List - Reads from ViewModel
            VStack(alignment: .leading) {
                Text("Work History")
                    .font(.headline)
                    .padding(.horizontal)
                
                if !workSessions.isEmpty {
                    List {
                        // Use ForEach directly with groupedSessions
                        ForEach(groupedSessions, id: \.key?.id) { group in
                            ProjectDisclosureGroup(
                                project: group.key,
                                sessions: group.value, // Pass the value directly
                                sessionToEdit: $sessionToEdit,
                                deleteAction: deleteSession
                            )
                            .environment(\.modelContext, modelContext)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    
                } else {
                    // Displayed when workSessions is empty
                    Text("No sessions recorded yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .alert("Session Not Saved", isPresented: $timerViewModel.showShortSessionAlert) {
            Button("OK") {}
        } message: {
            Text("The work session was less than 1 second long and was not saved.")
        }
        .sheet(item: $sessionToEdit) { session in
            EditSessionView(session: session)
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showingAddProjectSheet) {
            AddProjectView()
                .environment(\.modelContext, modelContext)
        }
        .onAppear {
            guard !didRestoreProject else { return }
            timerViewModel.restoreSelectedProject(context: modelContext)
            didRestoreProject = true
        }
    }
    
    private func deleteSession(_ session: WorkSession) {
        withAnimation {
            modelContext.delete(session)
        }
    }
    
    private func deleteSession(at offsets: IndexSet, in group: [WorkSession]) {
        withAnimation {
            offsets.map { group[$0] }.forEach(modelContext.delete)
        }
    }
}

struct ProjectDisclosureGroup: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project?
    let sessions: [WorkSession]
    @Binding var sessionToEdit: WorkSession?
    let deleteAction: (WorkSession) -> Void
    
    @State private var isExpanded: Bool = true
    @State private var isDropTargeted: Bool = false
    
    private var totalDuration: TimeInterval {
        // Use Project's calculation if available, otherwise sum manually for "No Project"
        project?.totalDuration ?? sessions.reduce(0) { $0 + $1.duration }
    }
    
    private var projectName: String {
        project?.name ?? "No Project"
    }
    
    private var isNoProjectAndEmpty: Bool {
        project == nil && sessions.isEmpty
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if sessions.isEmpty {
                Text("No sessions in this project.")
                    .foregroundColor(.secondary)
                    .padding(.leading, 15)
                    .padding(.vertical, 4)
            } else {
                ForEach(sessions) { session in
                    WorkSessionRow(
                        session: session
                    )
                    .draggable(WorkSessionTransferable(id: session.persistentModelID))
                    .contextMenu {
                        Button("Edit Session") {
                            sessionToEdit = session
                        }
                        Button("Delete Session", role: .destructive) {
                            deleteAction(session)
                        }
                    }
                }
                // Apply onDelete directly to ForEach if needed for swipe-to-delete (iOS style)
                // .onDelete { offsets in deleteSession(at: offsets, in: sessions) }
            }
            
        } label: {
            HStack {
                Text(projectName)
                    .fontWeight(.semibold)
                    .foregroundStyle(isNoProjectAndEmpty ? .secondary : .primary)
                Spacer()
                if project != nil {
                    Text(Formatters.durationFormatter.string(from: totalDuration) ?? "0:00:00")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle()) // Ensure the whole label area is tappable
            .dropDestination(for: WorkSessionTransferable.self) { items, location in
                // Handle the drop
                guard let item = items.first else { return false }
                moveSession(item.id, to: project)
                return true // Indicate success
            } isTargeted: { isTargeted in
                self.isDropTargeted = isTargeted
            }
            .background(isDropTargeted ? Color.blue.opacity(0.1) : Color.clear)
            .animation(.easeInOut(duration: 0.1), value: isDropTargeted)
            
        }
        .padding(.horizontal)
    }
    
    // Function to handle moving the session
    private func moveSession(_ sessionID: PersistentIdentifier, to targetProject: Project?) {
        // Fetch the session using its PersistentIdentifier
        guard let sessionToMove = modelContext.model(for: sessionID) as? WorkSession else {
            print("Error: Could not find session with ID \(sessionID) to move.")
            return
        }
        
        // Avoid unnecessary updates if dropped onto the same project group
        guard sessionToMove.project?.persistentModelID != targetProject?.persistentModelID else {
            print("Session already belongs to this project group.")
            return
        }
        
        sessionToMove.project = targetProject
    }
}

struct WorkSessionRow: View {
    let session: WorkSession
    
    var body: some View {
        HStack {
            Text(Formatters.durationFormatter.string(from: session.duration) ?? "0:00:00")
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            Text("\(session.startTime, formatter: Formatters.timeOnlyFormatter) - \(session.endTime, formatter: Formatters.timeOnlyFormatter)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkSession.self, Project.self, configurations: config)
        
        // Add sample projects
        let project1 = Project(name: "Client A")
        let project2 = Project(name: "Internal Tool")
        container.mainContext.insert(project1)
        container.mainContext.insert(project2)
        
        // Add sample sessions
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600), project: project1)) // P1 - 1 hr
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-3000), endTime: Date().addingTimeInterval(-1200), project: project1)) // P1 - 30 min
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-5000), endTime: Date().addingTimeInterval(-4000), project: project2)) // P2 - ~16 min
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-900), endTime: Date().addingTimeInterval(-300)))      // No Project - 10 min
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-10000), endTime: Date().addingTimeInterval(-9500), project: project1)) // P1 - ~8 min
        
        
        let previewViewModel = TimerViewModel()
        
        
        return ContentView()
            .environmentObject(previewViewModel)
            .modelContainer(container)
            .frame(width: 500, height: 600)
    } catch {
        fatalError("Failed to create model container for preview: \(error)")
    }
}
