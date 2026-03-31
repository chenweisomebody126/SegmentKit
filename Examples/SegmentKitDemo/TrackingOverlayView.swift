import CoreGraphics
import EdgeTAMKit
import SwiftUI
import UIKit

/// Mask 叠加渲染视图
///
/// 接收 ETKTrackResult，使用 croppedMask（已去除 letterbox padding）
/// 渲染半透明蓝色叠加层。croppedMask 与原始帧保持相同宽高比，
/// 不再需要手动 aspectRatio 补偿。
///
/// 渲染流程:
///   1. croppedMask logit → sigmoid → alpha
///   2. 构造 RGBA pixel buffer
///   3. 创建 CGImage
///   4. 用 SwiftUI Image 全屏显示
struct TrackingOverlayView: View {

    let trackResult: ETKTrackResult

    /// 叠加颜色 RGB (#3B82F6 = 蓝色)
    private let overlayR: UInt8 = 0x3B
    private let overlayG: UInt8 = 0x82
    private let overlayB: UInt8 = 0xF6

    /// 前景区域最大透明度
    private let maxOpacity: Float = 0.45

    var body: some View {
        if let image = renderMaskImage() {
            Image(uiImage: image)
                .resizable()
                // croppedMask 已是原始帧宽高比，直接 fill 对齐相机预览
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
        }
    }

    /// 将 croppedMask logit 渲染为半透明 RGBA UIImage
    private func renderMaskImage() -> UIImage? {
        let cropped = trackResult.croppedMask
        let cropSize = trackResult.croppedMaskSize
        let width = Int(cropSize.width)
        let height = Int(cropSize.height)
        let pixelCount = width * height

        guard cropped.count == pixelCount, width > 0, height > 0 else { return nil }

        // 构造 RGBA 像素数据
        var pixelData = [UInt8](repeating: 0, count: pixelCount * 4)

        for i in 0..<pixelCount {
            let logit = cropped[i]
            // sigmoid: 1 / (1 + exp(-x))
            let prob = 1.0 / (1.0 + exp(-logit))
            // 前景区域 (prob > 0.5) 显示叠加色，背景透明
            let alpha = prob > 0.5 ? maxOpacity * min(prob * 1.5, 1.0) : 0.0

            let offset = i * 4
            pixelData[offset]     = overlayR   // R
            pixelData[offset + 1] = overlayG   // G
            pixelData[offset + 2] = overlayB   // B
            pixelData[offset + 3] = UInt8(alpha * 255.0)  // A
        }

        // 创建 CGImage
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
