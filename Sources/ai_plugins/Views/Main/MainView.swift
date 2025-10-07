import SwiftUI

struct MainView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var viewModel: MainViewModel
    @State private var selectedTab: SidebarSection = .plugins
    @State private var selectedSettingsSection: SettingsSection = .aiProvider

    init() {
        let settings = AppSettings()
        self._settings = StateObject(wrappedValue: settings)
        self._viewModel = StateObject(wrappedValue: MainViewModel(settings: settings))
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // User Profile Section
                UserProfileView(settings: settings)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

                Divider()

                // Tab Selector
                HStack(spacing: 0) {
                    ForEach(SidebarSection.allCases) { section in
                        Button(action: {
                            selectedTab = section
                            // 切换到非 plugins 标签时清空选中的插件
                            if section != .plugins {
                                viewModel.selectedPlugin = nil
                            }
                        }) {
                            ZStack {
                                // Background layer (full clickable area)
                                Rectangle()
                                    .fill(selectedTab == section ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                // Icon layer
                                Image(systemName: section.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(selectedTab == section ? .accentColor : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .fill(selectedTab == section ? Color.accentColor : Color.clear)
                                    .frame(height: 2.5),
                                alignment: .bottom
                            )
                        }
                        .buttonStyle(.plain)
                        .help(section.localizedName)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

                Divider()

                // Tab Content
                Group {
                    switch selectedTab {
                    case .plugins:
                        pluginListContent
                    case .history:
                        historyContent
                    case .settings:
                        settingsContent
                    }
                }

                Divider()

                // Theme toggle at bottom
                Button(action: {
                    settings.isDarkMode.toggle()
                    updateAppearance()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: settings.isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 14))
                        Text(settings.isDarkMode ? NSLocalizedString("light_mode", bundle: .module, comment: "") : NSLocalizedString("dark_mode", bundle: .module, comment: ""))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .help(settings.isDarkMode ? NSLocalizedString("switch_to_light", bundle: .module, comment: "") : NSLocalizedString("switch_to_dark", bundle: .module, comment: ""))
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            .onAppear {
                viewModel.loadPlugins()
                updateAppearance()
            }
        } detail: {
            detailView
        }
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
    }

    @ViewBuilder
    private var pluginListContent: some View {
        VStack(spacing: 0) {
            // Search box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField(NSLocalizedString("search_plugins", bundle: .module, comment: ""), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.updateFilteredPlugins()
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.updateFilteredPlugins()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Plugin list
            if viewModel.plugins.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.searchText.isEmpty ? "puzzlepiece.extension" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(viewModel.searchText.isEmpty ? NSLocalizedString("no_plugins", bundle: .module, comment: "") : NSLocalizedString("no_matching_plugins", bundle: .module, comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.plugins) { plugin in
                            Button(action: {
                                viewModel.openTab(for: plugin)
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: getPluginIcon(for: plugin.mode))
                                        .font(.system(size: 13))
                                        .foregroundColor(.accentColor)
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plugin.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(plugin.description)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(viewModel.activeTab?.plugin.id == plugin.id ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(NSLocalizedString("no_history", bundle: .module, comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var settingsContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    Button(action: {
                        selectedSettingsSection = section
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                                .frame(width: 20)

                            Text(NSLocalizedString(section.localizedNameKey, bundle: .module, comment: ""))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedSettingsSection == section {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedSettingsSection == section ?
                                Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            Spacer()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        // The detail view logic
        switch selectedTab {
        case .settings:
            settingsDetailView
        case .history:
            VStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(NSLocalizedString("no_history", bundle: .module, comment: ""))
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .plugins:
            if !viewModel.openTabs.isEmpty {
                // If there are open tabs, show the PluginDetailView which contains the tab bar
                PluginDetailView(viewModel: viewModel)
            } else {
                // If no plugins are open, show a placeholder
                VStack(spacing: 16) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(NSLocalizedString("select_plugin", bundle: .module, comment: ""))
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func getPluginIcon(for mode: PluginMode) -> String {
        switch mode {
        case .chat:
            return "bubble.left.and.bubble.right.fill"
        case .bot:
            return "gearshape.2.fill"
        case .agent:
            return "person.crop.circle.fill.badge.checkmark"
        case .role:
            return "theatermasks.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    @ViewBuilder
    private var settingsDetailView: some View {
        switch selectedSettingsSection {
        case .aiProvider:
            AIProviderSettingsView(settings: settings)
        case .inputMethod:
            InputMethodSettingsView(settings: settings)
        case .modelSelection:
            ModelSelectionView(settings: settings)
        }
    }

    private func updateAppearance() {
        NSApp.appearance = settings.isDarkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
    }
}