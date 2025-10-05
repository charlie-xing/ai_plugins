import SwiftUI
import AppKit

struct ModelSelectionView: View {
    @ObservedObject var settings: AppSettings

    @State private var isFetchingModels = false
    @State private var fetchError: String?

    var activeProvider: AIProvider? {
        settings.aiProviders.first { $0.id == settings.activeProviderId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Active Provider Info
                if let provider = activeProvider {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("current_provider", comment: ""))
                            .font(.headline)

                        HStack(spacing: 12) {
                            Image(systemName: provider.providerType.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .frame(width: 40, height: 40)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(provider.apiEndpoint)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: fetchModels) {
                                HStack(spacing: 6) {
                                    if isFetchingModels {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                    }
                                    Text(NSLocalizedString("refresh", comment: ""))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isFetchingModels)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)

                    // Error Display
                    if let error = fetchError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Available Models List
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(NSLocalizedString("available_models", comment: ""))
                                .font(.headline)

                            Spacer()

                            Text("\(settings.availableModels.count) \(NSLocalizedString("models_count", comment: ""))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        if settings.availableModels.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "cpu")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(NSLocalizedString("no_models", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(NSLocalizedString("refresh_models_hint", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(settings.availableModels) { model in
                                    ModelRow(
                                        model: model,
                                        isSelected: model.id == settings.selectedModelId,
                                        onSelect: {
                                            selectModel(model)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)

                } else {
                    // No Active Provider
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(NSLocalizedString("no_active_provider", comment: ""))
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("configure_provider_first", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Auto-fetch models if we have a provider but no models
            if activeProvider != nil && settings.availableModels.isEmpty {
                fetchModels()
            }
            // Update window title to show current context
            WindowTitleManager.shared.setSettingsTitle("model_selection")
        }
    }

    // MARK: - Actions

    private func fetchModels() {
        guard let provider = activeProvider else { return }

        isFetchingModels = true
        fetchError = nil

        Task {
            let result = await AIProviderService.fetchModels(
                endpoint: provider.apiEndpoint,
                apiKey: provider.apiKey
            )

            await MainActor.run {
                isFetchingModels = false

                switch result {
                case .success(let modelIds):
                    // Convert model IDs to ModelInfo objects
                    settings.availableModels = modelIds.map { modelId in
                        ModelInfo(
                            id: modelId,
                            name: modelId,
                            providerId: provider.id,
                            description: nil,
                            contextWindow: nil,
                            isDefault: false
                        )
                    }

                    // Auto-select first model if none selected
                    if settings.selectedModelId == nil, let firstModel = settings.availableModels.first {
                        settings.selectedModelId = firstModel.id
                    }

                    settings.saveModels()

                case .failure(let error):
                    fetchError = error.localizedDescription
                }
            }
        }
    }

    private func selectModel(_ model: ModelInfo) {
        settings.selectedModelId = model.id
        settings.saveModels()
    }
}

// MARK: - Model Row Component

struct ModelRow: View {
    let model: ModelInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Model Icon
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.5))
                    .frame(width: 24, height: 24)

                // Model Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    if let description = model.description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let contextWindow = model.contextWindow {
                        Text("Context: \(contextWindow) tokens")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }

                Spacer()

                // Selected Badge
                if isSelected {
                    Text(NSLocalizedString("selected", comment: ""))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
