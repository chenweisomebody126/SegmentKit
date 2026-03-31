import AVFoundation
import SwiftUI
import UIKit

/// AVCaptureVideoPreviewLayer 的 SwiftUI 包装
///
/// 用 UIViewRepresentable 将 AVCaptureSession 的预览层
/// 嵌入 SwiftUI 视图层级。
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // session 不变，不需要更新
    }
}

/// 内部 UIView — 持有 AVCaptureVideoPreviewLayer
///
/// 重写 layoutSubviews 保证 preview layer 大小跟随视图变化。
class CameraPreviewUIView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
