import SwiftUI
import AppKit

/// 图像裁剪窗口管理器
@MainActor
class ImageCropperWindow {
    private var window: NSWindow?

    /// 显示图像裁剪窗口
    /// - Parameters:
    ///   - image: 要裁剪的图像
    ///   - onCrop: 裁剪完成回调
    ///   - onCancel: 取消回调
    func show(image: NSImage, onCrop: @escaping @MainActor (NSImage) -> Void, onCancel: @escaping @MainActor () -> Void) {
        let cropperView = ImageCropperView(
            image: image,
            onCrop: { croppedImage in
                onCrop(croppedImage)
                self.close()
            },
            onCancel: {
                onCancel()
                self.close()
            }
        )

        let hostingController = NSHostingController(rootView: cropperView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = NSLocalizedString("adjust_avatar", bundle: .module, comment: "")
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        self.window = window
    }

    /// 关闭窗口
    func close() {
        window?.close()
        window = nil
    }
}
