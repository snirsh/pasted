import SwiftUI
import SwiftData

/// Privacy preferences tab: manage excluded apps, concealed content detection, and history deletion.
struct PrivacyPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("concealedDetectionEnabled") private var concealedDetectionEnabled = true

    @State private var exclusions: [AppExclusion] = []
    @State private var showingAppPicker = false
    @State private var showingClearConfirmation = false

    private var exclusionService: AppExclusionService {
        AppExclusionService(modelContext: modelContext)
    }

    var body: some View {
        Form {
            // MARK: - Excluded Apps

            Section("Excluded Apps") {
                if exclusions.isEmpty {
                    Text("No excluded apps.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(exclusions, id: \.id) { exclusion in
                            HStack(spacing: 10) {
                                // App icon (32x32)
                                if let iconData = exclusion.iconData,
                                   let nsImage = NSImage(data: iconData) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: "app.fill")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(exclusion.displayName)
                                            .fontWeight(.medium)
                                        if exclusion.isDefault {
                                            Text("Default")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.quaternary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(exclusion.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    removeExclusion(exclusion)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove exclusion")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 240)
                }

                Button("Add App...") {
                    showingAppPicker = true
                }
            }

            // MARK: - Concealed Content

            Section("Concealed Content") {
                Toggle("Detect concealed content", isOn: $concealedDetectionEnabled)
                Text("When enabled, clipboard entries marked as sensitive by password managers are automatically skipped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - History

            Section("History") {
                Button("Clear All History...", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 450)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView { bundleID, displayName, iconData in
                addExclusion(bundleID: bundleID, displayName: displayName, iconData: iconData)
            }
        }
        .alert("Clear All History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text("This will permanently delete all clipboard history. This action cannot be undone.")
        }
        .onAppear {
            loadExclusions()
        }
    }

    // MARK: - Actions

    private func loadExclusions() {
        exclusions = (try? exclusionService.fetchAll()) ?? []
    }

    private func addExclusion(bundleID: String, displayName: String, iconData: Data?) {
        try? exclusionService.add(bundleID: bundleID, displayName: displayName, iconData: iconData)
        loadExclusions()
    }

    private func removeExclusion(_ exclusion: AppExclusion) {
        try? exclusionService.remove(exclusion)
        loadExclusions()
    }

    private func clearAllHistory() {
        let store = ClipboardStore(modelContext: modelContext)
        try? store.deleteAll()
    }
}
