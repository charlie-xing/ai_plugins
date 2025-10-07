import SwiftUI
import AppKit

/// 图像裁剪视图，提供圆形区域选择功能
struct ImageCropperView: View {
    let image: NSImage
    let onCrop: (NSImage) -> Void
    let onCancel: () -> Void

    @State private var cropRect: CGRect = .zero
    @State private var imageSize: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var isDragging = false

    private let minCropSize: CGFloat = 100
    private let maxCropSize: CGFloat = 400

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(NSLocalizedString("adjust_avatar", bundle: .module, comment: ""))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            // Image canvas with circular crop overlay
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.opacity(0.8)

                    // Image
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(dragOffset)

                    // Circular crop overlay
                    CropOverlay(cropRect: cropRect, canvasSize: geometry.size)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = CGSize(
                                width: lastDragOffset.width + value.translation.width,
                                height: lastDragOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastDragOffset = dragOffset
                        }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                setupInitialCrop(in: geo.size)
                            }
                    }
                )
            }
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Controls
            VStack(spacing: 16) {
                // Zoom slider
                HStack(spacing: 12) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))

                    Slider(value: $scale, in: 0.5...3.0)
                        .frame(maxWidth: 300)

                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(NSLocalizedString("cancel", bundle: .module, comment: ""))
                            .frame(minWidth: 100)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                    Button(action: performCrop) {
                        Text(NSLocalizedString("confirm", bundle: .module, comment: ""))
                            .frame(minWidth: 100)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 550)
    }

    private func setupInitialCrop(in size: CGSize) {
        imageSize = size

        // Calculate initial crop size (1/3 of the smaller dimension)
        let cropSize = min(size.width, size.height) * 0.6

        // Center the crop rect
        cropRect = CGRect(
            x: (size.width - cropSize) / 2,
            y: (size.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )
    }

    private func performCrop() {
        // Calculate the actual display size after scaledToFit
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = imageSize.width / imageSize.height

        var displayImageSize: CGSize
        if imageAspectRatio > containerAspectRatio {
            // 图片更宽，以宽度为准
            displayImageSize = CGSize(
                width: imageSize.width,
                height: imageSize.width / imageAspectRatio
            )
        } else {
            // 图片更高，以高度为准
            displayImageSize = CGSize(
                width: imageSize.height * imageAspectRatio,
                height: imageSize.height
            )
        }

        // Calculate scaled image size (after applying scale factor)
        let scaledDisplaySize = CGSize(
            width: displayImageSize.width * scale,
            height: displayImageSize.height * scale
        )

        // Calculate image position in container (top-left corner after scaling and offset)
        let imageX = (imageSize.width - scaledDisplaySize.width) / 2 + dragOffset.width
        let imageY = (imageSize.height - scaledDisplaySize.height) / 2 + dragOffset.height

        // Calculate crop rect position relative to the scaled image
        let cropInImageX = cropRect.origin.x - imageX
        let cropInImageY = cropRect.origin.y - imageY

        // Convert to original image coordinates
        // displayImageSize is the size shown on screen at scale=1.0
        // We need to map from screen coordinates to original image coordinates
        let scaleToOriginal = image.size.width / displayImageSize.width

        let relativeCropRect = CGRect(
            x: (cropInImageX / scale) * scaleToOriginal,
            y: (cropInImageY / scale) * scaleToOriginal,
            width: (cropRect.width / scale) * scaleToOriginal,
            height: (cropRect.height / scale) * scaleToOriginal
        )

        // Perform the crop
        if let croppedImage = ImageProcessor.cropCircular(image: image, rect: relativeCropRect) {
            onCrop(croppedImage)
        }
    }
}

/// 圆形裁剪遮罩覆盖层
struct CropOverlay: View {
    let cropRect: CGRect
    let canvasSize: CGSize

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Dark overlay with circular hole
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .overlay(
                                Circle()
                                    .frame(width: cropRect.width, height: cropRect.height)
                                    .position(
                                        x: cropRect.midX,
                                        y: cropRect.midY
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )

                // Circular border
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
}

#Preview {
    ImageCropperView(
        image: NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)!,
        onCrop: { _ in },
        onCancel: {}
    )
}
