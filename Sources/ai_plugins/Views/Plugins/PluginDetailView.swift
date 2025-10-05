import SwiftUI
import AppKit

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
            path.addArc(center: CGPoint(x: topRight.x - radius, y: topRight.y + radius),
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
            path.addArc(center: CGPoint(x: bottomRight.x - radius, y: bottomRight.y - radius),
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
            path.addArc(center: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y - radius),
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
            path.addArc(center: CGPoint(x: topLeft.x + radius, y: topLeft.y + radius),
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
            // Chrome-style tabs
            HStack(spacing: 4) {
                ForEach(viewModel.openTabs) { tab in
                    TabButton(
                        tab: tab,
                        isActive: tab.id == viewModel.activeTabId,
                        onSelect: {
                            print("!!! TAP GESTURE FIRED for \(tab.plugin.name) !!!")
                            viewModel.activeTabId = tab.id
                            viewModel.selectedPlugin = tab.plugin
                            WindowTitleManager.shared.setPluginTitle(tab.plugin.name)
                        },
                        onClose: {
                            print("!!! CLOSE BUTTON FIRED for \(tab.plugin.name) !!!")
                            viewModel.closeTab(tab.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            // WebView area - show content for the active tab
            if let activeTab = viewModel.activeTab {
                TabContentView(tab: activeTab)
            } else {
                // Optional: Show a placeholder if no tab is active for some reason
                Spacer()
            }

            // Shared input area at bottom
            if let activeTab = viewModel.activeTab {
                ExpandableTextInput(
                    text: $sharedPrompt,
                    placeholder: NSLocalizedString("enter_prompt", comment: ""),
                    onSend: {
                        print("PluginDetailView: Send button clicked, prompt: '\(sharedPrompt)'")
                        if !sharedPrompt.isEmpty {
                            print("PluginDetailView: Sending to active tab: \(activeTab.plugin.name)")
                            activeTab.viewModel.prompt = sharedPrompt
                            activeTab.viewModel.runPlugin(plugin: activeTab.plugin)
                            sharedPrompt = ""
                        }
                    }
                )
                .padding(16)
            }
        }
    }
}

/// Content view for a single tab - only contains WebView
struct TabContentView: View {
    @ObservedObject var tab: TabItem

    var body: some View {
        // WebView for output
        WebView(htmlContent: tab.viewModel.webViewContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedCorners(radius: 12, corners: [.topRight, .bottomLeft, .bottomRight])
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onAppear {
                print("TabContentView: Appeared for plugin - \(tab.plugin.name)")
            }
    }
}

/// Tab button component for plugin tabs
struct TabButton: View {
    let tab: TabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHoveringClose = false

    var body: some View {
        HStack(spacing: 8) {
            // Clickable label area (icon + text)
            HStack(spacing: 8) {
                // Plugin icon
                Image(systemName: getPluginIcon(for: tab.plugin.mode))
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? .accentColor : .secondary)

                // Plugin name
                Text(tab.plugin.name)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                print("!!! TAP GESTURE FIRED for \(tab.plugin.name) !!!")
                onSelect()
            }

            // Close button (independent clickable area)
            Button(action: {
                print("!!! CLOSE BUTTON FIRED for \(tab.plugin.name) !!!")
                onClose()
            }) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Tab background with rounded top corners
                RoundedCorners(radius: 10, corners: [.topLeft, .topRight])
                    .fill(isActive ? Color(NSColor.controlBackgroundColor).opacity(0.7) : Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        )
        .overlay(
            RoundedCorners(radius: 10, corners: [.topLeft, .topRight])
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
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