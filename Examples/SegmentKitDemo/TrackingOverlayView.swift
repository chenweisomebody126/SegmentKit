import CoreGraphics
import EdgeTAMKit
import SwiftUI
import UIKit

/// Mask 叠加渲染视图 — 使用 UIViewRepresentable 确保与 CameraPreviewView 相同的布局行为
///
/// 核心问题: SwiftUI 原生 Image 在 `.ignoresSafeArea()` 下仍按 safe area 尺寸计算
/// `.fill` 缩放比例，导致 mask 比 camera preview 小 ~11%，产生空间偏移。
///
/// 修复: 使用 UIImageView（和 CameraPreviewView 同样的方案），UIKit 直接获取全屏 frame，
/// 用 `.scaleAspectFill` 渲染裁剪后的 mask（croppedMask，宽高比和原始帧一致）。
struct TrackingOverlayView: UIViewRepresentable {

    let trackResult: ETKTrackResult

    func makeUIView(context: Context) -> MaskOverlayUIView {
        let view = MaskOverlayUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: MaskOverlayUIView, context: Context) {
        uiView.updateMask(trackResult: trackResult)
    }
}

/// 内部 UIView — 使用 UIImageView 渲染 mask，与 CameraPreviewUIView 布局一致
class MaskOverlayUIView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    /// 叠加颜色 RGB (#3B82F6 = 蓝色)
    private let overlayR: UInt8 = 0x3B
    private let overlayG: UInt8 = 0x82
    private let overlayB: UInt8 = 0xF6

    /// 前景区域最大透明度
    private let maxOpacity: Float = 0.45

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(imageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    /// 从 ETKTrackResult 更新 mask 显示
    func updateMask(trackResult: ETKTrackResult) {
        guard let image = renderMaskImage(trackResult: trackResult) else {
            imageView.image = nil
            return
        }
        imageView.image = image
    }

    /// 将 croppedMask logit 渲染为半透明 RGBA UIImage
    ///
    /// 使用 croppedMask，宽高比与原始视频帧一致，
    /// 配合 UIImageView 的 `.scaleAspectFill`，确保和 camera preview 完美对齐。
    private func renderMaskImage(trackResult: ETKTrackResult) -> UIImage? {
        let maskData = trackResult.croppedMask
        let width = Int(trackResult.croppedMaskSize.width)
        let height = Int(trackResult.croppedMaskSize.height)
        let pixelCount = width * height

        guard maskData.count == pixelCount, width > 0, height > 0 else { return nil }

        // 构造 RGBA 像素数据
        var pixelData = [UInt8](repeating: 0, count: pixelCount * 4)

        for i in 0..<pixelCount {
            let logit = maskData[i]
            // sigmoid: 1 / (1 + exp(-x))
            let prob = 1.0 / (1.0 + exp(-logit))
            // 前景区域 (prob > 0.5) 显示叠加色，背景透明
            let alpha = prob > 0.5 ? maxOpacity * min(prob * 1.5, 1.0) : 0.0

            // premultiplied alpha: RGB 必须乘以 alpha
            // 当 alpha=0 时四通道全为 0，避免无效数据导致蓝色泄漏
            let offset = i * 4
            pixelData[offset]     = UInt8(Float(overlayR) * alpha)  // R × α
            pixelData[offset + 1] = UInt8(Float(overlayG) * alpha)  // G × α
            pixelData[offset + 2] = UInt8(Float(overlayB) * alpha)  // B × α
            pixelData[offset + 3] = UInt8(alpha * 255.0)            // A
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
