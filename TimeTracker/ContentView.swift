//
//  ContentView.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 26/03/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Get the shared ViewModel from the environment
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.modelContext) private var modelContext // Inject ModelContext
    
    // Use @Query to fetch WorkSession data, sorted by endTime descending
    @Query(sort: \WorkSession.endTime, order: .reverse) private var workSessions: [WorkSession]
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer Display - Reads from ViewModel
            Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .padding(.vertical)
            
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
                    timerViewModel.stopTimer(context: modelContext)
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
                        // Use ViewModel's sessions and formatters
                        ForEach(workSessions) { session in
                            HStack {
                                Text(timerViewModel.formatTime(session.duration))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(session.startTime, formatter: timerViewModel.timeOnlyFormatter) - \(session.endTime, formatter: timerViewModel.timeOnlyFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteSession) // Call ViewModel
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                }
            }
            
            Spacer()
        }
        .padding()
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
    
}

#Preview {
    ContentView()
        .environmentObject(TimerViewModel())
        .modelContainer(for: WorkSession.self, inMemory: true) // Use in-memory for preview
        .frame(width: 400, height: 400)
}
