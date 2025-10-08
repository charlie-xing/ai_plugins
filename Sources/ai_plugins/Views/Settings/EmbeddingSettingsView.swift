import SwiftUI

struct EmbeddingSettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var embeddingService = EmbeddingService.shared

    @State private var selectedProvider: EmbeddingProvider = .mock
    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var connectionMessage: String = ""
    @State private var showAPIKeyInput = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("embedding_settings", bundle: .module, comment: ""))
                        .font(.headline)

                    Text(
                        NSLocalizedString(
                            "embedding_settings_description", bundle: .module, comment: "")
                    )
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Provider Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("embedding_provider", bundle: .module, comment: ""))
                        .font(.headline)

                    VStack(spacing: 12) {
                        ForEach(EmbeddingProvider.allCases) { provider in
                            ProviderCard(
                                provider: provider,
                                isSelected: selectedProvider == provider,
                                onSelect: {
                                    selectedProvider = provider
                                    showAPIKeyInput = provider.requiresAPIKey
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // API Configuration
                if showAPIKeyInput {
                    apiConfigurationSection
                }

                // Connection Test
                connectionTestSection

                // Current Status
                currentStatusSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: selectedProvider) { _ in
            saveSettings()
        }
    }

    // MARK: - API Configuration Section

    private var apiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("api_configuration", bundle: .module, comment: ""))
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("api_key", bundle: .module, comment: ""))
                    .font(.system(size: 13, weight: .medium))

                HStack {
                    SecureField(
                        NSLocalizedString("enter_api_key", bundle: .module, comment: ""),
                        text: $apiKey
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                    Button(action: {
                        saveSettings()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if selectedProvider == .openAI || selectedProvider == .openAISmall {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("api_key_info", bundle: .module, comment: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Link(
                            NSLocalizedString("get_openai_key", bundle: .module, comment: ""),
                            destination: URL(string: "https://platform.openai.com/api-keys")!
                        )
                        .font(.system(size: 11))
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Connection Test Section

    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(NSLocalizedString("connection_test", bundle: .module, comment: ""))
                    .font(.headline)

                Spacer()

                Button(action: testConnection) {
                    HStack(spacing: 6) {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "wifi")
                                .font(.system(size: 12))
                        }

                        Text(NSLocalizedString("test_connection", bundle: .module, comment: ""))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(isTestingConnection || !canTestConnection)
            }

            if connectionStatus != .unknown {
                HStack(spacing: 8) {
                    Image(systemName: connectionStatus.icon)
                        .font(.system(size: 14))
                        .foregroundColor(connectionStatus.color)

                    Text(connectionMessage)
                        .font(.system(size: 13))
                        .foregroundColor(connectionStatus.color)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(connectionStatus.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Current Status Section

    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("current_status", bundle: .module, comment: ""))
                .font(.headline)

            VStack(spacing: 12) {
                StatusRow(
                    title: NSLocalizedString("selected_provider", bundle: .module, comment: ""),
                    value: selectedProvider.displayName
                )

                StatusRow(
                    title: NSLocalizedString("vector_dimension", bundle: .module, comment: ""),
                    value: "\(embeddingService.getVectorDimension())"
                )

                if selectedProvider.requiresAPIKey {
                    StatusRow(
                        title: NSLocalizedString("api_key_status", bundle: .module, comment: ""),
                        value: apiKey.isEmpty
                            ? NSLocalizedString("not_configured", bundle: .module, comment: "")
                            : NSLocalizedString("configured", bundle: .module, comment: "")
                    )
                }

                if embeddingService.isProcessing {
                    StatusRow(
                        title: NSLocalizedString("status", bundle: .module, comment: ""),
                        value: NSLocalizedString("processing", bundle: .module, comment: "")
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Helper Properties

    private var canTestConnection: Bool {
        if selectedProvider.requiresAPIKey {
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    // MARK: - Actions

    private func loadCurrentSettings() {
        selectedProvider = embeddingService.currentProvider
        showAPIKeyInput = selectedProvider.requiresAPIKey

        // Load API key from user defaults (in real app, use Keychain)
        if selectedProvider.requiresAPIKey {
            apiKey = UserDefaults.standard.string(forKey: "EmbeddingAPIKey") ?? ""
        }
    }

    private func saveSettings() {
        embeddingService.setProvider(selectedProvider)

        if selectedProvider.requiresAPIKey {
            embeddingService.setAPIKey(apiKey)
        }

        // Reset connection status when settings change
        connectionStatus = .unknown
        connectionMessage = ""
    }

    private func testConnection() {
        isTestingConnection = true
        connectionStatus = .unknown
        connectionMessage = ""

        Task {
            do {
                let success = try await embeddingService.testConnection()

                await MainActor.run {
                    isTestingConnection = false

                    if success {
                        connectionStatus = .success
                        connectionMessage = NSLocalizedString(
                            "connection_successful", bundle: .module, comment: "")
                    } else {
                        connectionStatus = .failure
                        connectionMessage = NSLocalizedString(
                            "connection_failed", bundle: .module, comment: "")
                    }
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    connectionStatus = .failure
                    connectionMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct ProviderCard: View {
    let provider: EmbeddingProvider
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.5))
                    .frame(width: 24, height: 24)

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text(provider.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Requirements badge
                if provider.requiresAPIKey {
                    Text(NSLocalizedString("requires_api_key", bundle: .module, comment: ""))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(12)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types

enum ConnectionStatus {
    case unknown
    case success
    case failure

    var icon: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .unknown:
            return .secondary
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    EmbeddingSettingsView(settings: AppSettings())
}
