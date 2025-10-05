import SwiftUI
import AppKit

struct UserProfileView: View {
    @ObservedObject var settings: AppSettings
    @State private var isEditingProfile = false
    @State private var showImagePicker = false

    var body: some View {
        VStack(spacing: 12) {
            // Avatar with camera button
            ZStack(alignment: .bottomTrailing) {
                if let avatarPath = settings.userAvatarPath.isEmpty ? nil : settings.userAvatarPath,
                   let image = NSImage(contentsOfFile: avatarPath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.gray.opacity(0.6))
                        )
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                }

                // Camera button
                Button(action: {
                    selectAvatar()
                }) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("change_avatar", comment: ""))
            }
            .padding(.top, 20)

            // User name
            if isEditingProfile {
                TextField(NSLocalizedString("user_name", comment: ""), text: $settings.userName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit {
                        isEditingProfile = false
                    }
            } else {
                Text(settings.userName.isEmpty ? NSLocalizedString("guest", comment: "") : settings.userName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .onTapGesture {
                        isEditingProfile = true
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    private func selectAvatar() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = NSLocalizedString("change_avatar", comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            settings.userAvatarPath = url.path
        }
    }
}
