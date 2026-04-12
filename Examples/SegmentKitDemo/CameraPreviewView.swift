import AVFoundation
import CoreImage
import CoreVideo
import SwiftUI
import UIKit

/// 相机预览视图 — 使用 UIImageView 渲染帧（支持截图捕获）
///
/// AVCaptureVideoPreviewLayer 在 iOS 截图时不会被渲染，
/// 导致截图只显示叠加层。改用 UIImageView 直接渲染每帧，
/// 截图也能正常捕获相机画面。
struct CameraPreviewView: UIViewRepresentable {

    let cameraManager: CameraManager

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        cameraManager.previewView = view
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

/// 内部 UIView — 使用 UIImageView 渲染相机帧
class CameraPreviewUIView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

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

    /// 从 CVPixelBuffer 更新预览（在 capture queue 调用，内部 dispatch 到 main）
    func updateWithPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = UIImage(cgImage: cgImage)
        }
    }
}
