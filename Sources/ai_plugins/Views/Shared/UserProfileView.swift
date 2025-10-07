import SwiftUI
import AppKit

struct UserProfileView: View {
    @ObservedObject var settings: AppSettings
    @State private var isEditingProfile = false

    private let cropperWindow = ImageCropperWindow()

    var body: some View {
        HStack(spacing: 12) {
            // Avatar on the left with camera button
            ZStack(alignment: .bottomTrailing) {
                if let avatarPath = settings.userAvatarPath.isEmpty ? nil : settings.userAvatarPath,
                   let image = NSImage(contentsOfFile: avatarPath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1.5))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.6))
                        )
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1.5))
                }

                // Camera button
                Button(action: {
                    selectAvatar()
                }) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("change_avatar", bundle: .module, comment: ""))
            }

            // Stats on the right
            VStack(alignment: .leading, spacing: 8) {
                // User name
                if isEditingProfile {
                    TextField(NSLocalizedString("user_name", bundle: .module, comment: ""), text: $settings.userName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit {
                            isEditingProfile = false
                        }
                } else {
                    Text(settings.userName.isEmpty ? NSLocalizedString("guest", bundle: .module, comment: "") : settings.userName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .onTapGesture {
                            isEditingProfile = true
                        }
                }

                // Metrics row
                HStack(spacing: 16) {
                    // Typing speed metric
                    MetricView(
                        icon: "keyboard",
                        value: String(format: "%.0f", settings.userInputStats.averageKeystrokesPerMinute),
                        unit: NSLocalizedString("kpm", bundle: .module, comment: ""),
                        color: .blue
                    )

                    // AI acceptance rate metric
                    MetricView(
                        icon: "sparkles",
                        value: String(format: "%.0f%%", settings.userInputStats.aiAcceptanceRate),
                        unit: "",
                        color: .purple
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func selectAvatar() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = NSLocalizedString("change_avatar", bundle: .module, comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            // Load the image and show cropper
            if let image = NSImage(contentsOf: url) {
                cropperWindow.show(
                    image: image,
                    onCrop: { croppedImage in
                        self.saveAvatar(croppedImage)
                    },
                    onCancel: {}
                )
            }
        }
    }

    private func saveAvatar(_ image: NSImage) {
        // Create avatar directory if it doesn't exist
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let avatarDir = homeDir.appendingPathComponent(".ai_plugins_data/avatars")

        do {
            try FileManager.default.createDirectory(at: avatarDir, withIntermediateDirectories: true)

            // Generate unique filename
            let timestamp = Int(Date().timeIntervalSince1970)
            let avatarPath = avatarDir.appendingPathComponent("avatar_\(timestamp).jpg").path

            // Save compressed image
            if ImageProcessor.save(image: image, to: avatarPath) {
                settings.userAvatarPath = avatarPath
            }
        } catch {
            print("Failed to create avatar directory: \(error)")
        }
    }
}

/// 精美的指标显示组件
struct MetricView: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Value and unit
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .help(icon == "keyboard" ? NSLocalizedString("typing_speed_tooltip", bundle: .module, comment: "") : NSLocalizedString("ai_acceptance_tooltip", bundle: .module, comment: ""))
    }
}
