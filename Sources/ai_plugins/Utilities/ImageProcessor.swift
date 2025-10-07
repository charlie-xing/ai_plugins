import AppKit
import CoreImage

/// 图像处理工具类，提供图像裁剪、缩放和压缩功能
class ImageProcessor {
    /// 最大头像尺寸（像素）
    static let maxAvatarSize: CGFloat = 512

    /// 目标文件大小（字节）- 200KB
    static let targetFileSize: Int = 200 * 1024

    /// 裁剪图像为圆形区域
    /// - Parameters:
    ///   - image: 原始图像
    ///   - rect: 裁剪区域矩形
    /// - Returns: 裁剪后的图像
    static func cropCircular(image: NSImage, rect: CGRect) -> NSImage? {
        // 使用 NSImage 的绘图 API，避免坐标系转换问题
        let croppedSize = rect.size
        let croppedImage = NSImage(size: croppedSize)

        croppedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        // 绘制裁剪区域
        image.draw(
            in: CGRect(origin: .zero, size: croppedSize),
            from: rect,
            operation: .copy,
            fraction: 1.0
        )

        croppedImage.unlockFocus()

        // 创建圆形遮罩
        return createCircularImage(from: croppedImage)
    }

    /// 将图像裁剪为圆形
    /// - Parameter image: 原始图像
    /// - Returns: 圆形图像
    static func createCircularImage(from image: NSImage) -> NSImage? {
        let size = min(image.size.width, image.size.height)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)

        let outputImage = NSImage(size: rect.size)
        outputImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        // 创建圆形路径并裁剪
        let path = NSBezierPath(ovalIn: rect)
        path.addClip()

        // 绘制图像
        let sourceRect = CGRect(
            x: (image.size.width - size) / 2,
            y: (image.size.height - size) / 2,
            width: size,
            height: size
        )
        image.draw(in: rect, from: sourceRect, operation: .copy, fraction: 1.0)

        outputImage.unlockFocus()

        return outputImage
    }

    /// 调整图像大小
    /// - Parameters:
    ///   - image: 原始图像
    ///   - maxSize: 最大尺寸
    /// - Returns: 调整大小后的图像
    static func resize(image: NSImage, maxSize: CGFloat) -> NSImage? {
        let size = image.size

        // 如果图像已经小于最大尺寸，直接返回
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }

        // 计算新尺寸，保持宽高比
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // 创建新图像
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(in: CGRect(origin: .zero, size: newSize),
                   from: CGRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)

        newImage.unlockFocus()

        return newImage
    }

    /// 压缩图像到目标文件大小
    /// - Parameters:
    ///   - image: 原始图像
    ///   - targetSize: 目标文件大小（字节）
    /// - Returns: 压缩后的图像数据
    static func compress(image: NSImage, targetSize: Int = targetFileSize) -> Data? {
        // 首先调整图像大小
        guard let resizedImage = resize(image: image, maxSize: maxAvatarSize) else {
            return nil
        }

        // 转换为 JPEG 格式，逐步降低质量直到满足大小要求
        var compressionQuality: Double = 0.9
        var imageData: Data?

        while compressionQuality > 0.1 {
            if let tiffData = resizedImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) {

                if data.count <= targetSize || compressionQuality <= 0.1 {
                    imageData = data
                    break
                }
            }

            compressionQuality -= 0.1
        }

        return imageData
    }

    /// 保存图像到文件
    /// - Parameters:
    ///   - image: 要保存的图像
    ///   - path: 保存路径
    /// - Returns: 是否保存成功
    @discardableResult
    static func save(image: NSImage, to path: String) -> Bool {
        guard let imageData = compress(image: image) else {
            return false
        }

        do {
            let url = URL(fileURLWithPath: path)
            try imageData.write(to: url)
            return true
        } catch {
            print("Failed to save image: \(error)")
            return false
        }
    }
}
