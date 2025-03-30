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
    @Environment(TimerViewModel.self) private var timerViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \WorkSession.endTime, order: .reverse) private var workSessions: [WorkSession]
    @Query(sort: \Project.name) private var projects: [Project]
    
    @State private var selectedSidebarItem: SidebarItem? = .noProject
    @State private var selectedSessionId: WorkSession.ID? = nil // For potential content list selection
    @State private var sessionToEdit: WorkSession? = nil
    @State private var showingAddProjectSheet = false
    
    @State private var didRestoreProject = false
    
    // Computed property for filtered sessions based on sidebar selection
    private var filteredSessions: [WorkSession] {
        switch selectedSidebarItem {
        case .noProject:
            return workSessions.filter { $0.project == nil } // Show only unassigned sessions
        case .project(let projectId):
            // Show sessions matching the selected project ID
            return workSessions.filter { $0.project?.id == projectId }
        case .none:
            return [] // No selection, show nothing
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                projects: projects,
                selectedItem: $selectedSidebarItem,
                addProjectAction: { showingAddProjectSheet = true }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 400)
            
        } content: {
            SessionListView(
                sessions: filteredSessions,
                selectedSessionId: $selectedSessionId,
                editAction: { session in sessionToEdit = session },
                deleteAction: deleteSession
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            
        } detail: {
            TimerDetailView()
            // Pass necessary environment objects/state down if needed
            // .environment(timerViewModel) // Already available via environment
            // .environment(\.modelContext, modelContext) // Already available
            // Pass projects for the picker
                .environment(\.projectsData, projects)
        }
        .onAppear {
            // Restore last selected project for the timer view model
            guard !didRestoreProject else { return }
            timerViewModel.restoreSelectedProject(context: modelContext)
            didRestoreProject = true
        }
        .sheet(item: $sessionToEdit) { session in
            EditSessionView(session: session)
                .environment(\.modelContext, modelContext)
                .environment(\.projectsData, projects) // Pass projects if Edit view needs them for Picker
        }
        .sheet(isPresented: $showingAddProjectSheet) {
            AddProjectView()
                .environment(\.modelContext, modelContext)
        }
        .alert("Session Not Saved", isPresented: Bindable(timerViewModel).showShortSessionAlert) {
            Button("OK") {}
        } message: {
            Text("The work session was less than 1 second long and was not saved.")
        }
    }
    
    private func deleteSession(_ session: WorkSession) {
        withAnimation {
            modelContext.delete(session)
            // If the deleted session was selected in the content list, clear selection
            if selectedSessionId == session.id {
                selectedSessionId = nil
            }
        }
    }
    
    private func moveSession(_ sessionID: PersistentIdentifier, to targetProject: Project?) {
        guard let sessionToMove = modelContext.model(for: sessionID) as? WorkSession else {
            print("Error: Could not find session with ID \(sessionID) to move.")
            return
        }
        // Avoid unnecessary updates
        guard sessionToMove.project?.persistentModelID != targetProject?.persistentModelID else {
            return
        }
        sessionToMove.project = targetProject
        // Optionally update sidebar selection if moving to a specific project
        if let targetProject {
            selectedSidebarItem = .project(targetProject.id)
        } else {
            selectedSidebarItem = .noProject
        }
    }
}

/// Represents selectable items in the sidebar.
enum SidebarItem: Hashable, Identifiable {
    case noProject
    case project(Project.ID)
    
    var id: String {
        switch self {
        case .noProject: return "noProject"
        case .project(let id): return "project_\(id)"
        }
    }
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    let projects: [Project]
    @Binding var selectedItem: SidebarItem?
    let addProjectAction: () -> Void
    
    // Define drop type
    private let dropTypes: [UTType] = [.workSessionID]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Projects").font(.headline).padding(.horizontal)
            
            List(selection: $selectedItem) {
                // --- Static Items ---
                Label("No Project", systemImage: "folder.badge.questionmark")
                    .tag(SidebarItem.noProject)
                    .dropDestination(for: WorkSessionTransferable.self) { items, _ in
                        handleDrop(items: items, targetProject: nil, targetItem: .noProject)
                    }
                
                // --- Dynamic Project Items ---
                Section("Your Projects") {
                    if projects.isEmpty {
                        Text("No projects yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(projects) { project in
                            Label(project.name, systemImage: "folder")
                                .tag(SidebarItem.project(project.id))
                                .dropDestination(for: WorkSessionTransferable.self) { items, _ in
                                    handleDrop(items: items, targetProject: project, targetItem: .project(project.id))
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar) // Use sidebar list style
            
            Spacer() // Pushes button to bottom
            
            Button {
                addProjectAction()
            } label: {
                Label("Add Project", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .keyboardShortcut("n", modifiers: .command)
        }
        
    }
    
    private func handleDrop(items: [WorkSessionTransferable], targetProject: Project?, targetItem: SidebarItem) -> Bool {
        guard let item = items.first else { return false }
        moveSession(item.id, to: targetProject)
        selectedItem = targetItem // Select the drop target in the sidebar
        return true
    }
    
    // Function to handle moving the session (needs access to modelContext)
    private func moveSession(_ sessionID: PersistentIdentifier, to targetProject: Project?) {
        guard let sessionToMove = modelContext.model(for: sessionID) as? WorkSession else {
            print("Error: Could not find session with ID \(sessionID) to move.")
            return
        }
        // Avoid unnecessary updates
        guard sessionToMove.project?.persistentModelID != targetProject?.persistentModelID else {
            return
        }
        sessionToMove.project = targetProject
    }
}

struct SessionListView: View {
    let sessions: [WorkSession]
    @Binding var selectedSessionId: WorkSession.ID?
    let editAction: (WorkSession) -> Void
    let deleteAction: (WorkSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            // Title could reflect the filter, e.g., based on selectedSidebarItem
            Text("Work Sessions") // Simple title for now
                .font(.headline)
                .padding([.top, .horizontal])
            
            if sessions.isEmpty {
                Text("No sessions found in this project.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedSessionId) {
                    ForEach(sessions) { session in
                        WorkSessionRow(session: session)
                            .tag(session.id) // Make row selectable
                            .draggable(WorkSessionTransferable(id: session.persistentModelID)) // Enable dragging
                            .contextMenu {
                                Button("Edit Session") { editAction(session) }
                                Button("Delete Session", role: .destructive) { deleteAction(session) }
                            }
                        // Optional: Add double-click action
                            .onTapGesture(count: 2) {
                                editAction(session)
                            }
                    }
                    // No onDelete needed here if using context menu
                }
                .listStyle(.inset) // Standard inset list style
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
        // Optional: Maybe background color
        // .background(Color(.controlBackgroundColor))
    }
}

struct TimerDetailView: View {
    @Environment(TimerViewModel.self) private var timerViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.projectsData) private var projects
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer() // Push content towards center vertically
            
            // Timer Display
            Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                .font(.system(size: 34, weight: .light, design: .monospaced)) // Slightly smaller for detail view
                .padding(.vertical)
            
            // Project Picker
            HStack {
                Text("Project:")
                Picker("Select Project", selection: Bindable(timerViewModel).selectedProject) {
                    Text("None").tag(Project?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project))
                    }
                }
                .labelsHidden() // Hide the picker's own label
                .frame(maxWidth: 250) // Limit picker width
            }
            .padding(.horizontal)
            
            
            // Control Buttons using viewThatFits and Grid
            AdaptiveTimerControls()
                .environment(timerViewModel)
                .environment(\.modelContext, modelContext)
            
            
            Spacer() // Push content towards center vertically
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the detail area
        // Optional background
        // .background(Color(.windowBackgroundColor))
    }
}

struct AdaptiveTimerControls: View {
    @Environment(TimerViewModel.self) private var timerViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            // --- Preferred: Horizontal Grid Layout ---
            Grid(horizontalSpacing: 15, verticalSpacing: 10) {
                GridRow {
                    startButton()
                    pauseButton()
                    stopButton()
                    discardButton()
                }
            }
            .controlSize(.large) // Apply control size to the grid
            
            // --- Alternative: Vertical Layout ---
            VStack(spacing: 10) {
                // Arrange buttons vertically if horizontal doesn't fit
                Grid { // Use Grid for alignment even in VStack
                    GridRow { startButton().gridCellColumns(2) } // Span 2 columns
                    GridRow { pauseButton(); stopButton() }
                    GridRow { discardButton().gridCellColumns(2) } // Span 2 columns
                }
            }
            .controlSize(.regular) // Maybe use regular size if vertical
        }
        .frame(maxWidth: 450) // Constrain max width of controls area
    }
    
    @ViewBuilder private func startButton() -> some View {
        Button {
            timerViewModel.startTimer()
        } label: {
            Text(timerViewModel.timerState == .stopped ? "Start" : "Resume")
                .frame(minWidth: 80)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(timerViewModel.timerState == .running)
        .keyboardShortcut(.defaultAction) // Often Spacebar or Enter
    }
    
    @ViewBuilder private func pauseButton() -> some View {
        Button("Pause") {
            timerViewModel.pauseTimer()
        }
        .buttonStyle(.bordered)
        .disabled(timerViewModel.timerState != .running)
        .keyboardShortcut("p", modifiers: .command)
    }
    
    @ViewBuilder private func stopButton() -> some View {
        Button("Stop") {
            if let sessionData = timerViewModel.stopTimer() {
                let newSession = WorkSession(
                    startTime: sessionData.endTime.addingTimeInterval(-sessionData.duration), // Calculate start time
                    endTime: sessionData.endTime,
                    project: timerViewModel.selectedProject
                )
                modelContext.insert(newSession)
            }
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(timerViewModel.timerState == .stopped)
        .keyboardShortcut(".", modifiers: .command)
    }
    
    @ViewBuilder private func discardButton() -> some View {
        Button("Discard") {
            timerViewModel.discardTimer()
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(timerViewModel.timerState == .stopped)
        .keyboardShortcut(.delete)
    }
}

struct WorkSessionRow: View {
    let session: WorkSession
    
    var body: some View {
        HStack {
            // Use project color dot if desired later
            // Circle().fill(session.project?.color ?? .gray).frame(width: 8, height: 8)
            
            Text(Formatters.durationFormatter.string(from: session.duration) ?? "0:00:00")
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(session.startTime, formatter: Formatters.timeOnlyFormatter) - \(session.endTime, formatter: Formatters.timeOnlyFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // Optionally show date if spans multiple days or for clarity
                Text(session.startTime, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

// Helper to pass the projects array down explicitly if needed,
// avoiding repeated @Query definitions in child views.
private struct ProjectsDataKey: EnvironmentKey {
    static let defaultValue: [Project] = []
}

extension EnvironmentValues {
    var projectsData: [Project] {
        get { self[ProjectsDataKey.self] }
        set { self[ProjectsDataKey.self] = newValue }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkSession.self, Project.self, configurations: config)
        
        // Sample Data
        let project1 = Project(name: "Client A")
        let project2 = Project(name: "Internal Tool")
        container.mainContext.insert(project1)
        container.mainContext.insert(project2)
        
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600), project: project1))
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-3000), endTime: Date().addingTimeInterval(-1200), project: project1))
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-5000), endTime: Date().addingTimeInterval(-4000), project: project2))
        container.mainContext.insert(WorkSession(startTime: Date().addingTimeInterval(-900), endTime: Date().addingTimeInterval(-300))) // No Project
        
        let previewViewModel = TimerViewModel()
        // Manually set the last selected project for preview if needed
        // previewViewModel.selectedProject = project1
        
        return ContentView()
            .environment(previewViewModel)
            .modelContainer(container)
            .frame(width: 800, height: 600)
        
    } catch {
        fatalError("Failed to create model container for preview: \(error)")
    }
}
