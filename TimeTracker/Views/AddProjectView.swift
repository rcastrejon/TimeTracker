//
//  AddProjectView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 29/03/25.
//

import SwiftUI
import SwiftData

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
    }
}
