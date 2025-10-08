import SwiftUI

struct RAGSettingsView: View {
    @ObservedObject private var ragService = RAGService.shared
    @State private var configuration: RAGConfiguration
    @State private var hasChanges = false
    @State private var showingResetConfirmation = false

    init() {
        _configuration = State(initialValue: RAGService.shared.configuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("RAG Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Configure how knowledge base content is retrieved and used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button("Reset") {
                        showingResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasChanges)

                    Button("Save") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Enable/Disable RAG
                    SettingSection(
                        title: "Enable RAG",
                        description: "Use knowledge base content to enhance AI responses"
                    ) {
                        Toggle("Enable RAG", isOn: $configuration.enabled)
                            .toggleStyle(.switch)
                            .onChange(of: configuration.enabled) { _ in
                                hasChanges = true
                            }
                    }

                    if configuration.enabled {
                        // Search Configuration
                        SettingSection(
                            title: "Search Settings",
                            description: "Configure how content is retrieved from knowledge bases"
                        ) {
                            VStack(alignment: .leading, spacing: 16) {
                                // Max Results
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Maximum Results")
                                            .font(.system(size: 13, weight: .medium))
                                        Text("Number of chunks to retrieve")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack {
                                        Slider(
                                            value: Binding(
                                                get: { Double(configuration.maxResults) },
                                                set: {
                                                    configuration.maxResults = Int($0)
                                                    hasChanges = true
                                                }
                                            ),
                                            in: 1...20,
                                            step: 1
                                        )
                                        .frame(width: 120)

                                        Text("\(configuration.maxResults)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider()

                                // Similarity Threshold
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Similarity Threshold")
                                            .font(.system(size: 13, weight: .medium))
                                        Text("Minimum similarity score (0.0 - 1.0)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack {
                                        Slider(
                                            value: Binding(
                                                get: { Double(configuration.similarityThreshold) },
                                                set: {
                                                    configuration.similarityThreshold = Float($0)
                                                    hasChanges = true
                                                }
                                            ),
                                            in: 0.0...1.0,
                                            step: 0.05
                                        )
                                        .frame(width: 120)

                                        Text(
                                            String(
                                                format: "%.2f", configuration.similarityThreshold)
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        // Context Configuration
                        SettingSection(
                            title: "Context Settings",
                            description: "Configure how retrieved content is formatted and used"
                        ) {
                            VStack(alignment: .leading, spacing: 16) {
                                // Max Context Length
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Maximum Context Length")
                                            .font(.system(size: 13, weight: .medium))
                                        Text("Characters limit for context text")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack {
                                        Slider(
                                            value: Binding(
                                                get: { Double(configuration.maxContextLength) },
                                                set: {
                                                    configuration.maxContextLength = Int($0)
                                                    hasChanges = true
                                                }
                                            ),
                                            in: 500...5000,
                                            step: 100
                                        )
                                        .frame(width: 120)

                                        Text("\(configuration.maxContextLength)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider()

                                // Include Metadata
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Include Metadata")
                                            .font(.system(size: 13, weight: .medium))
                                        Text("Show similarity scores in context")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $configuration.includeMetadata)
                                        .toggleStyle(.switch)
                                        .onChange(of: configuration.includeMetadata) { _ in
                                            hasChanges = true
                                        }
                                }
                            }
                        }

                        // Context Template
                        SettingSection(
                            title: "Context Template",
                            description:
                                "Template for formatting retrieved context. Use {context} and {query} placeholders."
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Template:")
                                    .font(.system(size: 13, weight: .medium))

                                TextEditor(text: $configuration.contextTemplate)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(minHeight: 100, maxHeight: 150)
                                    .border(Color.secondary.opacity(0.3), width: 1)
                                    .onChange(of: configuration.contextTemplate) { _ in
                                        hasChanges = true
                                    }

                                Text("Available placeholders: {context}, {query}")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Preview Section
                        if hasChanges {
                            SettingSection(
                                title: "Configuration Preview",
                                description: "Preview of current settings"
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    PreviewRow(
                                        label: "Max Results", value: "\(configuration.maxResults)")
                                    PreviewRow(
                                        label: "Similarity Threshold",
                                        value: String(
                                            format: "%.2f", configuration.similarityThreshold))
                                    PreviewRow(
                                        label: "Max Context Length",
                                        value: "\(configuration.maxContextLength) chars")
                                    PreviewRow(
                                        label: "Include Metadata",
                                        value: configuration.includeMetadata ? "Yes" : "No")
                                }
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadCurrentConfiguration()
        }
        .confirmationDialog(
            "Reset Configuration",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Default", role: .destructive) {
                resetToDefault()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will reset all RAG configuration to default values. This action cannot be undone."
            )
        }
    }

    private func loadCurrentConfiguration() {
        configuration = ragService.configuration
        hasChanges = false
    }

    private func saveConfiguration() {
        ragService.updateConfiguration(configuration)
        hasChanges = false
    }

    private func resetToDefault() {
        configuration = RAGConfiguration()
        hasChanges = true
    }
}

// MARK: - Helper Views

struct SettingSection<Content: View>: View {
    let title: String
    let description: String
    let content: Content

    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            content
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
    }
}

struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct RAGSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        RAGSettingsView()
            .frame(width: 600, height: 700)
    }
}
