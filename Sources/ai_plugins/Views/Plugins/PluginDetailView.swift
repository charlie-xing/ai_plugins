import SwiftUI
import AppKit

struct PluginDetailView: View {
    let plugin: Plugin
    @StateObject private var viewModel = PluginViewModel()
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(plugin.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // WebView for output
            WebView(htmlContent: viewModel.webViewContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Input area
            HStack(alignment: .bottom, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    CustomTextEditor(text: $viewModel.prompt) {
                        if !viewModel.prompt.isEmpty {
                            viewModel.runPlugin(plugin: plugin)
                        }
                    }
                    .frame(minHeight: 44, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                    // Placeholder with keyboard shortcut hint
                    if viewModel.prompt.isEmpty {
                        HStack {
                            Text(NSLocalizedString("enter_prompt", comment: ""))
                                .foregroundColor(.secondary.opacity(0.6))
                                .font(.system(size: 14))

                            Spacer()

                            HStack(spacing: 2) {
                                Text("⌘")
                                    .font(.system(size: 12, weight: .medium))
                                Text("↵")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.trailing, 8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                    }
                }

                Button(action: {
                    viewModel.runPlugin(plugin: plugin)
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(viewModel.prompt.isEmpty ? Color.gray : Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.prompt.isEmpty)
                .help(NSLocalizedString("send", comment: "") + " (⌘+Enter)")
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }
}