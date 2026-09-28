import SwiftUI

struct SettingsView: View {
    @AppStorage("distanceUnit") private var unit: DistanceUnit = .meters
    let store: CourseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Distance", selection: $unit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.white)

                Section {
                    LabeledContent("Course", value: store.reference.name)
                    if let fetchedAt = store.course?.fetchedAt {
                        LabeledContent("Updated", value: fetchedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Label("Refresh course data", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isLoading)
                    if let error = store.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Course data")
                } footer: {
                    Text("Hole and green data © OpenStreetMap contributors, available under the Open Database License.")
                }
                .listRowBackground(Color.white)
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
