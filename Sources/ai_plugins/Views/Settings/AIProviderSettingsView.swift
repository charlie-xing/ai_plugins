import SwiftUI
import AppKit

struct AIProviderSettingsView: View {
    @ObservedObject var settings: AppSettings

    @State private var selectedProviderType: ProviderType = .openai
    @State private var providerName: String = ""
    @State private var apiEndpoint: String = ""
    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    @State private var showingAddProvider = false

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Add New Provider Section
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("add_provider", bundle: .module, comment: ""))
                        .font(.headline)

                    // Provider Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("ai_provider", bundle: .module, comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker(NSLocalizedString("ai_provider", bundle: .module, comment: ""), selection: $selectedProviderType) {
                            ForEach(ProviderType.allCases) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedProviderType) { newType in
                            apiEndpoint = newType.defaultEndpoint
                            providerName = newType.rawValue
                        }
                    }

                    // Provider Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("provider_name", bundle: .module, comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("e.g., My OpenAI", text: $providerName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // API Endpoint
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("api_endpoint", bundle: .module, comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("https://api.example.com/v1", text: $apiEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    // API Key
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("api_key", bundle: .module, comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Test Result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            switch result {
                            case .success(let message):
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            case .failure(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: testConnection) {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text(NSLocalizedString("test_connection", bundle: .module, comment: ""))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .disabled(apiEndpoint.isEmpty || apiKey.isEmpty || isTestingConnection)

                        Button(action: saveProvider) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text(NSLocalizedString("save", bundle: .module, comment: ""))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(providerName.isEmpty || apiEndpoint.isEmpty || apiKey.isEmpty)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Configured Providers List
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("configured_providers", bundle: .module, comment: ""))
                        .font(.headline)

                    if settings.aiProviders.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(NSLocalizedString("no_providers", bundle: .module, comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(settings.aiProviders) { provider in
                                ProviderRow(
                                    provider: provider,
                                    isActive: provider.id == settings.activeProviderId,
                                    onActivate: {
                                        activateProvider(provider)
                                    },
                                    onDelete: {
                                        deleteProvider(provider)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !selectedProviderType.defaultEndpoint.isEmpty {
                apiEndpoint = selectedProviderType.defaultEndpoint
                providerName = selectedProviderType.rawValue
            }
            // Update window title to show current context
            WindowTitleManager.shared.setSettingsTitle("ai_provider")
        }
    }

    // MARK: - Actions

    private func testConnection() {
        isTestingConnection = true
        testResult = nil

        Task {
            let result = await AIProviderService.testConnection(
                endpoint: apiEndpoint,
                apiKey: apiKey
            )

            await MainActor.run {
                isTestingConnection = false
                switch result {
                case .success(let message):
                    testResult = .success(message)
                case .failure(let error):
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func saveProvider() {
        let newProvider = AIProvider(
            name: providerName,
            providerType: selectedProviderType,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            isActive: settings.aiProviders.isEmpty, // First provider is active by default
            isConnected: testResult != nil
        )

        settings.aiProviders.append(newProvider)

        // Set as active if it's the first one
        if settings.activeProviderId == nil {
            settings.activeProviderId = newProvider.id
        }

        settings.saveProviders()

        // Reset form
        resetForm()
        testResult = .success("Provider saved successfully!")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testResult = nil
        }
    }

    private func activateProvider(_ provider: AIProvider) {
        settings.activeProviderId = provider.id
        settings.saveProviders()
    }

    private func deleteProvider(_ provider: AIProvider) {
        settings.aiProviders.removeAll { $0.id == provider.id }
        if settings.activeProviderId == provider.id {
            settings.activeProviderId = settings.aiProviders.first?.id
        }
        settings.saveProviders()
    }

    private func resetForm() {
        providerName = selectedProviderType.rawValue
        apiEndpoint = selectedProviderType.defaultEndpoint
        apiKey = ""
    }
}

// MARK: - Provider Row Component

struct ProviderRow: View {
    let provider: AIProvider
    let isActive: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Provider Icon
            Image(systemName: provider.providerType.icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            // Provider Info
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 14, weight: .medium))

                Text(provider.apiEndpoint)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status Badge
            if isActive {
                Text(NSLocalizedString("active", bundle: .module, comment: ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(6)
            } else {
                Button(action: onActivate) {
                    Text(NSLocalizedString("activate", bundle: .module, comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("delete_provider", bundle: .module, comment: ""))
        }
        .padding(12)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
