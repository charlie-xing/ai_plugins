import AppKit
import SwiftUI

/// Custom corner options
struct UIRectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// Custom shape for rounded corners on specific corners only
struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        // Start from top left
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: topLeft.x + radius, y: topLeft.y))
        } else {
            path.move(to: topLeft)
        }

        // Top right corner
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: topRight.x - radius, y: topRight.y))
            path.addArc(
                center: CGPoint(x: topRight.x - radius, y: topRight.y + radius),
                radius: radius,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false)
        } else {
            path.addLine(to: topRight)
        }

        // Bottom right corner
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - radius))
            path.addArc(
                center: CGPoint(x: bottomRight.x - radius, y: bottomRight.y - radius),
                radius: radius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false)
        } else {
            path.addLine(to: bottomRight)
        }

        // Bottom left corner
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y))
            path.addArc(
                center: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y - radius),
                radius: radius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false)
        } else {
            path.addLine(to: bottomLeft)
        }

        // Top left corner
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + radius))
            path.addArc(
                center: CGPoint(x: topLeft.x + radius, y: topLeft.y + radius),
                radius: radius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false)
        } else {
            path.addLine(to: topLeft)
        }

        path.closeSubpath()
        return path
    }
}

struct PluginDetailView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var sharedPrompt: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // A GeometryReader is used to calculate the available width for the tabs.
            GeometryReader { geometry in
                let totalTabs = viewModel.openTabs.count
                let horizontalPadding: CGFloat = 16  // Padding on each side
                let tabSpacing: CGFloat = 4  // Spacing between tabs

                // Calculate available width: geometry width minus padding that will be applied
                let availableWidth = geometry.size.width - (horizontalPadding * 2)

                // Calculate total spacing between tabs
                let totalSpacing = totalTabs > 1 ? CGFloat(totalTabs - 1) * tabSpacing : 0

                // Width available for tab content (excluding spacing)
                let widthForTabs = availableWidth - totalSpacing

                // Chrome-style tab width calculation
                let maxTabWidth: CGFloat = 200  // Maximum width for a single tab
                let minTabWidth: CGFloat = 50   // Minimum width (icon + close button only)
                let compactThreshold: CGFloat = 80  // Below this, hide text

                let (tabWidth, showText) = {
                    guard totalTabs > 0 else { return (maxTabWidth, true) }
                    let uniformWidth = widthForTabs / CGFloat(totalTabs)
                    let finalWidth = min(maxTabWidth, max(minTabWidth, uniformWidth))
                    let shouldShowText = finalWidth >= compactThreshold
                    return (finalWidth, shouldShowText)
                }()

                HStack(spacing: tabSpacing) {
                    ForEach(viewModel.openTabs) { tab in
                        TabButton(
                            tab: tab,
                            isActive: tab.id == viewModel.activeTabId,
                            width: tabWidth,
                            showText: showText,
                            onSelect: {
                                viewModel.activeTabId = tab.id
                                viewModel.selectedPlugin = tab.plugin
                                WindowTitleManager.shared.setPluginTitle(tab.plugin.name)
                            },
                            onClose: {
                                viewModel.closeTab(tab.id)
                            }
                        )
                    }
                    Spacer()  // This pushes all the tabs to the left.
                }
                .padding(.bottom, 0)  // Align tabs to bottom of container
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, horizontalPadding)  // Apply padding inside GeometryReader
            }
            .frame(height: 36)  // Reduced height for tighter appearance
            .padding(.top, 4)  // Reduced top padding
            .background(Color(NSColor.windowBackgroundColor))

            // WebView area - show content for the active tab
            if let activeTab = viewModel.activeTab {
                TabContentView(viewModel: activeTab.viewModel)
            } else {
                Spacer()
            }

            // Shared input area at bottom
            if let activeTab = viewModel.activeTab {
                ExpandableTextInput(
                    text: $sharedPrompt,
                    placeholder: NSLocalizedString("enter_prompt", comment: ""),
                    onSend: {
                        print("PluginDetailView: onSend triggered for tab: \(activeTab.id)")
                        if !sharedPrompt.isEmpty {
                            activeTab.viewModel.prompt = sharedPrompt
                            activeTab.viewModel.runPlugin(plugin: activeTab.plugin)
                            sharedPrompt = ""
                        }
                    }
                )
                .id(activeTab.id)  // Force recreation when active tab changes
                .padding(16)
            }
        }
    }
}

/// Content view for a single tab - only contains WebView
struct TabContentView: View {
    @ObservedObject var viewModel: PluginViewModel

    var body: some View {
        // WebView for output
        WebView(htmlContent: viewModel.webViewContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .clipShape(RoundedCorners(radius: 12, corners: [.bottomLeft, .bottomRight]))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.top, 0)  // Negative top padding to overlap with active tab and eliminate border
    }
}

/// Tab button component for plugin tabs
struct TabButton: View {
    let tab: TabItem
    let isActive: Bool
    let width: CGFloat  // The width is now passed in.
    let showText: Bool  // Whether to show text (Chrome-style compact mode)
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHoveringClose = false

    var body: some View {
        HStack(spacing: showText ? 8 : 4) {
            // Clickable label area (icon + text)
            HStack(spacing: 6) {
                Image(systemName: getPluginIcon(for: tab.plugin.mode))
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? .accentColor : .secondary)
                    .frame(width: 16, alignment: .center)

                if showText {
                    Text(tab.plugin.name)
                        .font(.system(size: 12, weight: isActive ? .medium : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            // Close button with hover effect
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(isHoveringClose ? Color.gray.opacity(0.3) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("close_tab", comment: ""))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHoveringClose = hovering
                }
            }
        }
        .frame(width: width)  // Apply the dynamic width.
        .padding(.horizontal, showText ? 12 : 6)  // Less padding in compact mode
        .padding(.top, 6)
        .padding(.bottom, isActive ? 8 : 6)  // Extended bottom padding for active tab to merge with WebView
        .background(
            ZStack {
                RoundedCorners(radius: 10, corners: [.topLeft, .topRight])
                    .fill(
                        isActive
                            ? Color.blue.opacity(0.15)
                            : Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        )
        .shadow(color: isActive ? Color.black.opacity(0.08) : Color.clear, radius: 4, x: 0, y: 1)
        .zIndex(isActive ? 1 : 0)  // Bring active tab to front to overlay WebView border
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
}
