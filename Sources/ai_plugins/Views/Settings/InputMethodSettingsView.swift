import SwiftUI

struct InputMethodSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Local Model Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("local_model", comment: ""))
                        .font(.headline)

                    // Local Model URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("model_url", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("e.g., /path/to/model", text: $settings.inputMethodSettings.localModelURL)
                                .textFieldStyle(.roundedBorder)

                            Button(action: selectModelFile) {
                                Image(systemName: "folder")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.bordered)
                            .help(NSLocalizedString("browse_file", comment: ""))
                        }

                        Text(NSLocalizedString("model_path_hint", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Model Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("model_name", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("e.g., gpt-3.5-turbo", text: $settings.inputMethodSettings.modelName)
                            .textFieldStyle(.roundedBorder)

                        Text(NSLocalizedString("model_identifier", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Input Parameters
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("input_parameters", comment: ""))
                        .font(.headline)

                    // Input Interval
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("input_interval", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(settings.inputMethodSettings.inputInterval) ms")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.inputMethodSettings.inputInterval) },
                                set: { settings.inputMethodSettings.inputInterval = Int($0) }
                            ),
                            in: 100...2000,
                            step: 100
                        )
                        .accentColor(.accentColor)

                        HStack {
                            Text("100 ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2000 ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(NSLocalizedString("interval_hint", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Appearance Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("appearance", comment: ""))
                        .font(.headline)

                    // Skin Theme
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("skin_theme", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker(NSLocalizedString("skin_theme", comment: ""), selection: $settings.inputMethodSettings.skinTheme) {
                            ForEach(SkinTheme.allCases, id: \.self) { theme in
                                HStack {
                                    Image(systemName: theme.icon)
                                    Text(theme.displayName)
                                }
                                .tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(NSLocalizedString("theme_hint", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(NSLocalizedString("reset_defaults", comment: ""))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)

                    Button(action: saveSettings) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text(NSLocalizedString("save_settings", comment: ""))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Actions

    private func selectModelFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Model File"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            settings.inputMethodSettings.localModelURL = url.path
        }
    }

    private func resetToDefaults() {
        settings.inputMethodSettings = InputMethodSettings()
    }

    private func saveSettings() {
        settings.saveInputMethodSettings()
    }
}

// MARK: - SkinTheme Extension

extension SkinTheme {
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }

    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
}
