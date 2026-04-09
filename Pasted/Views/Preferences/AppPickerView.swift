import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Sheet that lets the user pick an application to exclude from clipboard capture.
/// Shows currently running apps and offers a "Browse Applications..." button for
/// apps not currently running.
struct AppPickerView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called when the user selects an app. Parameters: bundleID, displayName, iconData (32x32 PNG).
    let onSelect: (String, String, Data?) -> Void

    @State private var runningApps: [(bundleID: String, name: String, icon: NSImage?)] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("Select Application")
                .font(.headline)
                .padding()

            Divider()

            if runningApps.isEmpty {
                Text("No running applications found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runningApps, id: \.bundleID) { app in
                    Button {
                        selectApp(bundleID: app.bundleID, name: app.name, icon: app.icon)
                    } label: {
                        HStack(spacing: 10) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .fontWeight(.medium)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button("Browse Applications...") {
                    browseApplications()
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            loadRunningApps()
        }
    }

    // MARK: - Running Apps

    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        runningApps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return (bundleID: bundleID, name: name, icon: app.icon)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Browse

    private func browseApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select an application to exclude from clipboard capture."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: url.path)

        selectApp(bundleID: bundleID, name: name, icon: icon)
    }

    // MARK: - Selection

    private func selectApp(bundleID: String, name: String, icon: NSImage?) {
        let iconData = icon.flatMap { resizeIconToPNG($0, size: 32) }
        onSelect(bundleID, name, iconData)
        dismiss()
    }

    // MARK: - Icon Helpers

    /// Resizes an NSImage to the target size and returns PNG data.
    private func resizeIconToPNG(_ image: NSImage, size: CGFloat) -> Data? {
        let targetSize = NSSize(width: size, height: size)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData
    }
}
