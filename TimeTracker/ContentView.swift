//
//  ContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \WorkSession.endTime, order: .reverse) private var workSessions: [WorkSession]
    @Query(sort: \Project.name) private var projects: [Project]
    
    @State private var sessionToEdit: WorkSession? = nil
    @State private var showingAddProjectSheet = false
    
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
                        // Optional: try? modelContext.save() if explicit save desired
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
                if workSessions.isEmpty { // Read ViewModel
                    Text("No sessions recorded yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    List {
                        ForEach(workSessions) { session in
                            HStack {
                                Text(session.project?.name ?? "No Project")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 80, alignment: .leading) // Give it some space
                                    .lineLimit(1)
                                
                                Divider().frame(height: 15)
                                
                                Text(timerViewModel.formatTime(session.duration))
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                Text("\(session.startTime, formatter: Formatters.timeOnlyFormatter) - \(session.endTime, formatter: Formatters.timeOnlyFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contextMenu {
                                Button("Edit Session") {
                                    sessionToEdit = session
                                }
                                Button("Delete Session", role: .destructive) {
                                    deleteSession(session)
                                }
                            }
                        }
                        .onDelete(perform: deleteSession)
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(item: $sessionToEdit) { session in
            // Pass the selected session to the editing view
            // The environment objects/values (like modelContext) are inherited automatically
            EditSessionView(session: session)
        }
        .sheet(isPresented: $showingAddProjectSheet) {
            AddProjectView()
            // Pass the model context if needed inside AddProjectView
            // .environment(\.modelContext, modelContext)
        }
        // No need for onDisappear cleanup here anymore, ViewModel handles timer lifecycle
    }
    
    // Function within the View to handle deletion using the ModelContext
    private func deleteSession(at offsets: IndexSet) {
        withAnimation {
            offsets.map { workSessions[$0] }.forEach(modelContext.delete)
            // Might want error handling around save if needed,
            // but often it's automatic.
            // try? modelContext.save()
        }
    }
    
    private func deleteSession(_ session: WorkSession) {
        withAnimation {
            modelContext.delete(session)
            // try? modelContext.save()
        }
    }
}

struct AddProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var projectName: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Add New Project")
                .font(.title2)
            
            TextField("Project Name", text: $projectName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    saveProject()
                    dismiss()
                }
                .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 350)
    }
    
    private func saveProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let newProject = Project(name: trimmedName)
        modelContext.insert(newProject)
        // Optional: try? modelContext.save() for explicit save/error handling
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkSession.self, Project.self, configurations: config) // Add Project
        
        // Add sample projects for the picker
        let project1 = Project(name: "Client A")
        let project2 = Project(name: "Internal Tool")
        container.mainContext.insert(project1)
        container.mainContext.insert(project2)
        
        // Add a sample session (optional, can be linked to a project)
        let sampleSession = WorkSession(startTime: Date().addingTimeInterval(-3600), endTime: Date(), project: project1)
        container.mainContext.insert(sampleSession)
        
        let previewViewModel = TimerViewModel()
        
        
        return ContentView()
            .environmentObject(previewViewModel)
            .modelContainer(container) // Use the container with sample data
            .frame(width: 500, height: 500) // Wider frame for project column
    } catch {
        fatalError("Failed to create model container for preview: \(error)")
    }
}
